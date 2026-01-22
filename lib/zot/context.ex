defmodule Zot.Context do
  @moduledoc ~S"""
  Context management for parsing / validating values.
  """

  import Zot.Issue, only: [issue: 2, issue: 3, prepend_path: 2]
  import Zot.Utils, only: [is_mfa: 1, resolve: 1, zot_type: 1]

  alias __MODULE__

  @typedoc ~S"""
  Represents a segment in a path.
  """
  @type segment :: String.t() | atom | non_neg_integer

  @typedoc ~S"""
  Zot's context struct encapsulates all that is needed to parse and
  validate a value.
  """
  @type t :: %Context{
          type: struct,
          input: term,
          output: term,
          path: [segment],
          issues: [Zot.Issue.t()],
          score: integer,
          opts: keyword,
          valid?: boolean
        }

  defstruct [:type, :input, :output, path: [], issues: [], score: 0, opts: [], valid?: true]

  @doc ~S"""
  Creates a new context.
  """
  @spec new(type, input, opts) :: t
        when type: struct,
             input: term,
             opts: keyword

  def new(zot_type(_) = type, input, opts \\ [])
      when is_list(opts),
      do: %Context{type: type, opts: opts, input: input, output: input}

  @doc ~S"""
  Puts the given path into the context.
  """
  @spec put_path(t, [segment]) :: t

  def put_path(%Context{} = ctx, path)
      when is_list(path),
      do: %{ctx | path: path}

  @doc ~S"""
  Appends new issues to the context, what causes the context to be
  marked as invalid.
  """
  @spec append_issues(t, [Zot.Issue.t()]) :: t

  def append_issues(%Context{} = ctx, []), do: ctx
  def append_issues(%Context{issues: issues} = ctx, [_ | _] = new_issues), do: %{ctx | issues: issues ++ new_issues, valid?: false}

  @doc ~S"""
  Increments the context's score by the given amount.
  """
  @spec inc_score(t, integer) :: t

  def inc_score(ctx, inc \\ 1)
  def inc_score(%Context{} = ctx, 0), do: ctx
  def inc_score(%Context{score: score} = ctx, inc) when is_integer(inc), do: %{ctx | score: score + inc}

  @doc ~S"""
  Checks if the context is valid.
  """
  @spec valid?(t) :: boolean

  def valid?(%Context{} = ctx), do: ctx.valid?

  @doc ~S"""
  Unwraps the Context into an :ok|:error tuple.
  """
  @spec unwrap(t) :: {:ok, term} | {:error, [Zot.Issue.t(), ...]}

  def unwrap(%Context{valid?: true} = ctx), do: {:ok, ctx.output}
  def unwrap(%Context{valid?: false} = ctx), do: {:error, ctx.issues}

  @doc ~S"""
  Parses the given context.
  """
  @spec parse(t) :: t

  def parse(%Context{} = ctx) do
    with {:ok, ctx} <- resolve_default(ctx),
         {:ok, ctx} <- validate_required(ctx),
         {:ok, ctx} <- parse_type(ctx),
         {:ok, ctx} <- apply_effects(ctx) do
      ctx
    else
      {:error, ctx} -> ctx
      {:halt, ctx} -> ctx
    end
  end

  #
  #   PRIVATE
  #

  defp resolve_default(%Context{type: %_{default: nil}, output: nil} = ctx), do: {:ok, ctx}
  defp resolve_default(%Context{type: %_{default: default}, output: nil} = ctx), do: {:ok, %{ctx | output: resolve(default)}}
  defp resolve_default(%Context{} = ctx), do: {:ok, ctx}

  defp validate_required(%Context{type: %_{required: true}, output: nil} = ctx), do: {:error, append_issues(ctx, [issue(ctx.path, "is required")])}
  defp validate_required(%Context{type: %_{required: false}, output: nil} = ctx), do: {:halt, ctx}
  defp validate_required(%Context{} = ctx), do: {:ok, ctx}

  defp parse_type(%Context{} = ctx) do
    case Zot.Type.parse(ctx.type, ctx.output, ctx.opts) do
      {:ok, output} -> {:ok, %{ctx | output: output}}
      {:error, issues} -> {:error, append_issues(%{ctx | output: nil}, prepend_path(issues, ctx.path))}
      {:error, issues, partial} -> {:error, append_issues(inc_score(%{ctx | output: partial}, score(partial)), prepend_path(issues, ctx.path))}
    end
  end

  defp score(nil), do: 0
  defp score(value) when is_struct(value), do: score(Map.from_struct(value))
  defp score(value) when is_map(value), do: 1 + score(Map.values(value))
  defp score([]), do: 1
  defp score([head | tail]), do: score(head) + score(tail)
  defp score({_, value}), do: score(value)
  #    ↑ when iterating over a keyword's k-v tuples
  defp score(_), do: 1

  defp apply_effects(%Context{type: %_{effects: []}} = ctx), do: {:ok, ctx}

  defp apply_effects(%Context{type: %_{effects: effects}} = ctx) do
    Enum.reduce_while(effects, {:ok, ctx}, fn effect, {:ok, acc} ->
      case apply_effect(effect, acc) do
        {:ok, new_ctx} -> {:cont, {:ok, new_ctx}}
        {:error, new_ctx} -> {:halt, {:error, new_ctx}}
      end
    end)
  end

  defp apply_effect({:transform, fun}, ctx), do: {:ok, %{ctx | output: invoke_transform(fun, ctx)}}

  defp apply_effect({:refine, %Zot.Parameterized{} = refinement}, ctx) do
    case invoke_refine(refinement.value, ctx) do
      true -> {:ok, ctx}
      false -> {:error, append_issues(ctx, [issue(ctx.path, refinement.params.error, actual: ctx.output)])}
      %Context{valid?: true} = new_ctx -> {:ok, new_ctx}
      %Context{valid?: false} = new_ctx -> {:error, new_ctx}
      :ok -> {:ok, ctx}
      :error -> {:error, append_issues(ctx, [issue(ctx.path, refinement.params.error, actual: ctx.output)])}
      {:error, <<_, _::binary>> = reason} -> {:error, append_issues(ctx, [issue(ctx.path, reason, actual: ctx.output)])}
      {:error, %_{} = error} -> {:error, append_issues(ctx, [issue(ctx.path, Exception.message(error))])}
    end
  end

  defp invoke_transform({m, f, a} = mfa, ctx) when is_mfa(mfa), do: apply(m, f, [ctx.output | a])
  defp invoke_transform(fun, ctx) when is_function(fun, 1), do: fun.(ctx.output)

  defp invoke_refine({m, f, a} = mfa, ctx) when is_mfa(mfa), do: apply(m, f, [ctx | a])
  defp invoke_refine(fun, ctx) when is_function(fun, 1), do: fun.(ctx.output)
  defp invoke_refine(fun, ctx) when is_function(fun, 2), do: fun.(ctx.output, ctx)
end
