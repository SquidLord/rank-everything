defmodule RankEverything.Persistence do
  @moduledoc """
  Handles saving and loading ranking sessions to/from the file system.
  Simple JSON-based storage for persistence.
  """
  
  require Logger
  
  @data_dir "priv/data/sessions"

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker
    }
  end

  def start_link() do
    ensure_data_dir()
    {:ok, self()}
  end
  
  defp ensure_data_dir() do
    File.mkdir_p!(@data_dir)
  end

  defp session_path(id) do
    Path.join([@data_dir, "#{id}.json"])
  end
  
  @doc """
  Saves a session map to disk encoded as JSON.
  """
  def save_session(%{id: id} = session) do
    ensure_data_dir()
    
    # We strip out the sorter struct metadata for plain json,
    # or rely on Jason.Encoder if derived. Since Sorter contains tuples in work_stack,
    # we need to be careful. For now, we will encode the raw Map with structs.
    # Jason handles structs if @derive Jason.Encoder is used, but tuples are encoded as lists.
    # We will let Jason handle the basic types.
    
    json_data = Jason.encode!(session, pretty: true)
    
    case File.write(session_path(id), json_data) do
      :ok -> 
        Logger.debug("Saved session #{id} to disk.")
        :ok
      {:error, reason} ->
        Logger.error("Failed to save session #{id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Loads a session from disk by ID.
  """
  def load_session(id) do
    path = session_path(id)
    
    if File.exists?(path) do
      case File.read(path) do
        {:ok, data} ->
          case Jason.decode(data, keys: :atoms) do
            {:ok, session} -> 
              {:ok, hydrate_session(session)}
            {:error, _} = err -> 
              Logger.warning("Failed to decode session #{id}")
              err
          end
        err -> err
      end
    else
      {:error, :not_found}
    end
  end
  
  @doc """
  Lists all saved session IDs.
  """
  def list_saved_sessions() do
    ensure_data_dir()
    
    @data_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.map(&Path.rootname/1)
  end
  
  @doc """
  Deletes a saved session from disk.
  """
  def delete_session(id) do
    File.rm(session_path(id))
  end
  
  # --- Hydration ---
  # Jason decodes structs as maps and tuples as lists.
  # We need to convert them back to their Elixir representations.
  
  defp hydrate_session(session) do
    # Convert map back to %RankEverything.Session{} if needed
    # But since session state might just be a regular map with a :sorter key
    
    sorter = 
      if session[:sorter] do
        hydrate_sorter(session.sorter)
      else
        nil
      end
      
    %{session | sorter: sorter}
  end
  
  defp hydrate_sorter(sorter_map) do
    # Convert the map to the %RankEverything.Sorter{} struct
    # We need to manually fix tuples that were encoded as lists
    
    hydrated = struct(RankEverything.Sorter, sorter_map)
    
    # Fix :status from string to atom since Jason.decode(keys: :atoms) doesn't deep-convert string values to atoms for specific fields
    status = if is_binary(hydrated.status), do: String.to_atom(hydrated.status), else: hydrated.status
    
    # Fix current_task tuple: {path, pivot_id, remaining_ids, less, greater} -> was encoded as list
    curr_task = 
      case hydrated.current_task do
        nil -> nil
        list when is_list(list) and length(list) == 5 ->
          List.to_tuple(list)
        tuple when is_tuple(tuple) -> tuple
        _ -> nil
      end
      
    # Fix tree nodes from lists to tuples if needed. Currently tree is a map ID => Item or tuple
    tree = 
      Enum.reduce(hydrated.tree || %{}, %{}, fn {k, v}, acc ->
         # Convert list values to tuple {less_id, pivot_id, greater_id}
         val = if is_list(v) and length(v) == 3, do: List.to_tuple(v), else: v
         Map.put(acc, k, val)
      end)
      
    %{hydrated | status: status, current_task: curr_task, tree: tree}
  end
end
