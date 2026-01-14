defmodule Zot.Template do
  @moduledoc ~S"""
  Utility module for defining Zot types.
  """

  @doc ~S"""
  """
  defmacro __using__(_) do
    quote do
      import Kernel, except: [min: 2, max: 2]
      import Zot.Parameterized, only: [p: 3]
      import Zot.Utils

      import unquote(__MODULE__)
    end
  end

  @doc ~S"""
  Macro for defining a Zot type.
  """
  defmacro deftype(ast) do
    shared_fields = [required: true, default: nil, effects: [], description: nil, example: nil, private: %{}]
    struct_fields = Macro.escape(Keyword.keys(ast) ++ shared_fields ++ [__zot_type__: true])
    defaults = Enum.map(ast, fn {field, opts} -> {field, Keyword.get(opts, :default)} end)

    quote do
      defstruct unquote(struct_fields)

      @doc false
      unquote(build_constructor(ast, defaults))
    end
  end

  #
  #   PRIVATE
  #

  defp build_constructor([], _) do
    quote do
      def new, do: %__MODULE__{}
    end
  end

  defp build_constructor(ast, defaults) do
    reducer_fn =
      {:fn, [],
        ast
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.flat_map(&reducer_fn_modifier_clauses/1)
        |> Enum.concat([reducer_fn_raise_clause()])}

    quote do
      def new(opts \\ []) do
        unquote(defaults)
        |> Keyword.merge(opts)
        |> Enum.reduce(%__MODULE__{}, unquote(reducer_fn))
      end
    end
  end

  defp reducer_fn_modifier_clauses({modifier, _}) do
    [
      {:->, [],
       [
         [{modifier, {:value, [], __MODULE__}}, {:type, [], __MODULE__}],
         {modifier, [], [{:type, [], __MODULE__}, {:value, [], __MODULE__}]}
       ]}
    ]
  end

  defp reducer_fn_raise_clause do
    modifier = {:modifier, [], __MODULE__}

    {:->, [],
     [
       [{modifier, {:_, [], __MODULE__}}, {:_, [], __MODULE__}],
       {:raise, [context: __MODULE__, imports: [{1, Kernel}, {2, Kernel}]],
        [
          {:__aliases__, [alias: false], [:ArgumentError]},
          {:<<>>, [], ["Unknown option :", interpolate(modifier)]}
        ]}
     ]}
  end

  defp interpolate(var), do: {:"::", [], [{{:., [], [Kernel, :to_string]}, [from_interpolation: true], [var]}, {:binary, [], __MODULE__}]}
end
