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
  Creates a parameterized value.
  """
  @spec parameterized(value, defaults, params) :: params
        when value: term,
             defaults: keyword,
             params: keyword

  def parameterized(value, defaults \\ [], params) do
    params =
      defaults
      |> Keyword.merge(params)
      |> Map.new()
      |> Map.take([:error])

    {value, params}
  end
end
