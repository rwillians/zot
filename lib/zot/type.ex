defprotocol Zot.Type do
  @moduledoc ~S"""
  Protocol for defining Zot types.
  """

  @typedoc ~S"""
  Raw input value.
  """
  @type input :: term

  @typedoc ~S"""
  Parsed and validated value.
  """
  @type output :: term

  @typedoc ~S"""
  The portion of an invalid input that was successfully parsed and
  validated.
  """
  @type partial :: term

  @doc ~S"""
  Parses a value according to the given type.
  """
  @spec parse(t, input, [option]) ::
          {:ok, output}
          | {:error, [Zot.Issue.t(), ...]}
          | {:error, [Zot.Issue.t(), ...], partial}
        when option: {:coerce, boolean | :unsafe} | {atom, term}

  def parse(type, value, opts \\ [])

  @doc ~S"""
  Converts the type into a JSON Schema.
  """
  @spec json_schema(t) :: map

  def json_schema(type)
end
