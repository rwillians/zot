defmodule Zot.Context do
  @moduledoc ~S"""
  Contextual information about a value subject to parsing / validation.
  """

  import Zot.Issue, only: [prepend_path: 2]

  alias __MODULE__
  alias Zot.Issue

  @typedoc false
  @type t :: %Context{
          issues: [Issue.t()],
          input: term,
          parse_score: non_neg_integer,
          parsed: term,
          type: Zot.Type.t(),
          valid?: boolean
        }

  defstruct issues: [],
            input: nil,
            parse_score: 0,
            parsed: nil,
            path: [],
            type: nil,
            valid?: true

  @doc ~S"""
  Creates a new context.
  """
  def new(%_{} = type, path \\ [], input)
      when is_list(path),
      do: %Context{path: path, input: input, type: type}

  @doc ~S"""
  Adds an issue to the context.
  """
  @spec add_issue(ctx :: t, issue :: Zot.Issue.t()) :: t
  @spec add_issue(ctx :: t, message :: String.t()) :: t
  @spec add_issue(ctx :: t, template :: String.t(), variables :: keyword) :: t

  def add_issue(%Context{} = ctx, %Issue{} = issue),
    do: %{ctx | issues: [issue | ctx.issues], valid?: false}

  def add_issue(%Context{} = ctx, message)
      when is_binary(message),
      do: add_issue(ctx, %Issue{template: message})

  def add_issue(%Context{} = ctx, template, [{_, _} | _] = variables)
      when is_binary(template),
      do: add_issue(ctx, %Issue{template: template, variables: variables})

  @doc ~S"""
  Gets the issues from the context, prepending the context's path to
  each issue.
  """
  @spec get_issues(ctx :: t) :: [Zot.Issue.t()]

  def get_issues(%Context{} = ctx), do: Enum.map(ctx.issues, &prepend_path(&1, ctx.path))

  @doc ~S"""
  Gets the parsed value from the context.
  """
  @spec get_parsed(ctx :: t) :: term

  def get_parsed(%Context{} = ctx), do: ctx.parsed

  @doc ~S"""
  Sets the path of the context.
  """
  @spec put_path(ctx :: t, path :: [term]) :: t

  def put_path(%Context{} = ctx, path)
      when is_list(path),
      do: %{ctx | path: path}

  @doc ~S"""
  Parses the given context.
  """
  @spec parse(ctx :: t, opts :: keyword) :: t

  def parse(%Context{} = ctx, opts \\ []) do
    with %Context{valid?: true} = ctx <- parse_type(ctx, opts),
         %Context{valid?: true} = ctx <- apply_effects(ctx),
         do: ctx
  end

  @doc ~S"""
  Checks whether the context is valid.
  """
  @spec valid?(ctx :: t) :: boolean

  def valid?(%Context{} = ctx), do: ctx.valid?

  #
  #   PRIVATE
  #

  defp parse_type(%Context{} = ctx, opts) do
    case Zot.Type.parse(ctx.type, ctx.input, opts) do
      {:ok, value} -> ctx |> put_parsed(value)
      {:error, issues} -> ctx |> add_issues(issues)
      #                ↓ the type has explicitly provided a partial success
      {:error, issues, parsed} -> ctx |> add_issues(issues) |> put_parsed(parsed)
    end
  end

  defp apply_effects(%Context{} = ctx) do
    Enum.reduce_while(ctx.type.__effects__, ctx, fn effect, acc ->
      case apply_effect(acc, effect) do
        {:ok, acc} -> {:cont, acc}
        {:error, acc} -> {:halt, acc}
      end
    end)
  end

  defp apply_effect(%Context{} = ctx, {:refine, fun, error}) do
    case call(fun, ctx.parsed) do
      true -> {:ok, ctx}
      :ok -> {:ok, ctx}
      false -> {:error, add_issue(ctx, error)}
      {:error, <<error::binary>>} -> {:error, add_issue(ctx, error)}
    end
  end

  defp apply_effect(%Context{} = ctx, {:transform, fun}) do
    case call(fun, ctx.parsed) do
      {:ok, value} -> {:ok, put_parsed(ctx, value)}
      {:error, <<error::binary>>} -> {:error, add_issue(ctx, error)}
      {:error, %_{} = error} -> {:error, add_issue(ctx, Exception.message(error))}
      value -> {:ok, put_parsed(ctx, value)}
    end
  end

  defp call({m, f, a}, value), do: apply(m, f, [value | a])
  defp call(fun, value), do: fun.(value)

  defp put_parsed(ctx, parsed), do: %{ctx | parsed: parsed, parse_score: score(parsed)}

  defp add_issues(ctx, []), do: ctx
  defp add_issues(ctx, [_ | _] = issues), do: Enum.reduce(issues, ctx, &add_issue(&2, &1))

  #          ↓ each kv item in a keyword or map
  defp score({_, value}), do: score(value)
  defp score(value) when is_list(value) or is_non_struct_map(value), do: Enum.sum(Enum.map(value, &score/1)) + 1
  defp score(%_{} = value), do: score(Map.from_struct(value)) + 1
  defp score(nil), do: 0
  defp score(_), do: 1
end
