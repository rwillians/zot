defmodule Zot.Parameterized do
  @moduledoc since: "0.1.0"

  @typedoc ~S"""
  The type spec of a parameterized modifier.
  """
  @type t(inner_type) :: {inner_type, params}

  @typedoc ~S"""
  Map of parameters.
  """
  @type params :: %{error: String.t()}

  @doc ~S"""
  Merges two keyword lists of parameters.
  """
  @spec merge_params(a, b) :: params
        when a: keyword,
             b: keyword

  def merge_params(a, b) do
    a
    |> Keyword.merge(b)
    |> Map.new()
    |> Map.take([:error])
  end
end
