defmodule RankEverything.ImporterTest do
  use ExUnit.Case, async: true
  alias RankEverything.Importer

  describe "extract_obsidian_markdown_url/1" do
    test "extracts URL from Obsidian Publish preload tag" do
      html = ~s|<html><body><script>window.preloadPage=f("https://publish-01.obsidian.md/access/123/site.md");</script></body></html>|
      assert {:ok, "https://publish-01.obsidian.md/access/123/site.md"} = Importer.extract_obsidian_markdown_url(html)
    end

    test "returns :error for normal HTML" do
      html = "<html><body><p>Hello world</p></body></html>"
      assert :error = Importer.extract_obsidian_markdown_url(html)
    end
  end

  describe "parse_obsidian_markdown/1" do
    test "extracts bulleted and numbered lists" do
      markdown = """
      # My List
      
      Some text here.
      
      - Apple
      * Banana
      1. Cherry
      
      More text.
      """
      
      assert {:ok, items} = Importer.parse_obsidian_markdown(markdown)
      assert length(items) == 3
      assert Enum.at(items, 0).name == "Apple"
      assert Enum.at(items, 1).name == "Banana"
      assert Enum.at(items, 2).name == "Cherry"
    end
    
    test "returns error if less than 2 valid items" do
      markdown = """
      # Only one item
      - Lonely item
      """
      assert {:error, _msg} = Importer.parse_obsidian_markdown(markdown)
    end
  end

  describe "parse_html/1" do
    test "extracts items from a UL list" do
      html = "<ul><li>Option A</li><li>Option B</li></ul>"
      assert {:ok, items} = Importer.parse_html(html)
      assert length(items) == 2
      assert Enum.at(items, 0).name == "Option A"
      assert Enum.at(items, 1).name == "Option B"
    end
    
    test "extracts rows from a table" do
      html = "<table><tr><td>Row 1</td></tr><tr><td>Row 2</td></tr></table>"
      assert {:ok, items} = Importer.parse_html(html)
      assert length(items) == 2
      assert Enum.at(items, 0).name == "Row 1"
    end
  end
end
