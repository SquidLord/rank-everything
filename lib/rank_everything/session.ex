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
    # Register with Tracking
    Tracking.register_session(id, name)
    
    # Initialize Sorter
    sorter = Sorter.new(items)
    
    # Initial state
    state = %{
      id: id,
      name: name,
      sorter: sorter
    }
    
    # Broadcast initial state
    broadcast_change(state)
    
    {:ok, state}
  end

  @impl true
  def handle_call({:vote, decision}, _from, state) do
    new_sorter = Sorter.vote(state.sorter, decision)
    new_state = %{state | sorter: new_sorter}
    
    # Update progress in Tracking if changed? 
    # Sorter doesn't expose progress % yet, but we could calc it.
    # For now, just broadcast.
    broadcast_change(new_state)
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Ensure we clean up the tracking list
    Tracking.remove_session(state.id)
    :ok
  end

  defp broadcast_change(state) do
    Phoenix.PubSub.broadcast(RankEverything.PubSub, "session:#{state.id}", {:session_updated, state})
  end
end
