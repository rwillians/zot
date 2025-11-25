defmodule Zot.Type.Boolean do
  @moduledoc ~S"""
  A type that accepts boolean values.
  """

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.Boolean do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Boolean{}, value, _) do
    with :ok <- validate_required(value),
         :ok <- validate_type(value, "boolean"),
         do: {:ok, value}
  end
end
