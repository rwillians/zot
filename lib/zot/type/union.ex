defmodule Zot.Type.Union do
  @moduledoc ~S"""
  Describes a union type, which allows values to be one of many types.
  """

  use Zot.Template

  deftype inner_types: [t: [Zot.Type.t(), ...]]

  def inner_types(%Zot.Type.Union{} = type, [_, _ | _] = value),
    do: %{type | inner_types: value}
end

defimpl Zot.Type, for: Zot.Type.Union do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Union{} = type, value, opts) do
    result =
      Enum.reduce_while(type.inner_types, {:error, []}, fn inner_type, {:error, acc} ->
        ctx =
          Zot.Context.new(inner_type, value, opts)
          |> Zot.Context.parse()

        case Zot.Context.valid?(ctx) do
          true -> {:halt, {:ok, ctx}}
          false -> {:cont, {:error, [ctx | acc]}}
        end
      end)

    case result do
      {:ok, ctx} ->
        Zot.Context.unwrap(ctx)

      {:error, ctxs} ->
        ctxs
        |> Enum.sort_by(& &1.score, :desc)
        |> List.first()
        |> Zot.Context.unwrap()
    end
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Union{} = type) do
    %{
      "anyOf" => Enum.map(type.inner_types, &Zot.json_schema/1)
    }
  end
end
