defmodule Zot.Type.Email do
  @moduledoc ~S"""
  A type that accepts email address values.
  """

  use Zot.Template

  deftype ruleset: {:gmail, t: :gmail | :html5 | :rfc5322 | :unicode}

  @doc ~S"""
  Defines which ruleset to use for email validation.
  """
  def ruleset(%Zot.Type.Email{} = type, value)
      when value in [:gmail, :html5, :rfc5322, :unicode],
      do: %{type | ruleset: value}
end

defimpl Zot.Type, for: Zot.Type.Email do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Email{} = type, value, _) do
    with :ok <- validate_type(value, "string"),
         :ok <- validate_email(value, type.ruleset),
         do: {:ok, value}
  end
end
