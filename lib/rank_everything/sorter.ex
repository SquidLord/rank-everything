defmodule RankEverything.Sorter do
  @moduledoc """
  A purely functional implementation of the Interactive QuickSort algorithm.
  This module manages the state of the sort but does not run as a process itself.
  """

  # The main struct holds the state of the sort
  defstruct [
    # Map of id => %{id: String, name: String}
    items: %{},

    # The recursive tree structure:
    # It can be:
    # - nil (empty)
    # - {:leaf, [ids]} (unsorted bucket)
    # - {:node, pivot_id, left_tree, right_tree} (partitioned)
    tree: nil,

    # List of path-pointers to leaf nodes that still need processing.
    # Each element is a list of directions [:left, :right, :left...] to reach the leaf.
    work_stack: [],

    # The current active partition state:
    # {path, pivot_id, remaining_ids, less_acc, greater_acc}
    current_task: nil,

    # Status: :ready, :voting, :finished
    status: :ready,

    # History of comparisons for audit: [{winner_id, loser_id, reason}]
    history: []
  ]

  @type t :: %__MODULE__{}

  # --- Public API ---

  @doc "Initialize a new Sorter with a list of items (map or list of maps)"
  def new(items_list) when is_list(items_list) do
    # Convert list to map for fast lookup
    items_map = Map.new(items_list, fn i -> {i.id, i} end)
    ids = Enum.map(items_list, & &1.id)

    %__MODULE__{
      items: items_map,
      tree: {:leaf, ids},
      work_stack: [[]], # Start with root path []
      status: :ready
    }
    |> check_next_task()
  end

  @doc "Submit a vote: :less (worse than pivot) or :greater (better than pivot)"
  def vote(%__MODULE__{current_task: nil} = state, _vote), do: state

  def vote(%__MODULE__{current_task: {path, pivot, [candidate | rest], less, greater}} = state, decision) do
    state = update_history(state, pivot, candidate, decision)

    new_task = case decision do
      :less    -> {path, pivot, rest, [candidate | less], greater}
      :greater -> {path, pivot, rest, less, [candidate | greater]}
    end

    %{state | current_task: new_task}
    |> check_next_task()
  end

  @doc "Get the current comparison pair {candidate_item, pivot_item} or nil"
  def get_current_pair(%__MODULE__{current_task: nil}), do: nil
  def get_current_pair(%__MODULE__{current_task: {_, pivot_id, [candidate_id | _], _, _}} = state) do
    {Map.get(state.items, candidate_id), Map.get(state.items, pivot_id)}
  end

  @doc "Get the final sorted list of items. Only valid if status is :finished."
  def get_result(state) do
    id_list = flatten_tree(state.tree)
    Enum.map(id_list, &Map.get(state.items, &1))
  end

  # --- Internal Logic ---

  defp update_history(state, pivot, candidate, :less) do
    %{state | history: [{pivot, candidate, "better"} | state.history]}
  end
  defp update_history(state, pivot, candidate, :greater) do
    %{state | history: [{candidate, pivot, "better"} | state.history]}
  end

  # Checks if the current task is done or if we need to pop from stack
  defp check_next_task(%__MODULE__{current_task: {path, pivot, [], less, greater}} = state) do
    # specific task finished! Commit the partition to the tree.
    # Note: QuickSort pivot is the split point.
    # We replace the {:leaf, ...} at `path` with {:node, pivot, {:leaf, less}, {:leaf, greater}}
    
    new_tree = update_tree_at(state.tree, path, {:node, pivot, {:leaf, less}, {:leaf, greater}})
    
    # Add new work to stack.
    # We push Right (greater) first, then Left (less) so we process Left first (Top implementation).
    # Path logic: append :right or :left
    stack = state.work_stack
    stack = if length(greater) > 1, do: [path ++ [:right] | stack], else: stack
    stack = if length(less) > 1, do: [path ++ [:left] | stack], else: stack

    %{state |
      tree: new_tree,
      current_task: nil,
      work_stack: stack
    }
    |> check_next_task()
  end

  defp check_next_task(%__MODULE__{current_task: nil, work_stack: []} = state) do
    %{state | status: :finished}
  end

  defp check_next_task(%__MODULE__{current_task: nil, work_stack: [next_path | rest]} = state) do
    # Pop from stack, start partitioning
    leaf_ids = get_leaf_at(state.tree, next_path)
    
    # Validation: If leaf has <= 1 item, it's already sorted. Loop again.
    if length(leaf_ids) <= 1 do
      %{state | work_stack: rest} |> check_next_task()
    else
      # Pick Pivot (First item for simplicity, or random?)
      # Random is better to avoid worst case.
      pivot_id = Enum.random(leaf_ids)
      remaining = List.delete(leaf_ids, pivot_id)

      %{state |
        work_stack: rest,
        current_task: {next_path, pivot_id, remaining, [], []}, # {path, pivot, remaining, less_acc, greater_acc}
        status: :voting
      }
    end
  end

  # If current task has items remaining, just continue
  defp check_next_task(state), do: state

  # --- Tree Helpers ---

  defp update_tree_at(_tree, [], new_node), do: new_node
  defp update_tree_at({:node, p, l, r}, [:left | rest], new_sub), do: {:node, p, update_tree_at(l, rest, new_sub), r}
  defp update_tree_at({:node, p, l, r}, [:right | rest], new_sub), do: {:node, p, l, update_tree_at(r, rest, new_sub)}

  defp get_leaf_at({:leaf, ids}, []), do: ids
  defp get_leaf_at({:node, _, l, _}, [:left | rest]), do: get_leaf_at(l, rest)
  defp get_leaf_at({:node, _, _, r}, [:right | rest]), do: get_leaf_at(r, rest)
  # Fallback for error safety?
  defp get_leaf_at(_, _), do: [] 

  defp flatten_tree(nil), do: []
  defp flatten_tree({:leaf, ids}), do: ids # Note: ids in a leaf are technically unsorted relative to each other if >1, but algorithm ensures they are size 0 or 1 eventually? 
                                          # Wait, if we stop recursing at size 1, then yes.
                                          # Ideally leaf should be singleton or empty. 
                                          # Our logic only pushes to work_stack if length > 1.
                                          # So any remaining leaf is length <= 1.
  defp flatten_tree({:node, pivot, l, r}) do
    # High items (greater) come FIRST in rank (Rank 1 is best)
    flatten_tree(r) ++ [pivot] ++ flatten_tree(l)
  end
end
