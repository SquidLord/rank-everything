defmodule RankEverything.Session.Supervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_session(args) do
    # Helper to start a new Session under this supervisor
    spec = {RankEverything.Session, args}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def terminate_session(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
