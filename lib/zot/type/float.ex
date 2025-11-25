defmodule Zot.Type.Float do
  @moduledoc ~S"""
  Defines a type that accepts float values.
  """

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.Float do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Float{}, value, _) do
    with :ok <- validate_required(value),
         :ok <- validate_type(value, "float"),
         do: {:ok, value}
  end
end
