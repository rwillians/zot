defmodule Zot.Template do
  @moduledoc ~S"""
  """

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc ~S"""
  """
  defmacro deftype(expr) do
    fields = Keyword.keys(expr) ++ [__effects__: []]

    quote do
      defstruct unquote(fields)
    end
  end
end
