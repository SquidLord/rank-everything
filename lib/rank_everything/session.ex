defmodule RankEverything.Session do
  use GenServer, restart: :temporary
  alias RankEverything.Sorter
  alias RankEverything.Tracking

  # -- Client API --

  def start_link(args) do
    # Args: %{id: id, name: name, items: [...]}
    GenServer.start_link(__MODULE__, args, name: via_tuple(args.id))
  end

  def vote(id, decision) do
    GenServer.call(via_tuple(id), {:vote, decision})
  end

  def get_state(id) do
    GenServer.call(via_tuple(id), :get_state)
  end

  def stop(id) do
    GenServer.stop(via_tuple(id))
  end

  defp via_tuple(id) do
    {:via, Registry, {RankEverything.SessionRegistry, id}}
  end

  # -- Server Callbacks --

  @impl true
  def init(%{id: id, name: name, items: items}) do
    # Try to load existing session from disk, or create new
    state = 
      case RankEverything.Persistence.load_session(id) do
        {:ok, loaded_state} -> 
          loaded_state
        _ ->
          sorter = Sorter.new(items)
          new_state = %{id: id, name: name, sorter: sorter}
          RankEverything.Persistence.save_session(new_state)
          new_state
      end
      
    # Register with Tracking
    Tracking.register_session(state.id, state.name)
    
    # Broadcast initial state
    broadcast_change(state)
    
    {:ok, state}
  end

  @impl true
  def handle_call({:vote, decision}, _from, state) do
    new_sorter = Sorter.vote(state.sorter, decision)
    new_state = %{state | sorter: new_sorter}
    
    # Save the updated state to disk
    RankEverything.Persistence.save_session(new_state)
    
    # Update progress in Tracking if finished
    if new_sorter.status == :finished do
      Tracking.update_progress(state.id, 1.0)
    end
    
    # Broadcast
    broadcast_change(new_state)
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def terminate(_reason, state) do
    # We do NOT remove the session from Tracking here because we want it to persist.
    # The session is temporary in memory, but permanent on disk until explicitly deleted.
    :ok
  end

  defp broadcast_change(state) do
    Phoenix.PubSub.broadcast(RankEverything.PubSub, "session:#{state.id}", {:session_updated, state})
  end
end
