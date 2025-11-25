defmodule Zot.Type.String do
  @moduledoc ~S"""
  A type that accepts string values.
  """

  use Zot.Template

  import Kernel, except: [max: 2, min: 2]

  deftype trim:        {false, t: boolean},
          length:      {nil,   t: Zot.Parameterized.t(nil | pos_integer)},
          min:         {nil,   t: Zot.Parameterized.t(nil | non_neg_integer)},
          max:         {nil,   t: Zot.Parameterized.t(nil | pos_integer)},
          starts_with: {nil,   t: Zot.Parameterized.t(nil | String.t)},
          ends_with:   {nil,   t: Zot.Parameterized.t(nil | String.t)},
          regex:       {nil,   t: Zot.Parameterized.t(nil | Regex.t | String.t)}

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
      do: %{type | length: {value, merge_params(@opts, opts)}}

  @doc ~S"""
  Defines the minimum expected length of the input.
  """
  @opts error: "expected string to have at least %{expected} characters, got %{actual} characters"
  def min(%Zot.Type.String{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value) and value > -1,
      do: %{type | min: {value, merge_params(@opts, opts)}}

  @doc ~S"""
  Defines the maximum expected length of the input.
  """
  @opts error: "expected string to have at most %{expected} characters, got %{actual} characters"
  def max(%Zot.Type.String{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value) and value > 0,
      do: %{type | max: {value, merge_params(@opts, opts)}}

  @doc ~S"""
  Defines an expected prefix for the input.
  """
  @opts error: "expected string to start with '%{prefix}'"
  def starts_with(%Zot.Type.String{} = type, value, opts \\ [])
      when is_nil(value)
      when is_non_empty_string(value),
      do: %{type | starts_with: {value, merge_params(@opts, opts)}}

  @doc ~S"""
  Defines an expected suffix for the input.
  """
  @opts error: "expected string to end with '%{suffix}'"
  def ends_with(%Zot.Type.String{} = type, value, opts \\ [])
      when is_nil(value)
      when is_non_empty_string(value),
      do: %{type | ends_with: {value, merge_params(@opts, opts)}}

  @doc ~S"""
  Defines an expected pattern for the input.
  """
  @opts error: "expected string to match the pattern %{pattern}"
  def regex(%Zot.Type.String{} = type, value, opts \\ [])
      when is_nil(value)
      when is_non_empty_string(value)
      when is_struct(value, Regex),
      do: %{type | regex: {value, merge_params(@opts, opts)}}
end

defimpl Zot.Type, for: Zot.Type.String do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.String{} = type, value, _) do
    with :ok <- validate_required(value),
         :ok <- validate_type(value, "string"),
         value <- trim(value, type.trim),
         :ok <- validate_length(value, is: type.length, min: type.min, max: type.max),
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

  defp validate_starts_with(_, {nil, _}), do: :ok

  defp validate_starts_with(value, {prefix, params}) do
    case String.starts_with?(value, prefix) do
      true -> :ok
      false -> {:error, [issue(params.error, prefix: prefix)]}
    end
  end

  defp validate_ends_with(_, {nil, _}), do: :ok

  defp validate_ends_with(value, {suffix, params}) do
    case String.ends_with?(value, suffix) do
      true -> :ok
      false -> {:error, [issue(params.error, suffix: suffix)]}
    end
  end
end
