defmodule RankEverything.SorterTest do
  use ExUnit.Case
  alias RankEverything.Sorter

  describe "new/1" do
    test "initializes with list of maps" do
      items = [
        %{id: "A", name: "Apple"},
        %{id: "B", name: "Banana"},
        %{id: "C", name: "Cherry"}
      ]
      sorter = Sorter.new(items)
      assert sorter.status == :voting
      assert sorter.tree == {:leaf, ["A", "B", "C"]}
      # items should be stored in map
      assert sorter.items["A"].name == "Apple"
    end
  end

  describe "vote/2" do
    test "partitions a simple 3-item list" do
      items = [
        %{id: "A", name: "Apple"},
        %{id: "B", name: "Banana"},
        %{id: "C", name: "Cherry"}
      ]
      # Pivot is random, but let's see. 
      # Since we can't easily force random seed here without config, 
      # we inspect the state to find the pivot.
      
      sorter = Sorter.new(items)
      {path, pivot_id, remaining, _, _} = sorter.current_task
      
      # Let's say pivot is B.
      # Remaining will be [A, C] (or similar)
      
      # We just vote on whatever is presented until finished.
      # Strategy: Alphabetical order is "better" (A > B > C) ??
      # Let's say A > B > C.
      # Rank 1: A
      # Rank 2: B
      # Rank 3: C
      
      sorter = run_sort_until_finished(sorter, fn candidate, pivot ->
        if candidate.name < pivot.name, do: :greater, else: :less
      end)
      
      assert sorter.status == :finished
      results = Sorter.get_result(sorter)
      
      # Verify order: A, B, C
      assert Enum.at(results, 0).id == "A"
      assert Enum.at(results, 1).id == "B"
      assert Enum.at(results, 2).id == "C"
    end
  end

  defp run_sort_until_finished(sorter, decision_fn) do
    if sorter.status == :finished do
      sorter
    else
      {candidate, pivot} = Sorter.get_current_pair(sorter)
      vote = decision_fn.(candidate, pivot)
      
      sorter
      |> Sorter.vote(vote)
      |> run_sort_until_finished(decision_fn)
    end
  end
end
