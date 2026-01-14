defmodule Zot.Type.UUID do
  @moduledoc ~S"""
  Describes a UUID string type.
  """

  use Zot.Template

  deftype version: [t: :any | :v1 | :v2 | :v3 | :v4 | :v5 | :v6 | :v7 | :v8, default: :any]

  def version(%Zot.Type.UUID{} = type, value)
      when value in [:any, :v1, :v2, :v3, :v4, :v5, :v6, :v7, :v8],
      do: %{type | version: value}
end

defimpl Zot.Type, for: Zot.Type.UUID do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.UUID{} = type, value, _) do
    with :ok <- validate_type(value, is: "string"),
         :ok <- validate_uuid(type.version, value),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.UUID{} = type) do
    %{
      "description" => type.description,
      "example" => type.example,
      "format" => "uuid",
      "type" => json_type("string", type.required)
    }
  end

  #
  #   PRIVATE
  #

  # matches a uuid of an exact version
  defmacrop uuid(version) when version in [:v1, :v2, :v3, :v4, :v5, :v6, :v7, :v8] do
    vchar =
      case version do
        :v1 -> ?1
        :v2 -> ?2
        :v3 -> ?3
        :v4 -> ?4
        :v5 -> ?5
        :v6 -> ?6
        :v7 -> ?7
        :v8 -> ?8
      end

    quote do
      <<_::binary-size(8), ?-, _::binary-size(4), ?-, unquote(vchar), _::binary-size(3), ?-, _::binary-size(4), ?-, _::binary-size(12)>>
    end
  end

  # matches any uuid and assigns the version character to the given
  # variable
  defmacrop uuid(var) do
    quote do
      <<_::binary-size(8), ?-, _::binary-size(4), ?-, unquote(var)::binary-size(1), _::binary-size(3), ?-, _::binary-size(4), ?-, _::binary-size(12)>>
    end
  end

  defp validate_uuid(:any, value), do: cast(value)
  defp validate_uuid(:v1, uuid(:v1) = value), do: cast(value)
  defp validate_uuid(:v1, uuid(ver)), do: {:error, [issue("expected a uuid %{expected}, got %{actual}", expected: {:escaped, "v1"}, actual: {:escaped, "v#{ver}"})]}
  defp validate_uuid(:v2, uuid(:v2) = value), do: cast(value)
  defp validate_uuid(:v2, uuid(ver)), do: {:error, [issue("expected a uuid %{expected}, got %{actual}", expected: {:escaped, "v2"}, actual: {:escaped, "v#{ver}"})]}
  defp validate_uuid(:v3, uuid(:v3) = value), do: cast(value)
  defp validate_uuid(:v3, uuid(ver)), do: {:error, [issue("expected a uuid %{expected}, got %{actual}", expected: {:escaped, "v3"}, actual: {:escaped, "v#{ver}"})]}
  defp validate_uuid(:v4, uuid(:v4) = value), do: cast(value)
  defp validate_uuid(:v4, uuid(ver)), do: {:error, [issue("expected a uuid %{expected}, got %{actual}", expected: {:escaped, "v4"}, actual: {:escaped, "v#{ver}"})]}
  defp validate_uuid(:v5, uuid(:v5) = value), do: cast(value)
  defp validate_uuid(:v5, uuid(ver)), do: {:error, [issue("expected a uuid %{expected}, got %{actual}", expected: {:escaped, "v5"}, actual: {:escaped, "v#{ver}"})]}
  defp validate_uuid(:v6, uuid(:v6) = value), do: cast(value)
  defp validate_uuid(:v6, uuid(ver)), do: {:error, [issue("expected a uuid %{expected}, got %{actual}", expected: {:escaped, "v6"}, actual: {:escaped, "v#{ver}"})]}
  defp validate_uuid(:v7, uuid(:v7) = value), do: cast(value)
  defp validate_uuid(:v7, uuid(ver)), do: {:error, [issue("expected a uuid %{expected}, got %{actual}", expected: {:escaped, "v7"}, actual: {:escaped, "v#{ver}"})]}
  defp validate_uuid(:v8, uuid(:v8) = value), do: cast(value)
  defp validate_uuid(:v8, uuid(ver)), do: {:error, [issue("expected a uuid %{expected}, got %{actual}", expected: {:escaped, "v8"}, actual: {:escaped, "v#{ver}"})]}
  defp validate_uuid(_, _), do: {:error, [issue("is invalid")]}

  # https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/uuid.ex#L86
  defp cast(<<a1, a2, a3, a4, a5, a6, a7, a8, ?-, b1, b2, b3, b4, ?-, c1, c2, c3, c4, ?-, d1, d2, d3, d4, ?-, e1, e2, e3, e4, e5, e6, e7, e8, e9, e10, e11, e12>>) do
    <<c(a1), c(a2), c(a3), c(a4), c(a5), c(a6), c(a7), c(a8), ?-, c(b1), c(b2), c(b3), c(b4), ?-, c(c1), c(c2), c(c3), c(c4), ?-, c(d1), c(d2), c(d3), c(d4), ?-, c(e1), c(e2),
      c(e3), c(e4), c(e5), c(e6), c(e7), c(e8), c(e9), c(e10), c(e11), c(e12)>>
  catch
    :error -> {:error, [issue("is invalid")]}
  else
    uuid -> {:ok, uuid}
  end

  defp cast(_), do: {:error, [issue("is invalid")]}

  @compile {:inline, c: 1}

  defp c(?0), do: ?0
  defp c(?1), do: ?1
  defp c(?2), do: ?2
  defp c(?3), do: ?3
  defp c(?4), do: ?4
  defp c(?5), do: ?5
  defp c(?6), do: ?6
  defp c(?7), do: ?7
  defp c(?8), do: ?8
  defp c(?9), do: ?9
  defp c(?A), do: ?a
  defp c(?B), do: ?b
  defp c(?C), do: ?c
  defp c(?D), do: ?d
  defp c(?E), do: ?e
  defp c(?F), do: ?f
  defp c(?a), do: ?a
  defp c(?b), do: ?b
  defp c(?c), do: ?c
  defp c(?d), do: ?d
  defp c(?e), do: ?e
  defp c(?f), do: ?f
  defp c(_), do: throw(:error)
end
