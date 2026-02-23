defmodule RankEverything.Importer do
  @moduledoc """
  Fetches a URL and attempts to extract a list of items to rank.
  Looks for the largest <ul>, <ol>, or <table> element.
  """

  require Logger

  @doc """
  Fetches the given URL and parses it for rankable items.
  Returns {:ok, list_of_maps} or {:error, reason}.
  """
  def import_from_url(url) do
    # Basic URL validation could go here
    case Req.get(url, redirect: true, max_redirects: 5) do
      {:ok, %{status: 200, body: html}} ->
        case extract_obsidian_markdown_url(html) do
          {:ok, md_url} -> fetch_and_parse_obsidian(md_url)
          :error -> parse_html(html)
        end
        
      {:ok, %{status: status}} ->
        {:error, "HTTP Error: #{status}"}
        
      {:error, reason} ->
        Logger.error("Failed to fetch URL: #{inspect(reason)}")
        {:error, "Failed to connect to the provided URL."}
    end
  end

  @doc false
  def extract_obsidian_markdown_url(html) do
    # Looks for window.preloadPage=f("https://publish-01.obsidian.md/access/...md");
    case Regex.run(~r/window\.preloadPage\s*=\s*f\(\s*"([^"]+)"\s*\)/, html) do
      [_, md_url] -> {:ok, md_url}
      _ -> :error
    end
  end

  defp fetch_and_parse_obsidian(md_url) do
    Logger.debug("Detected Obsidian Publish. Fetching raw Markdown from: #{md_url}")
    case Req.get(md_url, redirect: true, max_redirects: 5) do
      {:ok, %{status: 200, body: text}} ->
        parse_obsidian_markdown(text)
      _error ->
        {:error, "Failed to fetch Obsidian Publish Markdown content."}
    end
  end

  @doc false
  def parse_obsidian_markdown(text) do
    items = 
      text
      |> String.split(["\n", "\r\n"])
      |> Enum.map(&String.trim/1)
      # Match standard markdown lists: - item, * item, 1. item
      |> Enum.filter(fn line -> String.match?(line, ~r/^(\s*[-*]|\s*\d+\.)\s+(.+)$/) end)
      |> Enum.map(fn line -> 
        [_, _, content] = Regex.run(~r/^(\s*[-*]|\s*\d+\.)\s+(.+)$/, line)
        String.trim(content)
      end)
      |> Enum.reject(&(&1 == ""))
      
    if items == [] do
      {:error, "Found Obsidian Publish page, but it did not contain any bulleted or numbered lists."}
    else
      format_items(items)
    end
  end

  @doc false
  def parse_html(html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        # Find candidates
        tables = Floki.find(document, "table")
        lists_ul = Floki.find(document, "ul")
        lists_ol = Floki.find(document, "ol")
        
        candidates = tables ++ lists_ul ++ lists_ol
        
        if candidates == [] do
          {:error, "Could not find any lists or tables on this page."}
        else
          # Score candidates by number of items (tr or li)
          # We pick the largest one.
          best_candidate = 
            candidates
            |> Enum.max_by(fn element ->
              case element do
                {"table", _, _} = table -> length(Floki.find(table, "tr"))
                list -> length(Floki.find(list, "li"))
              end
            end, fn -> nil end)
            
          extract_items(best_candidate)
        end
        
      _error ->
        {:error, "Failed to parse the HTML document."}
    end
  end
  
  defp extract_items(nil), do: {:error, "No items found."}

  defp extract_items({"table", _, _} = table) do
    # Extract rows, skip header row if using th
    rows = Floki.find(table, "tr")
    
    items =
      rows
      |> Enum.map(fn row ->
        # Just grab all text from the row's tds or ths and join
        cells = Floki.find(row, "td, th")
        text = cells
               |> Enum.map(&Floki.text(&1, sep: " "))
               |> Enum.map(&String.trim/1)
               |> Enum.reject(&(&1 == ""))
               |> Enum.join(" - ")
               
        text
      end)
      |> Enum.reject(&(&1 == ""))
      
    if items == [] do
       {:error, "Found a table but could not extract any text."}
    else
       format_items(items)
    end
  end

  defp extract_items({tag, _, _} = list) when tag in ["ul", "ol"] do
    items = 
      Floki.find(list, "li")
      |> Enum.map(&Floki.text/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      
    if items == [] do
      {:error, "Found a list but it was empty."}
    else
      format_items(items)
    end
  end
  
  defp format_items(strings) do
    # Convert list of strings to the expected [%{id: "...", name: "..."}, ...] format
    result = 
      strings
      |> Enum.with_index()
      |> Enum.map(fn {name, idx} ->
        %{
          id: Integer.to_string(idx + 1), # Simple ID generation
          name: name
        }
      end)
      
    if length(result) < 2 do
      {:error, "Found less than 2 items. You need at least 2 items to rank."}
    else
      {:ok, result}
    end
  end
end
