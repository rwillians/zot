defmodule Zot.Helpers do
  @moduledoc false

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
  Returns the given module's name without the `"Elixir."` prefix.
  """
  @spec name(module) :: String.t()

  def name(mod) when is_atom(mod), do: String.replace(to_string(mod), ~r/^Elixir\./, "")

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
end
