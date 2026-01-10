defmodule Zot.Commons do
  @moduledoc ~S"""
  Common functions used across type implementations.
  """

  import Zot.Issue, only: [issue: 2]

  @doc ~S"""
  """
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      import Zot.Issue, only: [issue: 1, issue: 2]
      import Zot.Utils
    end
  end

  def dump(nil), do: nil
  def dump(value) when is_binary(value), do: value
  def dump(value) when is_boolean(value), do: to_string(value)
  def dump(value) when is_atom(value), do: Atom.to_string(value)
  def dump(value) when is_number(value), do: value
  def dump(%Date{} = value), do: Date.to_iso8601(value)
  def dump(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def dump(%Decimal{} = value), do: Decimal.to_float(value)
  def dump(%Regex{} = value), do: "/" <> Regex.source(value) <> "/"
  def dump(%Zot.Parameterized{} = param), do: dump(param.value)
  def dump(value), do: to_string(value)

  def validate_regex(%{regex: nil}, _), do: :ok

  def validate_regex(%{regex: %Zot.Parameterized{} = regex}, value) do
    case Regex.match?(regex.value, value) do
      true -> :ok
      false -> {:error, [issue(regex.params.error, value: regex.value)]}
    end
  end

  def validate_type(value, is: expected) do
    case typeof(value, expected) do
      ^expected -> :ok
      actual -> {:error, [issue("expected type %{expected}, got %{actual}", expected: expected, actual: actual)]}
    end
  end

  #
  #   PRIVATE
  #

  defp typeof(value, hint)
  defp typeof(nil, _), do: "nil"
  defp typeof(value, _) when is_boolean(value), do: "boolean"
  defp typeof(value, _) when is_atom(value), do: "atom"
  defp typeof(value, _) when is_binary(value), do: "string"
  defp typeof(value, _) when is_bitstring(value), do: "bitstring"
  defp typeof(value, _) when is_float(value), do: "float"
  defp typeof(value, _) when is_integer(value), do: "integer"
  defp typeof(value, "keyword") when is_list(value), do: "keyword"
  defp typeof(value, _) when is_list(value), do: "list"
  defp typeof(%mod{}, _), do: name(mod)
  defp typeof(%{__struct__: mod}, _), do: name(mod)
  defp typeof(value, _) when is_map(value), do: "map"
  defp typeof(value, _) when is_tuple(value), do: "tuple"
  defp typeof(value, _) when is_function(value), do: "function"
  defp typeof(value, _) when is_pid(value), do: "pid"
  defp typeof(value, _) when is_port(value), do: "port"
  defp typeof(value, _) when is_reference(value), do: "reference"
  defp typeof(value, _), do: raise(ArgumentError, "Unabled to determine type of value #{inspect(value)}")

  defp name(mod) when is_atom(mod), do: String.replace(to_string(mod), ~r/^Elixir\./, "")
end
