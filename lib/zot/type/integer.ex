defmodule Zot.Type.Integer do
  @moduledoc ~S"""
  Defines a type that accepts integer values.
  """

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.Integer do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Integer{}, value, _) do
    with :ok <- validate_required(value),
         :ok <- validate_type(value, "integer"),
         do: {:ok, value}
  end
end
