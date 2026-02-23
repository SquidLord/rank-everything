defmodule RankEverything do
  @moduledoc """
  RankEverything keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  of if it comes from the database, an external API or others.
  """
  
  alias RankEverything.Session
  alias RankEverything.Session.Supervisor, as: SessionSup

  @doc """
  Starts a new ranking session with the given name and list of items.
  Returns {:ok, id}
  """
  def create_ranking(name) do
    id = generate_id()
    
    # Placeholder items for now - we will add input parsing later
    items = [
      %{id: "1", name: "Option A"},
      %{id: "2", name: "Option B"},
      %{id: "3", name: "Option C"}
    ]
    
    # Start the session
    # We pass id, name, items to the Session GenServer
    args = %{id: id, name: name, items: items}
    
    case SessionSup.start_session(args) do
      {:ok, _pid} -> {:ok, id}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stops and removes a ranking session.
  """
  def delete_ranking(id) do
    Session.stop(id)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
