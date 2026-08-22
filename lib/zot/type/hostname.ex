defmodule Zot.Type.Hostname do
  @moduledoc ~S"""
  Describes a hostname string type.

  A valid hostname is a sequence of dot-separated RFC 1123 labels.
  Each label contains only alphanumeric characters and hyphens, starts
  and ends with an alphanumeric character and is at most 63 characters
  long. The hostname as a whole is at most 253 characters long.
  """

  use Zot.Template

  deftype allow_loopback: [t: boolean, default: true]

  def allow_loopback(%Zot.Type.Hostname{} = type, value \\ true)
      when is_boolean(value),
      do: %{type | allow_loopback: value}
end

defimpl Zot.Type, for: Zot.Type.Hostname do
  use Zot.Commons

  @regex ~r"^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?){0,}$"
  @error "is not a valid hostname"

  @impl Zot.Type
  def parse(%Zot.Type.Hostname{} = type, value, _) do
    with :ok <- validate_type(value, is: "string"),
         :ok <- validate_hostname(value),
         :ok <- validate_loopback(value, type.allow_loopback),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Hostname{} = type) do
    %{
      "description" => type.description,
      "examples" => maybe_examples(type.example),
      "format" => "hostname",
      "maxLength" => 253,
      "pattern" => Regex.source(@regex),
      "type" => maybe_nullable("string", type.required)
    }
  end

  #
  #   PRIVATE
  #

  defp validate_hostname(value) when byte_size(value) > 253, do: {:error, [issue(@error)]}

  defp validate_hostname(value) do
    case Regex.match?(@regex, value) do
      true -> :ok
      false -> {:error, [issue(@error)]}
    end
  end

  defp validate_loopback(_, true), do: :ok

  defp validate_loopback(value, false) do
    host = String.downcase(value)

    cond do
      host == "localhost" -> {:error, [issue("loopback addresses are not allowed")]}
      String.ends_with?(host, ".localhost") -> {:error, [issue("loopback addresses are not allowed")]}
      Zot.Ip.is_ip?(host) and Zot.Ip.loopback?(host) -> {:error, [issue("loopback addresses are not allowed")]}
      true -> :ok
    end
  end
end
