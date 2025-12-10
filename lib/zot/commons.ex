defmodule Zot.Commons do
  @moduledoc ~S"""
  Common functions and macros used across type implementations.
  """
  @moduledoc since: "0.1.0"

  import Zot.Helpers, only: [resolve: 1, typeof: 1]
  import Zot.Issue, only: [issue: 1, issue: 2]

  @doc ~S"""
  Imports common functions and macros used across type implementations.
  """
  @doc since: "0.1.0"
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      import Zot.Helpers, only: [get_coerce_flag: 1, typeof: 1]
      import Zot.Issue, only: [issue: 1, issue: 2, issue: 3]

      alias Zot.Context
    end
  end

  @doc ~S"""
  Validates the given email address against the specified ruleset.
  """
  def validate_email(email, ruleset \\ :gmail)
  def validate_email("", _), do: {:error, [issue("is not a valid email address")]}

  @gmail ~r/^(?!\.)(?!.*\.\.)([A-Za-z0-9_'+\-\.]*)[A-Za-z0-9_+-]@([A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}$/
  @html5 ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
  @rfc5322 ~r/^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
  @unicode ~r/^[^\s@"]{1,64}@[^\s@]{1,255}$/u

  def validate_email(value, ruleset) do
    regex =
      case ruleset do
        :gmail -> @gmail
        :html5 -> @html5
        :rfc5322 -> @rfc5322
        :unicode -> @unicode
      end

    case Regex.match?(regex, value) do
      true -> :ok
      false -> {:error, [issue("is not a valid email address")]}
    end
  end

  @doc ~S"""
  Validates a number against given constraints.
  """
  def validate_number(value, [_ | _] = constraints), do: validate(value, constraints)

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

  #
  #   PRIVATE
  #

  defp validate(_, []), do: :ok
  defp validate(value, [{_, {nil, _}} | rest]), do: validate(value, rest)

  defp validate(actual, [{:is, {n, opts}} | rest]) do
    expected = resolve(n)

    case eq(actual, expected) do
      true -> validate(actual, rest)
      false -> {:error, [issue(opts.error, actual: actual, expected: expected)]}
    end
  end

  defp validate(actual, [{:gte, {n, opts}} | rest]) do
    expected = resolve(n)

    case gte(actual, expected) do
      true -> validate(actual, rest)
      false -> {:error, [issue(opts.error, actual: actual, expected: expected)]}
    end
  end

  defp validate(actual, [{:lte, {n, opts}} | rest]) do
    expected = resolve(n)

    case lte(actual, expected) do
      true -> validate(actual, rest)
      false -> {:error, [issue(opts.error, actual: actual, expected: expected)]}
    end
  end

  defp eq(a, b) when is_number(a) and is_number(b), do: (a * 1.0) == (b * 1.0)
  defp eq(%Date{} = a, %Date{} = b), do: Date.compare(a, b) == :eq
  defp eq(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) == :eq
  defp eq(%Decimal{} = a, %Decimal{} = b), do: Decimal.equal?(a, b)
  defp eq(%Time{} = a, %Time{} = b), do: Time.compare(a, b) == :eq

  defp gte(a, b) when is_number(a) and is_number(b), do: (a * 1.0) >= (b * 1.0)
  defp gte(%Date{} = a, %Date{} = b), do: Date.compare(a, b) in [:gt, :eq]
  defp gte(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) in [:gt, :eq]
  defp gte(%Decimal{} = a, %Decimal{} = b), do: Decimal.compare(a, b) in [:gt, :eq]
  defp gte(%Time{} = a, %Time{} = b), do: Time.compare(a, b) in [:gt, :eq]

  defp lte(a, b) when is_number(a) and is_number(b), do: (a * 1.0) <= (b * 1.0)
  defp lte(%Date{} = a, %Date{} = b), do: Date.compare(a, b) in [:lt, :eq]
  defp lte(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) in [:lt, :eq]
  defp lte(%Decimal{} = a, %Decimal{} = b), do: Decimal.compare(a, b) in [:lt, :eq]
  defp lte(%Time{} = a, %Time{} = b), do: Time.compare(a, b) in [:lt, :eq]
end
