defmodule RankEverythingWeb.RankingLive do
  use RankEverythingWeb, :live_view
  alias RankEverything.Session
  alias RankEverything.Sorter

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to updates for this session
      Phoenix.PubSub.subscribe(RankEverything.PubSub, "session:#{id}")
      
      # Fetch initial state from the GenServer
      # Note: This will crash if session doesn't exist. We should handle that.
      try do
        state = Session.get_state(id)
        {:ok, assign_state(socket, state)}
      catch
        :exit, _ -> 
          {:ok, put_flash(push_navigate(socket, to: ~p"/"), :error, "Session not found.")}
      end
    else
      # Initial static render
      {:ok, assign(socket, id: id, loading: true)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen w-full flex flex-col items-center justify-center bg-zinc-900 text-zinc-100 p-6">
      
      <%= if Map.get(assigns, :loading) do %>
        <div class="text-xl animate-pulse">Loading Ranking Session...</div>
      <% else %>
      
        <div class="w-full max-w-4xl flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-emerald-400 to-cyan-500">
            <%= @session_name %>
          </h1>
          <div class="text-zinc-500 font-mono text-sm">
            ID: <%= @id %>
          </div>
        </div>

        <%= if @sorter_status == :finished do %>
          <!-- Result View -->
          <div class="glass w-full max-w-2xl bg-zinc-800/50 rounded-xl p-8 border border-zinc-700 shadow-2xl">
            <h2 class="text-2xl font-bold mb-6 text-center text-emerald-400">Ranking Complete!</h2>
            
            <div class="space-y-2 max-h-[60vh] overflow-y-auto pr-2 custom-scrollbar">
              <%= for {item, index} <- Enum.with_index(@results) do %>
                <div class="flex items-center p-4 bg-zinc-900/50 rounded-lg border border-zinc-800">
                  <div class="w-12 h-12 flex items-center justify-center bg-zinc-800 rounded-full font-bold text-lg text-emerald-500 mr-4 border border-zinc-700">
                    #<%= index + 1 %>
                  </div>
                  <div class="text-xl font-medium"><%= item.name %></div>
                </div>
              <% end %>
            </div>
            
            <div class="mt-8 flex justify-center gap-4">
               <a href={~p"/"} class="px-6 py-3 bg-zinc-700 hover:bg-zinc-600 rounded-lg font-bold transition-colors">
                Back to Dashboard
              </a>
              <button class="px-6 py-3 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg font-bold transition-colors">
                Export Results
              </button>
            </div>
          </div>
        
        <% else %>
          <!-- Voting View -->
          <div class="glass p-8 w-full max-w-5xl flex flex-col md:flex-row gap-8 items-center bg-zinc-800/50 rounded-xl shadow-2xl border border-zinc-700">
            
            <!-- Left Candidate -->
            <button phx-click="vote" phx-value-dir="greater" phx-window-keydown="vote" phx-key="ArrowLeft"
              class="flex-1 w-full py-16 md:py-24 bg-zinc-700/50 hover:bg-cyan-600/20 hover:border-cyan-500 border-2 border-zinc-600 rounded-xl transition-all group relative overflow-hidden">
              <div class="absolute inset-0 bg-gradient-to-br from-cyan-500/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
              <span class="relative z-10 text-3xl md:text-4xl font-bold group-hover:scale-105 transform inline-block transition-transform">
                <%= @candidate.name %>
              </span>
              <div class="mt-4 text-sm text-zinc-500 group-hover:text-cyan-300 font-mono">Press &larr; Left</div>
            </button>

            <div class="flex flex-col items-center">
              <div class="text-zinc-500 font-black text-2xl italic">VS</div>
              <div class="mt-2 text-xs text-zinc-600 uppercase tracking-widest">Constructing Tree</div>
            </div>

            <!-- Right Candidate (Pivot) -->
            <button phx-click="vote" phx-value-dir="less" phx-window-keydown="vote" phx-key="ArrowRight"
              class="flex-1 w-full py-16 md:py-24 bg-zinc-700/50 hover:bg-emerald-600/20 hover:border-emerald-500 border-2 border-zinc-600 rounded-xl transition-all group relative overflow-hidden">
              <div class="absolute inset-0 bg-gradient-to-bl from-emerald-500/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
              <span class="relative z-10 text-3xl md:text-4xl font-bold group-hover:scale-105 transform inline-block transition-transform">
                <%= @pivot.name %>
              </span>
              <div class="mt-4 text-sm text-zinc-500 group-hover:text-emerald-300 font-mono">Press Right &rarr;</div>
            </button>
          </div>

          <div class="mt-12 text-zinc-500 text-sm">
             <a href={~p"/"} class="hover:text-white underline">Cancel Ranking</a>
          </div>
        <% end %>

      <% end %>
    </div>
    """
  end

  def handle_event("vote", %{"dir" => dir_str, "key" => _}, socket), do: vote(socket, dir_str)
  def handle_event("vote", %{"dir" => dir_str}, socket), do: vote(socket, dir_str)

  defp vote(socket, dir_str) do
    decision = case dir_str do
      "less" -> :less
      "greater" -> :greater
      _ -> :unknown
    end
    
    if decision != :unknown do
      Session.vote(socket.assigns.id, decision)
    end
    
    {:noreply, socket}
  end

  def handle_info({:session_updated, state}, socket) do
    {:noreply, assign_state(socket, state)}
  end

  defp assign_state(socket, %{sorter: sorter, name: name, id: id}) do
    pair = Sorter.get_current_pair(sorter)
    
    assigns = %{
      id: id,
      session_name: name,
      sorter_status: sorter.status,
      loading: false
    }

    case sorter.status do
      :finished ->
        Map.merge(assigns, %{results: Sorter.get_result(sorter)})
      
      _ ->
        {candidate, pivot} = pair
        Map.merge(assigns, %{
          candidate: candidate,
          pivot: pivot
        })
    end
    |> then(&assign(socket, &1))
  end
end
