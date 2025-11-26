defmodule Zot.Template do
  @moduledoc ~S"""
  A set of macros to make it easier to define types.
  """
  @moduledoc since: "0.1.0"

  import Zot.Helpers, only: [exclude: 2, name: 1, parameterized: 1, unionize: 1]

  @doc ~S"""
  """
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      import Zot.Helpers, only: [is_mfa: 1, is_non_empty_string: 1, resolve: 1]
      import Zot.Parameterized, only: [merge_params: 2]

      @builder true
    end
  end

  @doc ~S"""
  Defines the type's modifiers.
  """
  defmacro deftype(ast) do
    caller = __CALLER__
    fields = Keyword.keys(ast)
    types = Macro.prewalk(ast, &extract_type/1)
    builder = builder(ast, caller)

    quote do
      @typedoc ~S"""
      """
      @type t :: %__MODULE__{unquote_splicing(types)}

      defstruct unquote(fields)

      if @builder == true do
        unquote(builder)
      end
    end
  end

  #
  #   PRIVATE
  #

  defp extract_type({field, {_, t: type}}), do: {field, type}
  defp extract_type(other), do: other

  defp builder([], _) do
    quote do
      @doc ~s"""
      Builds a new `#{unquote(name(__MODULE__))}`.
      """
      @spec new() :: t

      def new, do: %__MODULE__{}
    end
  end

  defp builder(ast, caller) do
    defaults = Macro.prewalk(ast, &extract_default/1)

    types =
      ast
      |> Macro.prewalk(&extract_type/1)
      |> Enum.sort_by(&elem(&1, 0))

    reducer_fn =
      {:fn, [],
       types
       |> Enum.flat_map(&reducer_fn_modifier_clauses/1)
       |> Enum.concat([reducer_fn_raise_clause(caller.module)])}

    options =
      types
      |> Enum.flat_map(&builder_option/1)
      |> unionize()

    modifier_specs = Enum.map(types, &modifier_spec/1)

    quote do
      @doc ~s"""
      Builds a new `#{unquote(name(caller.module))}` from the given options.
      """
      @spec new([option]) :: t
            when option: unquote(options)

      def new(opts \\ [])

      def new(opts) when is_list(opts) do
        unquote(defaults)
        |> Keyword.merge(opts)
        |> Enum.reduce(%__MODULE__{}, unquote(reducer_fn))
      end

      unquote({:__block__, [], modifier_specs})
    end
  end

  defp extract_default({field, {default, t: _}}), do: {field, default}
  defp extract_default(other), do: other

  defp reducer_fn_modifier_clauses({modifier, parameterized(_)}) do
    [
      {:->, [],
       [
         [{modifier, {{:value, [], __MODULE__}, {:opts, [], __MODULE__}}}, {:type, [], __MODULE__}],
         {modifier, [], [{:type, [], __MODULE__}, {:value, [], __MODULE__}, {:opts, [], __MODULE__}]}
       ]},
      {:->, [],
       [
         [{modifier, {:value, [], __MODULE__}}, {:type, [], __MODULE__}],
         {modifier, [], [{:type, [], __MODULE__}, {:value, [], __MODULE__}]}
       ]}
    ]
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

  defp reducer_fn_raise_clause(mod) do
    modifier = {:modifier, [], __MODULE__}

    {:->, [],
     [
       [{modifier, {:_, [], __MODULE__}}, {:_, [], __MODULE__}],
       {:raise, [context: __MODULE__, imports: [{1, Kernel}, {2, Kernel}]],
        [
          {:__aliases__, [alias: false], [:ArgumentError]},
          {:<<>>, [], ["[", name(mod), ".new/1] ", "Unknown option :", interpolate(modifier)]}
        ]}
     ]}
  end

  defp interpolate(var), do: {:"::", [], [{{:., [], [Kernel, :to_string]}, [from_interpolation: true], [var]}, {:binary, [], __MODULE__}]}

  defp builder_option({field, parameterized(inner_type)}) do
    inner_type = exclude(inner_type, nil)

    [
      quote(do: {unquote(field), unquote(inner_type)}),
      quote(do: {unquote(field), {unquote(inner_type), error: String.t()}})
    ]
  end

  defp builder_option({field, type}) do
    type = exclude(type, nil)

    [
      quote(do: {unquote(field), unquote(type)})
    ]
  end

  defp modifier_spec({modifier, parameterized(inner_type)}) do
    signature = [
      {modifier, [], [{:type, [], __MODULE__}, {:value, [], __MODULE__}, [{:option, [], __MODULE__}]]},
      {:type, [], __MODULE__}
    ]

    when_fields = [
      type: quote(do: t),
      value: inner_type,
      option: quote(do: {:error, String.t()})
    ]

    {:@, [context: __MODULE__, imports: [{1, Kernel}]],
     [
       {:spec, [context: __MODULE__], [{:when, [], [{:"::", [], signature}, when_fields]}]}
     ]}
  end

  defp modifier_spec({modifier, type}) do
    signature = [
      {modifier, [], [{:type, [], __MODULE__}, {:value, [], __MODULE__}]},
      {:type, [], __MODULE__}
    ]

    when_fields = [
      type: quote(do: t),
      value: type
    ]

    {:@, [context: __MODULE__, imports: [{1, Kernel}]],
     [
       {:spec, [context: __MODULE__], [{:when, [], [{:"::", [], signature}, when_fields]}]}
     ]}
  end
end
