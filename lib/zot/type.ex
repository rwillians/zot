defprotocol Zot.Type do
  @moduledoc ~S"""
  A protocol for defining types in Zot.
  """
  @moduledoc since: "0.1.0"

  @doc ~S"""
  """
  @spec parse(type, value, opts) ::
          {:ok, parsed_value}
          | {:error, [Zot.Issue.t()]}
          | {:error, [Zot.Issue.t()], partial_value}
        when type: t,
             value: term,
             opts: keyword,
             parsed_value: term,
             partial_value: term

  def parse(type, value, opts \\ [])
end
