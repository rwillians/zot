defmodule Zot.Type.Decimal do
  @moduledoc ~S"""
  Defines a type that accepts integer values.
  """

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.Decimal do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Decimal{}, value, _) do
    with :ok <- validate_required(value),
         :ok <- validate_type(value, "Decimal"),
         do: {:ok, value}
  end
end
