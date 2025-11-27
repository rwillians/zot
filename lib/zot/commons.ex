defmodule Zot.Commons do
  @moduledoc ~S"""
  Functions that are commonly used across implementations of the
  `Zot.Type` protocol.
  """

  import Zot.Helpers, only: [human_readable_list: 2, nes: 1, typeof: 1]
  import Zot.Issue

  @doc ~S"""
  Imports the commonly used functions.
  """
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      import Zot.Helpers, except: [exclude: 2, parameterized: 1, deunionize: 1, name: 1, unionize: 1]
      import Zot.Issue, only: [append_path: 2, issue: 1, issue: 2, prepend_path: 2]
    end
  end

  @gmail ~r/^(?!\.)(?!.*\.\.)([A-Za-z0-9_'+\-\.]*)[A-Za-z0-9_+-]@([A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}$/
  @html5 ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
  @rfc5322 ~r/^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
  @unicode ~r/^[^\s@"]{1,64}@[^\s@]{1,255}$/u

  @doc ~S"""
  Validates the given email address against the specified ruleset.
  """
  def validate_email(email, ruleset \\ :gmail)

  def validate_email("", _), do: {:error, [issue("is not a valid email address")]}

  def validate_email(nes(value), ruleset) do
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
  Validates the length of the given string or list.
  """
  def validate_length(value, [_ | _] = constraints) when is_binary(value), do: do_validate_number(String.length(value), constraints)
  def validate_length(value, [_ | _] = constraints) when is_list(value), do: do_validate_number(length(value), constraints)

  @doc ~S"""
  Validates the number against the given constraints.
  """
  def validate_number(value, [_ | _] = constraints) when is_number(value), do: do_validate_number(value, constraints)
  def validate_number(%Decimal{} = value, constraints), do: validate_number(Decimal.to_float(value), constraints)

  defp do_validate_number(_, []), do: :ok
  defp do_validate_number(value, [{_, {nil, _}} | rest]), do: do_validate_number(value, rest)

  defp do_validate_number(value, [{:is, {expected, opts}} | rest]) do
    #             ↓ so that, for example, 3.0 is considered equal to 3
    case (value * 1.0) == (expected * 1.0) do
      true -> do_validate_number(value, rest)
      false -> {:error, [issue(opts.error, expected: expected, actual: value)]}
    end
  end

  defp do_validate_number(value, [{:min, {expected, opts}} | rest]) do
    case value >= expected do
      true -> do_validate_number(value, rest)
      false -> {:error, [issue(opts.error, expected: expected, actual: value)]}
    end
  end

  defp do_validate_number(value, [{:max, {expected, opts}} | rest]) do
    case value <= expected do
      true -> do_validate_number(value, rest)
      false -> {:error, [issue(opts.error, expected: expected, actual: value)]}
    end
  end

  @doc ~S"""
  Validates a string against the given regex pattern.
  """
  def validate_regex(_, {nil, _}), do: :ok

  def validate_regex(<<value::binary>>, {%Regex{} = regex, opts}) do
    case Regex.match?(regex, value) do
      true -> :ok
      false -> {:error, [issue(opts.error, pattern: "/#{regex.source}/")]}
    end
  end

  def validate_regex(value, {nes(pattern), opts}), do: validate_regex(value, {Regex.compile!(pattern), opts})

  @doc ~S"""
  Validates the presence of a value.
  """
  def validate_required(nil), do: {:error, [issue("is required")]}
  def validate_required(_), do: :ok

  @doc ~S"""
  Validates that the given value is of the expected type.
  """
  def validate_type([], "list"), do: :ok
  def validate_type([], "keyword"), do: :ok

  def validate_type(value, nes(expected)) do
    case typeof(value) do
      ^expected -> :ok
      actual -> {:error, [issue("expected type %{expected}, got %{actual}", expected: expected, actual: actual)]}
    end
  end

  def validate_type(value, [_ | _] = expected) do
    with false <- Enum.any?(expected, &(typeof(value) == &1)) do
      expected_str = human_readable_list(expected, conjunction: :or)

      {:error, [issue("expected type %{expected}, got %{actual}", expected: expected_str, actual: typeof(value))]}
    else
      true -> :ok
    end
  end
end
