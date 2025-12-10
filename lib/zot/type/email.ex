defmodule Zot.Type.Email do
  @moduledoc ~S"""
  Describes a type that accepts email addresses.
  """

  use Zot.Template

  deftype ruleset: {:gmail, t: :gmail | :html5 | :rfc5322 | :unicode}

  def ruleset(%Zot.Type.Email{} = type, value)
      when value in [:gmail, :html5, :rfc5322, :unicode],
      do: %{type | ruleset: value}
end

defimpl Zot.Type, for: Zot.Type.Email do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Email{} = type, value, _) do
    with :ok <- validate_type(value, is: "string"),
         :ok <- validate_email(value, type.ruleset),
         do: {:ok, value}
  end
end
