defmodule Zot.Type.String do
  @moduledoc ~S"""
  A type that accepts strings.
  """

  use Zot.Template

  import Kernel, except: [max: 2, min: 2]

  deftype trim:        {false, t: boolean},
          length:      {nil,   t: p(nil | pos_integer)},
          min:         {nil,   t: p(nil | non_neg_integer)},
          max:         {nil,   t: p(nil | pos_integer)},
          starts_with: {nil,   t: p(nil | String.t)},
          ends_with:   {nil,   t: p(nil | String.t)},
          regex:       {nil,   t: p(nil | Regex.t | String.t)}

  @doc ~S"""
  Defines whether or not to trim the input before validation.
  """
  def trim(%Zot.Type.String{} = type, value)
      when is_boolean(value),
      do: %{type | trim: value}

  @doc ~S"""
  Defines the exact expected length of the input.
  """
  @opts error: "expected string to have exactly %{expected} characters, got %{actual} characters"
  def length(%Zot.Type.String{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value) and value > 0,
      do: %{type | length: parameterized(value, @opts, opts)}

  @doc ~S"""
  Defines the minimum expected length of the input.
  """
  @opts error: "expected string to have at least %{expected} characters, got %{actual} characters"
  def min(%Zot.Type.String{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value) and value > -1,
      do: %{type | min: parameterized(value, @opts, opts)}

  @doc ~S"""
  Defines the maximum expected length of the input.
  """
  @opts error: "expected string to have at most %{expected} characters, got %{actual} characters"
  def max(%Zot.Type.String{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value) and value > 0,
      do: %{type | max: parameterized(value, @opts, opts)}

  @doc ~S"""
  Defines an expected prefix for the input.
  """
  @opts error: "expected string to start with %{prefix}"
  def starts_with(%Zot.Type.String{} = type, value, opts \\ [])
      when is_nil(value)
      when is_non_empty_string(value),
      do: %{type | starts_with: parameterized(value, @opts, opts)}

  @doc ~S"""
  Defines an expected suffix for the input.
  """
  @opts error: "expected string to end with %{suffix}"
  def ends_with(%Zot.Type.String{} = type, value, opts \\ [])
      when is_nil(value)
      when is_non_empty_string(value),
      do: %{type | ends_with: parameterized(value, @opts, opts)}

  @doc ~S"""
  Defines an expected pattern for the input.
  """
  @opts error: "expected string to match the pattern %{pattern}"
  def regex(%Zot.Type.String{} = type, value, opts \\ [])
      when is_nil(value)
      when is_non_empty_string(value)
      when is_struct(value, Regex),
      do: %{type | regex: parameterized(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.String do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.String{} = type, value, _) do
    with :ok <- validate_type(value, "string"),
         value <- trim(value, type.trim),
         :ok <- validate_length(value, is: type.length, gte: type.min, lte: type.max),
         :ok <- validate_starts_with(value, type.starts_with),
         :ok <- validate_ends_with(value, type.ends_with),
         :ok <- validate_regex(value, type.regex),
         do: {:ok, value}
  end

  #
  #   PRIVATE
  #

  defp trim(value, false), do: value
  defp trim(value, true), do: String.trim(value)
end
