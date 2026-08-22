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
                  elem(value, 2) == [{:from, :now}]

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
      %unquote(var){__zot_type__: true}
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
  Compiles a glob pattern into an anchored regex.

  `*` matches any run of characters short of a `/`, `?` matches exactly
  one of the same, `**` also crosses slashes, `[a-c]` and `[!a-c]` are
  character classes, and `{jpg,png}` matches either alternative.
  Everything else means itself.
  """
  @spec glob(glob) :: Regex.t()
        when glob: String.t()

  def glob(glob)
      when is_binary(glob),
      do: Regex.compile!("^" <> translate(glob) <> "$")

  defp translate(<<>>), do: ""
  defp translate("**/" <> rest), do: "(?:.{0,}/)?" <> translate(rest)
  defp translate("**" <> rest), do: ".{0,}" <> translate(rest)
  defp translate("*" <> rest), do: "[^/]{0,}" <> translate(rest)
  defp translate("?" <> rest), do: "[^/]" <> translate(rest)
  defp translate("[!" <> rest), do: klass(rest, "[^")
  defp translate("[" <> rest), do: klass(rest, "[")
  defp translate("{" <> rest), do: alternatives(rest)
  defp translate(<<char::utf8, rest::binary>>), do: Regex.escape(<<char::utf8>>) <> translate(rest)

  defp klass(rest, open) do
    case String.split(rest, "]", parts: 2) do
      [inside, rest] -> open <> String.replace(inside, "\\", "\\\\") <> "]" <> translate(rest)
      [rest] -> "\\[" <> translate(bang_of(open) <> rest)
    end
  end

  defp bang_of("[^"), do: "!"
  defp bang_of("["), do: ""

  #  ↓ each alternative is a glob of its own, so a `*` inside braces
  #    still means what it means outside them
  defp alternatives(rest) do
    case String.split(rest, "}", parts: 2) do
      [inside, rest] -> "(?:" <> Enum.map_join(String.split(inside, ","), "|", &translate/1) <> ")" <> translate(rest)
      [rest] -> "\\{" <> translate(rest)
    end
  end

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
  def resolve({n, unit, from: :now} = relative) when is_relative(relative), do: DateTime.add(DateTime.utc_now(), n, unit)
  def resolve(value), do: value

  defp normalize(value) do
    case value do
      {:ok, value} -> value
      {:error, reason} -> raise reason
      nil -> raise RuntimeError, "value cannot be nil"
      value -> value
    end
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  # CALLBACKS                                                       #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc false
  def __drop_nil_fields__(map) when is_non_struct_map(map) do
    map
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  def __drop_nil_fields__(keyword) when is_list(keyword),
    do: Enum.reject(keyword, fn {_, value} -> is_nil(value) end)
end
