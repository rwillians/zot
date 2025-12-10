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
end
