defmodule RankEverythingWeb.HomeLive do
  use RankEverythingWeb, :live_view
  alias RankEverything.Tracking

  def render(assigns) do
    ~H"""
    <div class="min-h-screen w-full flex flex-col items-center bg-zinc-900 text-zinc-100 p-6">
      <div class="max-w-3xl w-full text-center space-y-8 mt-12">
        <div>
          <h1 class="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-cyan-500">
            Rank Everything
          </h1>
          <p class="mt-2 text-zinc-400">Interactive Pivot-Based Sorting</p>
        </div>

        <div class="glass p-8 rounded-2xl border border-zinc-800 bg-zinc-800/50 backdrop-blur-sm shadow-xl space-y-6">
          <form phx-submit="start_ranking" class="space-y-4 text-left">
            <div>
              <label class="block text-sm font-medium text-zinc-300 mb-1">Session Name</label>
              <input type="text" name="name" required placeholder="My Awesome Ranking" class="w-full bg-zinc-900/50 border border-zinc-700 rounded-lg px-4 py-3 text-white placeholder-zinc-500 focus:outline-none focus:border-cyan-500 transition-colors" />
            </div>
            
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-zinc-300 mb-1">Items to Rank (One per line)</label>
                <textarea name="items_text" rows="4" placeholder="Apples\nBananas\nCherries" class="w-full bg-zinc-900/50 border border-zinc-700 rounded-lg px-4 py-3 text-white placeholder-zinc-500 focus:outline-none focus:border-cyan-500 transition-colors"></textarea>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-zinc-300 mb-1">OR Import from URL</label>
                <input type="url" name="url" placeholder="https://en.wikipedia.org/wiki/..." class="w-full bg-zinc-900/50 border border-zinc-700 rounded-lg px-4 py-3 text-white placeholder-zinc-500 focus:outline-none focus:border-cyan-500 transition-colors" />
                <div class="text-xs text-zinc-500 mt-2">
                  Leave URL blank if typing items manually.
                </div>
              </div>
            </div>
            
            <button type="submit" class="w-full py-4 text-xl font-bold bg-emerald-500 hover:bg-emerald-400 text-black rounded-lg transition-all transform hover:scale-[1.02] shadow-lg shadow-emerald-500/20">
              Start Ranking
            </button>
          </form>
          
          <div class="pt-4 border-t border-zinc-700">
            <button phx-click="create_demo" class="w-full py-3 text-sm font-bold bg-zinc-700 hover:bg-zinc-600 text-white rounded-lg transition-all">
              Or Create a Quick Demo
            </button>
          </div>
        </div>
        
        <%= if @sessions != [] do %>
          <div class="text-left space-y-4">
            <h2 class="text-xl font-bold text-zinc-300 border-b border-zinc-800 pb-2">Active Sessions</h2>
            
            <div class="space-y-3">
              <%= for session <- @sessions do %>
                <div class="flex items-center justify-between p-4 bg-zinc-800 rounded-lg border border-zinc-700 hover:border-zinc-600 transition-colors group">
                  <div class="flex-1">
                    <div class="font-bold text-lg text-white"><%= session.name %></div>
                    <div class="text-xs text-zinc-500 font-mono"><%= session.id %></div>
                    
                    <!-- Progress Bar Placeholder -->
                    <div class="mt-2 h-1.5 w-32 bg-zinc-700 rounded-full overflow-hidden">
                      <div class="h-full bg-cyan-500" style={"width: #{session.progress * 100}%"}></div>
                    </div>
                  </div>
                  
                  <div class="flex gap-3">
                    <a href={~p"/rank/#{session.id}"} class="px-4 py-2 bg-cyan-600 hover:bg-cyan-500 text-white font-bold rounded text-sm transition-colors">
                      Continue
                    </a>
                    
                    <button phx-click="delete" phx-value-id={session.id} class="px-3 py-2 bg-red-900/50 hover:bg-red-600 text-red-200 hover:text-white rounded text-sm transition-colors border border-red-900 hover:border-red-500">
                      Delete
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <div class="text-sm text-zinc-600 mt-12">
          v7.0 (Elixir/Phoenix) • <span class="text-zinc-500"><%= length(@sessions) %> active sessions</span>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Tracking.subscribe()
    end
    
    sessions = Tracking.list_sessions()
    {:ok, assign(socket, sessions: sessions)}
  end

  def handle_event("start_ranking", %{"name" => name, "url" => url, "items_text" => text}, socket) do
    # Determine which path to take
    url = String.trim(url)
    text = String.trim(text)
    
    cond do
      url != "" ->
        case RankEverything.create_ranking_from_url(name, url) do
          {:ok, id} ->
            {:noreply, push_navigate(socket, to: ~p"/rank/#{id}")}
          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to import from URL: #{reason}")}
        end
        
      text != "" ->
        items = String.split(text, "\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
        case RankEverything.create_ranking_from_list(name, items) do
          {:ok, id} ->
            {:noreply, push_navigate(socket, to: ~p"/rank/#{id}")}
          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to create: #{reason}")}
        end
        
      true ->
        {:noreply, put_flash(socket, :error, "Please enter either items to rank OR a URL to import from.")}
    end
  end

  def handle_event("create_demo", _params, socket) do
    case RankEverything.create_demo_ranking("Demo Ranking #{:rand.uniform(1000)}") do
      {:ok, id} ->
        {:noreply, push_navigate(socket, to: ~p"/rank/#{id}")}
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create session.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    RankEverything.delete_ranking(id)
    {:noreply, socket}
  end

  def handle_info({:tracking_updated, sessions}, socket) do
    {:noreply, assign(socket, sessions: sessions)}
  end
end
