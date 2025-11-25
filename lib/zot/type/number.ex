defmodule Zot.Type.Number do
  @moduledoc ~S"""
  Defines a type that accepts number values.
  """

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.Number do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Number{}, value, _) do
    with :ok <- validate_required(value),
         :ok <- validate_type(value, ["integer", "float"]),
         do: {:ok, value}
  end
end
