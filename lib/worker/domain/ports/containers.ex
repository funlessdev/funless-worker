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

defmodule Worker.Domain.Ports.Containers do
  @moduledoc """
  Port for container manipulation.
  """
  @type worker_function :: Worker.Domain.Function.t()
  @type container_name :: String.t()

  @callback prepare_container(worker_function, container_name) ::
              {:ok, container_name} | {:error, any}
  @callback run_function(worker_function, container_name) ::
              {:ok, any} | {:error, any}
  @callback cleanup(worker_function, container_name) ::
              {:ok, container_name} | {:error, any}

  # TODO: add dynamic adapter based on env
  @adapter Worker.Adapters.Containers.Docker
  defdelegate prepare_container(worker_function, container_name), to: @adapter
  defdelegate run_function(worker_function, container_name), to: @adapter
  defdelegate cleanup(worker_function, container_name), to: @adapter
end