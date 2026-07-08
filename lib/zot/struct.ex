defmodule Zot.Struct do
  @moduledoc ~S"""
  Notation for defining a struct with schema validation using Zot.

      defmodule MyApp.PayoutCreated do
        use Zot.Struct

        schema env: Z.enum([:live, :sandbox]),
               wallet_id: Z.uuid(:v7),
               amount: Z.decimal(gt: 0),
               platform_fee: Z.decimal(gt: 0)
      end

  """

  @doc ~S"""
  Returns metadata about the module.
  """
  @callback meta(:schema) :: Zot.Type.Map.t()
  @callback meta(:fields) :: [atom, ...]

  @doc ~S"""
  Returns a new struct where its fields have been parsed/validated.
  """
  @callback new(params, opts) :: {:ok, struct} | {:error, [Zot.Issue.t(), ...]}
            when params: map | keyword,
                 opts: keyword

  @doc ~S"""
  Same as `new/1` but raises an error if failed to new the given
  params.
  """
  @callback new!(params, opts) :: struct
            when params: map | keyword,
                 opts: keyword

  @doc false
  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      import unquote(__MODULE__), only: [schema: 1]

      alias Zot, as: Z
    end
  end

  @doc false
  defmacro schema(expr) do
    fields = Keyword.keys(expr)

    quote do
      @schema unquote(expr)
              |> Enum.into(%{})
              |> Zot.strict_map()

      defstruct unquote(fields)

      @impl unquote(__MODULE__)
      def meta(:schema), do: @schema
      def meta(:fields), do: unquote(fields)

      @impl unquote(__MODULE__)
      def new(params, opts \\ []) do
        with {:ok, data} <- Zot.parse(@schema, params, opts),
             do: {:ok, struct!(__MODULE__, data)}
      end

      @impl unquote(__MODULE__)
      def new!(params, opts \\ []) do
        case Zot.parse(@schema, params, opts) do
          {:ok, data} -> struct!(__MODULE__, data)
          {:error, issues} -> raise unquote(__MODULE__).format(__MODULE__, issues)
        end
      end
    end
  end

  #
  #   CALLBACKS
  #

  @doc false
  def format(mod, issues) do
    prefix = "[#{inspect(mod)}]"
    pad = String.pad_leading("", String.length(prefix), " ")
    red = &(IO.ANSI.red() <> &1 <> IO.ANSI.reset())
    to_string = &to_string/1

    details =
      issues
      |> Enum.map(&{Enum.map_join(&1.path, ".", to_string), Exception.message(&1)})
      |> Enum.map_join("\n", fn {field, message} -> "#{pad} - #{red.(field)}: #{message}" end)

    "#{prefix} Some fields failed validation:\n\n#{details}\n\n"
  end
end
