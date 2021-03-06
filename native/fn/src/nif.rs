// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//
use crate::{
    atoms::{error, ok},
    utils,
};
use bollard::{
    container::{
        Config, CreateContainerOptions, KillContainerOptions, RemoveContainerOptions,
        StartContainerOptions,
    },
    models::HostConfig,
};
use futures_util::TryFutureExt;
use once_cell::sync::Lazy;
use rustler::{Encoder, Env, NifStruct, OwnedEnv};
use std::thread;
use tokio::runtime::{Builder, Runtime};

// https://github.com/rusterlium/rustler/issues/409
static TOKIO: Lazy<Runtime> = Lazy::new(|| {
    Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("Failed to start tokio runtime")
});

/// A struct representing functions.
///
/// It's the Rust equivalent of the `Worker.Domain.Function` Elixir struct.
///
#[derive(NifStruct)]
#[module = "Worker.Domain.Function"]
struct Function {
    name: String,
    image: String,
    archive: String,
    main_file: String,
}

/// A struct representing containers.
///
/// It's the Rust equivalent of the `Worker.Domain.Container` Elixir struct.
///
#[derive(NifStruct)]
#[module = "Worker.Domain.Container"]
struct Container {
    name: String,
    host: String,
    port: String,
}

/*
    TODO: currently only works with docker; docker_host should either be:
        1. A struct, identifying the underlying container runtime => passed by Elixir
        2. A string; in this case, the corresponding struct/runtime is built by Rust instead of Elixir => in this case, the string might be obtained by Rust directly
*/

/// Creates a container for the given function.
///
/// Sends the `{:ok, container}` or `{:error, err}` response to the calling Elixir worker.
///
/// The computation is moved to a different thread to avoid conflicts with the BEAM schedulers.
///
/// # Arguments
///
/// * `env` - NIF parameter, represents the calling worker
/// * `function` - A `Function` struct holding the necessary function information
/// * `container_name` - A string holding the name of the container being created
/// * `docker_host` - A string holding the path to the docker socket or remote host
///
#[rustler::nif]
fn prepare_runtime(env: Env, function: Function, container_name: String, docker_host: String) {
    let pid = env.pid();

    thread::spawn(move || {
        let mut thread_env = OwnedEnv::new();

        let docker =
            utils::connect_to_docker(&docker_host).expect("Failed to connect to docker socket");
        let docker_image = utils::select_image(&(function.image)).expect("");
        let rootless = docker_host != "unix:///var/run/docker.sock";

        let options = Some(CreateContainerOptions {
            name: &container_name,
        });

        let host_config = HostConfig {
            publish_all_ports: Some(true),
            ..Default::default()
        };

        let config = Config {
            image: Some(docker_image),
            host_config: Some(host_config),
            ..Default::default()
        };

        let f = utils::get_image(&docker, docker_image)
            .and_then(|_| docker.create_container(options, config))
            .and_then(|_| {
                docker.start_container(&container_name, None::<StartContainerOptions<String>>)
            })
            .and_then(|_| docker.inspect_container(&container_name, None));

        let result = TOKIO.block_on(f);

        match result {
            Ok(r) => {
                let h = if rootless {
                    utils::extract_rootless_host_port(r.network_settings)
                } else {
                    utils::extract_host_port(r.network_settings)
                };
                match h {
                    Some((host, port)) => thread_env.send_and_clear(&pid, |env| {
                        let container = Container {
                            name: container_name,
                            host,
                            port,
                        };
                        (ok(), container).encode(env)
                    }),
                    None => thread_env.send_and_clear(&pid, |env| {
                        (error(), "Error fetching container network configuration").encode(env)
                    }),
                }
            }
            Err(e) => thread_env.send_and_clear(&pid, |env| (error(), e.to_string()).encode(env)),
        }
    });
}

#[rustler::nif]
fn runtime_logs(env: Env, container_name: String, docker_host: String) {
    let pid = env.pid();

    thread::spawn(move || {
        let mut thread_env = OwnedEnv::new();
        let docker =
            utils::connect_to_docker(&docker_host).expect("Failed to connect to docker socket");

        let f = utils::container_logs(&docker, &container_name);

        let result = TOKIO.block_on(f);

        match result {
            Ok(v) => {
                let logs = v.iter().map(|l| l.to_string()).collect::<Vec<String>>();
                thread_env.send_and_clear(&pid, |env| (ok(), logs).encode(env))
            }
            Err(e) => thread_env.send_and_clear(&pid, |env| (error(), e.to_string()).encode(env)),
        };
    });
}

/// Removes the container with the given name.
///
/// Sends the `:ok` or `{:error, err}` response to the calling Elixir worker.
///
/// The computation is moved to a different thread to avoid conflicts with the BEAM schedulers.
///
/// # Arguments
///
/// * `env` - NIF parameter, represents the calling worker
/// * `container_name` - A string holding the name of the container being removed
/// * `docker_host` - A string holding the path to the docker socket or remote host
///
#[rustler::nif]
fn cleanup(env: Env, container_name: String, docker_host: String) {
    let pid = env.pid();

    thread::spawn(move || {
        let mut thread_env = OwnedEnv::new();
        let docker =
            utils::connect_to_docker(&docker_host).expect("Failed to connect to docker socket");

        let f = docker
            .kill_container(&container_name, None::<KillContainerOptions<String>>)
            .and_then(|_| docker.remove_container(&container_name, None::<RemoveContainerOptions>));

        let result = TOKIO.block_on(f);

        match result {
            Ok(()) => thread_env.send_and_clear(&pid, |env| ok().encode(env)),
            Err(e) => thread_env.send_and_clear(&pid, |env| (error(), e.to_string()).encode(env)),
        }
    });
}
