defmodule Zot.Type.Any do
  @moduledoc ~S"""
  Describes a type that accepts any value.
  """

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.Any do
  @impl Zot.Type
  def parse(%Zot.Type.Any{}, value, _),
    do: {:ok, value}

  @impl Zot.Type
  def json_schema(%Zot.Type.Any{} = type) do
    %{
      "description" => type.description,
      "example" => type.example
    }
  end
end
