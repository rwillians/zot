defmodule Zot.Type.Email do
  @moduledoc ~S"""
  Describes an email type.
  """

  use Zot.Template

  @typedoc ~S"""
  Rulesets that can used for email validation.
  """
  @type roleset :: :gmail | :html5 | :ref5322 | :unicode

  deftype ruleset: [t: ruleset, default: :gmail]

  def ruleset(%Zot.Type.Email{} = type, value)
      when is_nil(value)
      when value in [:gmail, :html5, :ref5322, :unicode],
      do: %{type | ruleset: value || :gmail}
end

defimpl Zot.Type, for: Zot.Type.Email do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Email{} = type, value, _) do
    regex =
      type.ruleset
      |> to_regex()
      |> Zot.Parameterized.new(error: "is invalid")

    with :ok <- validate_type(value, is: "string"),
         :ok <- validate_regex(value, regex),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Email{} = type) do
    %{
      "description" => type.description,
      "example" => type.example,
      "format" => "email",
      "type" => json_type("string", type.required)
    }
  end

  #
  #   PRIVATE
  #

  # Source: https://github.com/colinhacks/zod/blob/6176dcb570186c4945223fa83bcf3221cbfa1af5/packages/zod/src/v4/core/regexes.ts#L33-L50
  defp to_regex(:gmail), do: ~r/^(?!\.)(?!.*\.\.)([A-Za-z0-9_'+\-\.]*)[A-Za-z0-9_+-]@([A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}$/
  defp to_regex(:html5), do: ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
  defp to_regex(:ref5322), do: ~r/^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
  defp to_regex(:unicode), do: ~r/^[^\s@"]{1,64}@[^\s@]{1,255}$/u
end
