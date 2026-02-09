defmodule ZotTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  @doc ~S"""
  Given an error result containing exactly one `Zot.Issue`, returns
  the issue's messages string.
  """
  def unwrap_issue_message({:error, [issue]}), do: Exception.message(issue)

  doctest Zot
end
