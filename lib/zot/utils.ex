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
  Pattern matches a Zot type struct, assigning its module to the given
  variable.
  """
  defmacro type(var) do
    quote do
      %unquote(var){
        __zot_type__: true,
        required: _,
        default: _,
        effects: _,
        description: _,
        example: _,
        private: %{}
      }
    end
  end

  @doc ~S"""
  Retrieves the `:coerce` flag from the given options.
  """
  @spec coerce_flag(keyword) :: boolean | :unsafe

  def coerce_flag(opts)
      when is_list(opts),
      do: Keyword.get(opts, :coerce) || false

  @doc ~S"""
  Parses an float from the given value.
  """
  @spec parse_float(term) :: {:ok, float} | :error

  def parse_float(""), do: :error
  def parse_float(value) when is_binary(value), do: with({float, ""} <- Float.parse(value), do: {:ok, float}, else: (_ -> :error))
  def parse_float(_), do: :error

  @doc ~S"""
  Parses an integer from the given value.
  """
  @spec parse_integer(term) :: {:ok, integer} | :error

  def parse_integer(""), do: :error
  def parse_integer(value) when is_binary(value), do: with({int, ""} <- Integer.parse(value), do: {:ok, int}, else: (_ -> :error))
  def parse_integer(_), do: :error

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
