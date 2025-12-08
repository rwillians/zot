defmodule Zot.Type.Any do
  @moduledoc ~S"""
  Describes a type that accepts any value.
  """

  use Zot.Template

  deftype []

  def new, do: %__MODULE__{}
end

defimpl Zot.Type, for: Zot.Type.Any do
  @impl Zot.Type
  def parse(%Zot.Type.Any{}, value, _), do: {:ok, value}
end
