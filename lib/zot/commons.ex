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

  @doc ~S"""
  Renders a value to be used in JSON Schema.
  """
  @spec dump(term) :: nil | String.t() | number | boolean | list

  def dump(nil), do: nil
  def dump(value) when is_binary(value), do: value
  def dump(value) when is_boolean(value), do: value
  def dump(value) when is_atom(value), do: Atom.to_string(value)
  def dump(value) when is_number(value), do: value
  def dump(%Date{} = value), do: Date.to_iso8601(value)
  def dump(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def dump(%Decimal{} = value), do: Decimal.to_float(value)
  def dump(%Regex{} = value), do: Regex.source(value)
  def dump(%Zot.Parameterized{} = param), do: dump(param.value)

  def dump(value) when is_non_struct_map(value) do
    for {k, v} <- value,
        into: %{},
        do: {to_string(k), dump(v)}
  end

  def dump([]), do: []
  def dump([head | tail]), do: [dump(head) | dump(tail)]
  def dump(value) when is_tuple(value), do: value |> Tuple.to_list() |> dump()

  @doc ~S"""
  If an example is given, wraps it in a list. Otherwise, returns nil.
  """
  def maybe_examples(nil), do: nil
  def maybe_examples(example), do: [dump(example)]

  @doc ~S"""
  Return the a JSON Schema type that might be nullable.
  """
  @spec maybe_nullable(type_name, required?) :: String.t() | [String.t(), ...]
        when type_name: String.t(),
             required?: boolean

  def maybe_nullable(type_name, true) when is_binary(type_name), do: type_name
  def maybe_nullable(type_name, false) when is_binary(type_name), do: [type_name, nil]

  @doc ~S"""
  Validates that the given value is included in the provided list of
  values.
  """
  @spec validate_inclusion(value, Zot.Parameterized.t([term, ...]) | nil) ::
          :ok
          | {:error, [Zot.Issue.t(), ...]}
        when value: term

  def validate_inclusion(_, nil), do: :ok

  def validate_inclusion(value, %Zot.Parameterized{} = list) do
    case value in list.value do
      true -> :ok
      false -> {:error, [issue(list.params.error, expected: {:disjunction, list.value}, actual: value)]}
    end
  end

  @doc ~S"""
  Validates the length of a string, a list or a map against a set of
  constraints.

  **Constraints:**
  - `:is` - validates the exact length;
  - `:min` - validates the minimum length; and
  - `:max` - validates the maximum length.
  """
  @spec validate_length(value, [constraint, ...]) ::
          :ok
          | {:error, [Zot.Issue.t(), ...]}
        when value: String.t() | list | map,
             constraint:
               {:is, Zot.Parameterized.t(integer) | nil}
               | {:min, Zot.Parameterized.t(integer) | nil}
               | {:max, Zot.Parameterized.t(integer) | nil}

  def validate_length(value, [_ | _] = constraints) do
    actual =
      cond do
        is_binary(value) -> String.length(value)
        is_list(value) -> length(value)
        is_non_struct_map(value) -> map_size(value)
      end

    Enum.reduce_while(constraints, :ok, fn
      {_, nil}, acc ->
        {:cont, acc}

      {op, expected = %Zot.Parameterized{}}, _ ->
        case eval(op, expected.value, actual) do
          true -> {:cont, :ok}
          false -> {:halt, {:error, [issue(expected.params.error, actual: actual, expected: expected.value)]}}
        end
    end)
  end

  @doc ~S"""
  Validates a number against a set of constraints.

  **Constraints:**
  - `:is` - validates the exact value;
  - `:min` - validates the minimum value; and
  - `:max` - validates the maximum value.
  """
  @spec validate_number(value, [constraint, ...]) ::
          :ok
          | {:error, [Zot.Issue.t(), ...]}
        when value: integer | float | Decimal.t(),
             constraint:
               {:is, Zot.Parameterized.t(integer | float) | nil}
               | {:min, Zot.Parameterized.t(integer | float) | nil}
               | {:max, Zot.Parameterized.t(integer | float) | nil}

  def validate_number(value, [_ | _] = constraints) do
    actual = n(value)

    Enum.reduce_while(constraints, :ok, fn
      {_, nil}, acc ->
        {:cont, acc}

      {op, expected = %Zot.Parameterized{}}, _ ->
        case eval(op, n(expected.value), actual) do
          true -> {:cont, :ok}
          false -> {:halt, {:error, [issue(expected.params.error, actual: actual, expected: expected.value)]}}
        end
    end)
  end

  @doc ~S"""
  Validates a string against a regex pattern.
  """
  @spec validate_regex(value, Zot.Parameterized.t(Regex.t()) | nil) ::
          :ok
          | {:error, [Zot.Issue.t(), ...]}
        when value: String.t()

  def validate_regex(_, nil), do: :ok

  def validate_regex(value, %Zot.Parameterized{} = regex) when is_binary(value) do
    case Regex.match?(regex.value, value) do
      true -> :ok
      false -> {:error, [issue(regex.params.error, pattern: regex.value)]}
    end
  end

  @doc ~S"""
  Validates the type of a value against an expected type.
  """
  @spec validate_type(value, [constraint, ...]) ::
          :ok
          | {:error, [Zot.Issue.t(), ...]}
        when value: term,
             constraint: {:is, String.t()}

  def validate_type(value, is: expected) do
    case typeof(value, expected) do
      ^expected -> :ok
      actual -> {:error, [issue("expected type %{expected}, got %{actual}", expected: {:escaped, expected}, actual: {:escaped, actual})]}
    end
  end

  @doc ~S"""
  Validates the given value using a custom parameterized function.
  """
  @spec validate_with(value, validator | nil) :: :ok | {:error, [Zot.Issue.t(), ...]}
        when value: term,
             validator: Zot.Parameterized.t((term -> boolean))

  def validate_with(_, nil), do: :ok

  def validate_with(value, %Zot.Parameterized{value: fun} = validator) when is_function(fun, 1) do
    case fun.(value) do
      true -> :ok
      false -> {:error, [issue(validator.params.error, actual: value)]}
    end
  end

  #
  #   PRIVATE
  #

  defp eval(:is, expected, actual), do: actual == expected
  defp eval(:min, expected, actual), do: actual >= expected
  defp eval(:max, expected, actual), do: actual <= expected
  defp eval(op, _, _), do: raise(ArgumentError, "Unknown constraint operator #{inspect(op)}")

  # to [n]umber
  defp n(value) when is_number(value), do: value
  defp n(%Decimal{} = value), do: Decimal.to_float(value)

  defp typeof(value, hint)
  defp typeof(nil, _), do: "nil"
  defp typeof(value, _) when is_boolean(value), do: "boolean"
  defp typeof(value, _) when is_atom(value), do: "atom"
  defp typeof(value, _) when is_binary(value), do: "string"
  defp typeof(value, _) when is_bitstring(value), do: "bitstring"
  defp typeof(value, "number") when is_float(value), do: "number"
  defp typeof(value, _) when is_float(value), do: "float"
  defp typeof(value, "number") when is_integer(value), do: "number"
  defp typeof(value, _) when is_integer(value), do: "integer"
  defp typeof([], "keyword"), do: "keyword"
  defp typeof([{a, _} | _], "keyword") when is_atom(a), do: "keyword"
  defp typeof(value, _) when is_list(value), do: "list"
  defp typeof(%mod{}, _), do: name(mod)
  defp typeof(%{__struct__: mod}, _), do: name(mod)
  defp typeof(value, _) when is_non_struct_map(value), do: "map"
  defp typeof(value, _) when is_tuple(value), do: "tuple"
  defp typeof(value, _) when is_function(value), do: "function"
  defp typeof(value, _) when is_pid(value), do: "pid"
  defp typeof(value, _) when is_port(value), do: "port"
  defp typeof(value, _) when is_reference(value), do: "reference"
  defp typeof(value, _), do: raise(ArgumentError, "Unabled to determine type of value #{inspect(value)}")

  defp name(mod) when is_atom(mod), do: String.replace(to_string(mod), ~r/^Elixir\./, "")
end
