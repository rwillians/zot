defmodule Zot.Type.Atom do
  @moduledoc ~S"""
  Describes an atom type.
  """

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.Atom do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Atom{}, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "atom"),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Atom{} = type) do
    %{
      "description" => type.description,
      "examples" => maybe_examples(type.example),
      "type" => maybe_nullable("string", type.required)
    }
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false), do: {:ok, value}
  defp coerce(value, _) when is_atom(value), do: {:ok, value}
  defp coerce(value, :unsafe) when is_binary(value) do
    {:ok, String.to_atom(value)}
  rescue
    _ -> {:ok, String.to_atom(value)}
  end
  defp coerce(value, _) when is_binary(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    _ -> {:error, [issue("atom %{actual} does not exist", actual: value)]}
  end
  # ↓ let validate_type/2 handle it
  defp coerce(value, _), do: {:ok, value}
end
