defmodule RankEverything.Tracking do
  use GenServer

  @name __MODULE__

  # --- Client API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # Returns list of %{id, name, progress}
  def list_sessions do
    GenServer.call(@name, :list_sessions)
  end

  def register_session(id, name) do
    GenServer.cast(@name, {:register, id, name})
  end

  def update_progress(id, progress) do
    GenServer.cast(@name, {:update_progress, id, progress})
  end

  def remove_session(id) do
    GenServer.cast(@name, {:remove, id})
  end

  def subscribe do
    Phoenix.PubSub.subscribe(RankEverything.PubSub, "tracking")
  end

  # --- Server Callbacks ---

  @impl true
  def init(_) do
    # State is a Map: id -> %{id: id, name: name, progress: 0.0}
    {:ok, %{}}
  end

  @impl true
  def handle_call(:list_sessions, _from, state) do
    # Return as list, sorted by name maybe? or insert time (if we had it)
    sessions = Map.values(state)
    {:reply, sessions, state}
  end

  @impl true
  def handle_cast({:register, id, name}, state) do
    new_entry = %{id: id, name: name, progress: 0.0}
    new_state = Map.put(state, id, new_entry)
    broadcast_update(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_progress, id, progress}, state) do
    case Map.get(state, id) do
      nil -> {:noreply, state}
      entry -> 
        updated = %{entry | progress: progress}
        new_state = Map.put(state, id, updated)
        broadcast_update(new_state)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast({:remove, id}, state) do
    new_state = Map.delete(state, id)
    broadcast_update(new_state)
    {:noreply, new_state}
  end

  defp broadcast_update(state) do
    sessions = Map.values(state)
    Phoenix.PubSub.broadcast(RankEverything.PubSub, "tracking", {:tracking_updated, sessions})
  end
end
