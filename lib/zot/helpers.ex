defmodule Zot.Helpers do
  @moduledoc false

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                          GUARD CLAUSES                          #
  #                 keep them sorted alphabetically                 #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Guard clause that matches a keyword (as best as it can).
  """
  defguard is_keyword(value)
           when is_list(value) and
                  (length(value) == 0 or
                     (is_tuple(hd(value)) and
                        tuple_size(hd(value)) == 2 and
                        is_atom(elem(hd(value), 0))))

  @doc ~S"""
  Guard clause that matches an `mfa` tuple.
  """
  defguard is_mfa(value)
           when is_tuple(value) and
                  tuple_size(value) == 3 and
                  is_atom(elem(value, 0)) and
                  is_atom(elem(value, 1)) and
                  is_list(elem(value, 2))

  @doc ~S"""
  Guard clause that matches a non-empty string.
  """
  defguard is_non_empty_string(value)
           when is_binary(value) and byte_size(value) > 0

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                             MACROS                              #
  #                 keep them sorted alphabetically                 #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Excludes types from the given type.
  """
  @spec exclude(Macro.t(), Macro.t()) :: Macro.t()

  defmacro exclude(type, types) do
    types = deunionize(types)

    quote location: :keep do
      unquote(type)
      |> Zot.Helpers.deunionize()
      |> Enum.reject(&(&1 in unquote(types)))
      |> Zot.Helpers.unionize()
    end
  end

  @doc ~S"""
  Pattern matches a [n]on-[e]mpty [s]tring.
  """
  defmacro nes(var), do: quote(do: <<_, _::binary>> = unquote(var))

  @doc ~S"""
  Pattern matches the AST for type `Zot.Parameterized.t/1`, extracting its
  inner type.
  """
  defmacro parameterized(var) do
    quote do
      {{:., _, [{:__aliases__, _, [:Zot, :Parameterized]}, :t]}, _, [unquote(var)]}
    end
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                            FUNCTIONS                            #
  #                 keep them sorted alphabetically                 #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Splits a union type into a list of its component types.
  """
  @spec deunionize(Macro.t()) :: [Macro.t(), ...]

  def deunionize({:|, _, [left, right]}), do: [left | deunionize(right)]
  def deunionize({:none, _, _}), do: []
  def deunionize(other), do: [other]

  @doc ~S"""
  Returns a human-readable list as string from the given list.
  """
  @spec human_readable_list([value, ...], [option]) :: String.t()
        when value: String.t() | String.Chars.t(),
             option: {:conjunction, :and | :or}

  def human_readable_list([head]), do: "#{head}"

  def human_readable_list([_, _ | _] = list, opts \\ []) do
    conjunction =
      case Keyword.get(opts, :conjunction, :and) do
        :and -> "and"
        :or -> "or"
        value -> raise(ArgumentError, "Expected conjunction to be either :and or :or, got: #{inspect(value)}")
      end

    [last, second_last | rest] =
      list
      |> Enum.map(&to_string/1)
      |> :lists.reverse()

    rest
    |> :lists.reverse()
    |> Enum.concat(["#{second_last} #{conjunction} #{last}"])
    |> Enum.join(", ")
  end

  @doc ~S"""
  Invokes the given mfa or function.
  """
  @spec invoke(mfa | (-> term)) :: term

  def invoke({m, f, a} = mfa) when is_mfa(mfa), do: apply(m, f, a)
  def invoke(fun) when is_function(fun, 0), do: fun.()

  @doc ~S"""
  Invokes the given mfa or function with the given value as the first
  argument.
  """
  @spec invoke(mfa | (term -> term), term) :: term

  def invoke({m, f, a} = mfa, value) when is_mfa(mfa), do: apply(m, f, [value | a])
  def invoke(fun, value) when is_function(fun, 1), do: fun.(value)

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
  def resolve(mfa) when is_mfa(mfa), do: invoke(mfa)
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
  def typeof(value) when is_list(value), do: if(Keyword.keyword?(value), do: "keyword", else: "list")
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
  @spec unionize([Macro.t()]) :: Macro.t()

  def unionize([]), do: quote(do: none)

  def unionize([_ | _] = types) do
    [last | rest] =
      types
      |> Enum.uniq()
      |> :lists.reverse()

    Enum.reduce(rest, last, &{:|, [], [&1, &2]})
  end
end
