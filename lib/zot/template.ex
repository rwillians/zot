defmodule Zot.Template do
  @moduledoc ~S"""
  Starting point for building types.
  """
  @moduledoc since: "0.1.0"

  @doc ~S"""
  """
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc ~S"""
  """
  @doc since: "0.1.0"
  defmacro deftype(expr) do
    fields = Keyword.keys(expr) ++ [__effects__: []]

    quote do
      defstruct unquote(fields)
    end
  end
end
