defmodule Zot.Commons do
  @moduledoc ~S"""
  Common functions and macros used across type implementations.
  """
  @moduledoc since: "0.1.0"

  import Zot.Helpers, only: [typeof: 1]
  import Zot.Issue, only: [issue: 2]

  @doc ~S"""
  Imports common functions and macros used across type implementations.
  """
  @doc since: "0.1.0"
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      import Zot.Helpers, only: [typeof: 1]
      import Zot.Issue, only: [issue: 1, issue: 2, issue: 3]

      alias Zot.Context
    end
  end

  @doc ~S"""
  Validates that the given raw value is of the expected type.
  """
  @doc since: "0.1.0"
  def validate_type([], is: "list"), do: :ok
  def validate_type([], is: "keyword"), do: :ok

  def validate_type(value, is: expected) when is_binary(expected) do
    actual = typeof(value)

    vars = [
      expected: {:unquoted, expected},
      actual: {:unquoted, actual}
    ]

    if actual == expected,
      do: :ok,
      else: {:error, [issue("expected type %{expected}, got %{actual}", vars)]}
  end

  def validate_type(value, in: [_ | _] = expected) do
    if Enum.any?(expected, &(validate_type(value, is: &1) == :ok)) do
      :ok
    else
      variables = [
        expected: {:disjunction, expected, []},
        actual: {:unquoted, typeof(value)}
      ]

      {:error, [issue("expected type to be one of %{expected}, got %{actual}", variables)]}
    end
  end
end
