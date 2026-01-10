defmodule Zot.Utils do
  @moduledoc ~S"""
  Private utility functions.
  """

  @doc ~S"""
  Checks if the given value is an MFA tuple.
  """
  defguard is_mfa(value)
           when is_tuple(value) and
                  tuple_size(value) == 3 and
                  is_atom(elem(value, 0)) and
                  is_atom(elem(value, 1)) and
                  is_list(elem(value, 2))

  @doc ~S"""
  Checks if the given value is a relative date time tuple.
  """
  defguard is_relative(value)
    when is_tuple(value) and
          tuple_size(value) == 3 and
          is_integer(elem(value, 0)) and
          elem(value, 1) in [:second, :minute, :hour, :day, :week, :month, :year] and
          elem(value, 2) == :from_now

  @doc ~S"""
  Checks if the given value is a valid path segment.
  """
  defguard is_segment(value)
           when (is_atom(value) and not is_nil(value)) or is_binary(value) or (is_integer(value) and value > -1)

  @doc ~S"""
  Retrieves the `:coerce` flag from the given options.
  """
  @spec get_coerce_flag(keyword) :: boolean

  def get_coerce_flag(opts)
      when is_list(opts),
      do: Keyword.get(opts, :coerce) || false

  @doc ~S"""
  Resolves the given value which can be a literal value, a function or
  an MFA tuple.
  """
  @spec resolve(mfa) :: term
  @spec resolve((-> term)) :: term
  @spec resolve(term) :: term

  def resolve({m, f, a} = mfa) when is_mfa(mfa), do: normalize(apply(m, f, a))
  def resolve(fun) when is_function(fun, 0), do: normalize(fun.())
  def resolve({n, unit, :from_now} = relative) when is_relative(relative), do: DateTime.add(DateTime.utc_now(), n, unit)
  def resolve(value), do: value

  defp normalize(value) do
    case value do
      {:ok, value} -> value
      {:error, reason} -> raise reason
      nil -> raise RuntimeError, "default value cannot be nil"
      value -> value
    end
  end
end
