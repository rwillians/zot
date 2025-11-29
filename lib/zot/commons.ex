defmodule Zot.Commons do
  @moduledoc ~S"""
  Commonly used functions for implementing a Zot type.
  """

  import Zot.Helpers, only: [f: 1, is_non_empty_string: 1, human_readable_list: 2, resolve: 1, typeof: 1]
  import Zot.Issue, only: [issue: 1, issue: 2]

  @doc ~S"""
  """
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      import Zot.Helpers, except: [deunion: 1, exclude: 2, name: 1, parameterized: 1, union: 1]
      import Zot.Issue, only: [issue: 1, issue: 2, issue: 3, prepend_path: 2]
    end
  end

  @doc ~S"""
  Validates a date against given constraints.
  """
  def validate_date(value, [_ | _] = constraints)
      when is_struct(value, Date),
      do: validate(value, constraints)

  @doc ~S"""
  Validates a date-time against given constraints.
  """
  def validate_date_time(value, [_ | _] = constraints)
      when is_struct(value, DateTime),
      do: validate(value, constraints)


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
  Validates that a string ends with a given suffix.
  """
  def validate_ends_with(_, {nil, _}), do: :ok

  def validate_ends_with(value, {suffix, opts}) do
    case String.ends_with?(value, suffix) do
      true -> :ok
      false -> {:error, [issue(opts.error, suffix: suffix)]}
    end
  end

  @doc ~S"""
  Validates that the given value is included in the set of expected
  values.
  """
  def validate_inclusion(value, [_ | _] = expected) do
    if value in expected do
      :ok
    else
      expected_str =
        expected
        |> Enum.map(&f/1)
        |> human_readable_list(conjunction: :or)

      {:error, [issue("expected one of %{expected}, got %{actual}", expected: {:formated, expected_str}, actual: value)]}
    end
  end

  @doc ~S"""
  Validates the length of a string or list.
  """
  def validate_length(value, [_ | _] = constraints)
      when is_binary(value),
      do: validate(String.length(value), constraints)

  def validate_length(value, [_ | _] = constraints)
      when is_list(value),
      do: validate(length(value), constraints)

  @doc ~S"""
  Validates a number against given constraints.
  """
  def validate_number(value, [_ | _] = constraints)
      when is_number(value),
      do: validate(value, constraints)

  def validate_number(value, [_ | _] = constraints)
      when is_struct(value, Decimal),
      do: validate(Decimal.to_float(value), constraints)

  @doc ~S"""
  Validates a string against a regex pattern.
  """
  def validate_regex(_, {nil, _}), do: :ok

  def validate_regex(<<value::binary>>, {%Regex{} = pattern, opts}) do
    case Regex.match?(pattern, value) do
      true -> :ok
      false -> {:error, [issue(opts.error, pattern: pattern)]}
    end
  end

  def validate_regex(<<value::binary>>, {pattern, opts})
      when is_non_empty_string(pattern),
      do: validate_regex(value, {Regex.compile!(pattern), opts})

  @doc ~S"""
  Validates that a string starts with a given prefix.
  """
  def validate_starts_with(_, {nil, _}), do: :ok

  def validate_starts_with(value, {prefix, opts}) do
    case String.starts_with?(value, prefix) do
      true -> :ok
      false -> {:error, [issue(opts.error, prefix: prefix)]}
    end
  end

  @doc ~S"""
  Validates a time against given constraints.
  """
  def validate_time(value, [_ | _] = constraints)
      when is_struct(value, Time),
      do: validate(value, constraints)

  @doc ~S"""
  Validates that the given value satisfies the expected type.
  """
  def validate_type([], "list"), do: :ok
  def validate_type([], "keyword"), do: :ok

  def validate_type(value, <<expected::binary>>) do
    case typeof(value) do
      ^expected -> :ok
      actual -> {:error, [issue("expected type %{expected}, got %{actual}", expected: {:formated, expected}, actual: {:formated, actual})]}
    end
  end

  def validate_type(value, [_ | _] = expected) do
    if Enum.any?(expected, &(typeof(value) == &1)) do
      :ok
    else
      expected = human_readable_list(expected, conjunction: :or)
      {:error, [issue("expected type %{expected}, got %{actual}", expected: expected, actual: typeof(value))]}
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
  defp eq(%Time{} = a, %Time{} = b), do: Time.compare(a, b) == :eq

  defp gte(a, b) when is_number(a) and is_number(b), do: (a * 1.0) >= (b * 1.0)
  defp gte(%Date{} = a, %Date{} = b), do: Date.compare(a, b) in [:gt, :eq]
  defp gte(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) in [:gt, :eq]
  defp gte(%Time{} = a, %Time{} = b), do: Time.compare(a, b) in [:gt, :eq]

  defp lte(a, b) when is_number(a) and is_number(b), do: (a * 1.0) <= (b * 1.0)
  defp lte(%Date{} = a, %Date{} = b), do: Date.compare(a, b) in [:lt, :eq]
  defp lte(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) in [:lt, :eq]
  defp lte(%Time{} = a, %Time{} = b), do: Time.compare(a, b) in [:lt, :eq]
end
