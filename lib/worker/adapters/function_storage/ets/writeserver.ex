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

defmodule Worker.Adapters.FunctionStorage.ETS.WriteServer do
  @moduledoc """
    Implements GenServer behaviour; represents a process having exclusive writing rights on an underlying ETS table.

    The {function_name, container_name} couples are inserted or deleted by using GenServer.call() on this process; the table name is currently hardcoded to
    :functions_containers.
  """
  use GenServer, restart: :permanent

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: :write_server)
  end

  @impl true
  def init(_args) do
    table = :ets.new(:functions_containers, [:named_table, :protected])
    IO.puts("FunctionStorage server running")
    {:ok, table}
  end

  @impl true
  def handle_call({:insert, function_name, container}, _from, table) do
    :ets.insert(table, {function_name, container})
    {:reply, {:ok, {function_name, container}}, table}
  end

  @impl true
  def handle_call({:delete, function_name, container}, _from, table) do
    :ets.delete_object(table, {function_name, container})
    {:reply, {:ok, {function_name, container}}, table}
  end
end
