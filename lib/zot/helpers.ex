defmodule Zot.Helpers do
  @moduledoc false

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                          GUARD CLAUSES                          #
  #                 keep them sorted alphabetically                 #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Guard clause that matches an `mfa` tuple.

      iex> is_mfa({MyModule, :my_function, []})
      true

      iex> is_mfa({"MyModule", :my_function, []})
      false

      iex> is_mfa({MyModule, "my_function", []})
      false

      iex> is_mfa({MyModule, :my_function, nil})
      false

  """
  defguard is_mfa(value)
           when is_tuple(value) and
                  tuple_size(value) == 3 and
                  is_atom(elem(value, 0)) and
                  is_atom(elem(value, 1)) and
                  is_list(elem(value, 2))

  @doc ~S"""
  Guard clause that matches a non-empty string.

      iex> is_non_empty_string("hello")
      true

      iex> is_non_empty_string("")
      false

      iex> is_non_empty_string(:hello)
      false

  """
  defguard is_non_empty_string(value)
           when is_binary(value) and byte_size(value) > 0

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                             MACROS                              #
  #                 keep them sorted alphabetically                 #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Excludes types from the given type.

      iex> type = quote(do: :a | :b | :c)
      iex> exclude(type, :b | :c)
      quote(do: :a)

  """
  @spec exclude(Macro.t(), Macro.t()) :: Macro.t()

  defmacro exclude(type, types) do
    types = deunion(types)

    quote location: :keep do
      unquote(type)
      |> Zot.Helpers.deunion()
      |> Enum.reject(&(&1 in unquote(types)))
      |> Zot.Helpers.union()
    end
  end

  @doc ~S"""
  Pattern matches the AST for type `Zot.Parameterized.t/1`, extracting
  its inner type.
  """
  defmacro parameterized(inner_type) do
    quote do
      {{:., _, [{:__aliases__, _, [:Zot, :Parameterized]}, :t]}, _, [unquote(inner_type)]}
    end
  end


  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                            FUNCTIONS                            #
  #                 keep them sorted alphabetically                 #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Determines whether coercion is enabled from the given parser options.
  """
  @spec coerce?(opts) :: boolean | atom
        when opts: keyword

  def coerce?([]), do: false
  def coerce?([{_, _} | _] = opts), do: Keyword.get(opts, :coerce, false)

  @doc ~S"""
  Splits a union type into a list of its component types.
  """
  @spec deunion(Macro.t()) :: [Macro.t(), ...]

  def deunion({:|, _, [left, right]}), do: [left | deunion(right)]
  def deunion({:none, _, _}), do: []
  def deunion(other), do: [other]

  @doc ~S"""
  Returns the given module's name without the `"Elixir."` prefix.
  """
  @spec name(module) :: String.t()

  def name(mod) when is_atom(mod), do: String.replace(to_string(mod), ~r/^Elixir\./, "")

  @doc ~S"""
  Parses a float from the given string.
  """
  @spec parse_float(String.t()) :: {:ok, float} | :error

  def parse_float(value), do: with({float, ""} <- Float.parse(value), do: {:ok, float}, else: (_ -> :error))

  @doc ~S"""
  Parses an integer from the given string.
  """
  @spec parse_integer(String.t()) :: {:ok, integer} | :error

  def parse_integer(value), do: with({int, ""} <- Integer.parse(value), do: {:ok, int}, else: (_ -> :error))

  @doc ~S"""
  Resolves a value that may be an mfa or a function.
  """
  @spec resolve(mfa | (-> term) | term) :: term

  def resolve({m, f, a} = mfa) when is_mfa(mfa), do: apply(m, f, a)
  def resolve(fun) when is_function(fun, 0), do: fun.()
  def resolve(value), do: value

  @doc ~S"""
  Casts a string into an atom, only creating a new atom if it doesn't
  exist yet.
  """
  @spec to_atom_safe(value) :: atom()
        when value: String.t() | atom()

  def to_atom_safe(value)
      when is_atom(value),
      do: value

  def to_atom_safe(<<str::binary>>) do
    String.to_existing_atom(str)
  rescue
    _ -> String.to_atom(str)
  end

  @doc ~S"""
  Returns the type of the given value as a string.
  """
  @spec typeof(term) :: String.t()

  def typeof(nil), do: "nil"
  def typeof(value) when is_boolean(value), do: "boolean"
  def typeof(value) when is_atom(value), do: "atom"
  def typeof(value) when is_binary(value), do: "string"
  def typeof(value) when is_bitstring(value), do: "bitstring"
  def typeof(value) when is_float(value), do: "float"
  def typeof(value) when is_integer(value), do: "integer"
  def typeof([{_, _} | _]), do: "keyword"
  def typeof(value) when is_list(value), do: "list"
  def typeof(%mod{}), do: name(mod)
  def typeof(%{__struct__: mod}), do: name(mod)
  def typeof(value) when is_map(value), do: "map"
  def typeof(value) when is_tuple(value), do: "tuple"
  def typeof(value) when is_function(value), do: "function"
  def typeof(value) when is_pid(value), do: "pid"
  def typeof(value) when is_port(value), do: "port"
  def typeof(value) when is_reference(value), do: "reference"
  def typeof(value), do: raise(ArgumentError, "Unabled to determine type of value #{inspect(value)}")

  @doc ~S"""
  Combines a list of types into a union type.
  """
  @spec union([Macro.t()]) :: Macro.t()

  def union([]), do: quote(do: none)

  def union([_ | _] = types) do
    [last | rest] =
      types
      |> Enum.uniq()
      |> :lists.reverse()

    Enum.reduce(rest, last, &{:|, [], [&1, &2]})
  end
end
