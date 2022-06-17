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

defmodule Worker.Adapters.FunctionStorage.ETS do
  @moduledoc """
  ETS adapter for storage of {function, container} tuples.
  """
  @behaviour Worker.Domain.Ports.FunctionStorage

  @doc """
    Returns a list of containers associated with the given `function_name`.

    Returns {:ok, {function_name, [list of containers]}} if at least a container is found;
    returns {:error, err} if no value is associated to the `function_name` key in the ETS table.

    ## Parameters
      - function_name: name of the function, used as key in the ETS table entries
  """
  @impl true
  def get_function_containers(function_name) do
    containers = :ets.lookup(:functions_containers, function_name)

    case containers do
      [] ->
        {:error, "no container found for #{function_name}"}

      tuples when is_list(tuples) ->
        t =
          tuples
          |> Enum.map(fn {_f, c} -> c end)

        {:ok, {function_name, t}}
    end
  end

  @doc """
    Inserts the  {`function_name`, `container`} couple in the ETS table.
    Calls the :write_server process to alter the table, does not modify it directly.

    Returns {:ok, {function_name, container}}.

    ## Parameters
      - function_name: name of the function, used as key in the ETS table entries
      - container: struct identifying the container
  """
  @impl true
  def insert_function_container(function_name, container) do
    GenServer.call(:write_server, {:insert, function_name, container})
  end

  @doc """
    Removes the  {`function_name`, `container`} couple from the ETS table.
    Calls the :write_server process to alter the table, does not modify it directly.

    Returns {:ok, {function_name, container}}.

    ## Parameters
      - function_name: name of the function, used as key in the ETS table entries
      - container: struct identifying the container
  """
  @impl true
  def delete_function_container(function_name, container) do
    GenServer.call(:write_server, {:delete, function_name, container})
  end
end
