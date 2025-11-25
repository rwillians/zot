defprotocol Zot.Type do
  @moduledoc ~S"""
  A protocol describing what's expected of a zot type.
  """
  @moduledoc since: "0.1.0"

  @doc ~S"""
  Parses the given value according to the given type.

  ## Options

  * `:coerce` - when `true`, attempts to deeply coerce the value into
    the expected type before validation. Defaults to `false`.
  """
  @spec parse(type :: t, value :: any, [option]) :: {:ok, term} | {:error, [Zot.Issue.t(), ...]}
        when option: {:coerce, boolean}

  def parse(type, value, opts \\ [])
end
