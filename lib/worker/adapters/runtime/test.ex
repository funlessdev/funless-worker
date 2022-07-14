# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

defmodule Worker.Adapters.Runtime.Test do
  @moduledoc false
  @behaviour Worker.Domain.Ports.Runtime

  @impl true
  def prepare_container(_worker_function, _container_name) do
    {:ok, %Worker.Domain.Container{name: "hello-container", host: "localhost", port: "8080"}}
  end

  @impl true
  def run_function(_worker_function, _args, _container_name) do
    {:ok, "output"}
  end

  @impl true
  def cleanup(_worker_function, container_name) do
    {:ok, container_name}
  end
end
