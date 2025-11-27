defmodule Zot.Type.Any do
  @moduledoc ~S"""
  A type that accepts any value.
  """

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.Any do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Any{}, value, _) do
    with :ok <- validate_required(value),
         do: {:ok, value}
  end
end
