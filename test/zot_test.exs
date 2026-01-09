defmodule ZotTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  def unwrap_issue_message({:error, [issue]}), do: Exception.message(issue)

  doctest Zot
end
