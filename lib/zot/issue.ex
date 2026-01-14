defmodule Zot.Issue do
  @moduledoc ~S"""
  Represents a single issue found when parsing / validating a value
  against a type.
  """

  alias __MODULE__, as: Issue

  @typedoc ~S"""
  Represents a segment in a path.
  """
  @type segment :: String.t() | atom | non_neg_integer

  @typedoc ~S"""
  Zot's issue struct.
  """
  @type t :: %Issue{
          path: [segment],
          template: String.t(),
          params: keyword()
        }

  defexception path: [],
               template: nil,
               params: []

  @impl Exception
  def message(%Issue{} = issue) do
    Enum.reduce(issue.params, issue.template, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", render(value))
    end)
  end

  @doc ~S"""
  Creates a new issue.
  """
  @spec issue(template :: String.t()) :: t
  @spec issue(template, params) :: t when template: String.t(), params: keyword
  @spec issue(path, template) :: t when path: [segment], template: String.t()
  @spec issue(path :: [segment], template :: String.t(), params :: keyword) :: t

  def issue(template)
      when is_binary(template),
      do: %Issue{template: template}

  def issue(template, params)
      when is_binary(template) and is_list(params),
      do: %Issue{template: template, params: params}

  def issue(path, template)
      when is_list(path) and is_binary(template),
      do: %Issue{path: path, template: template}

  def issue(path, template, params)
      when is_list(path) and is_binary(template) and is_list(params),
      do: %Issue{path: path, template: template, params: params}

  @doc ~S"""
  Prepends segements to the given issue's path.
  """
  @spec prepend_path(t, [segment]) :: t
  @spec prepend_path([t, ...], [segment]) :: [t, ...]

  def prepend_path(%Issue{} = issue, []), do: issue
  def prepend_path(%Issue{path: path} = issue, [_ | _] = segments), do: %{issue | path: segments ++ path}
  def prepend_path([_ | _] = issues, segments), do: Enum.map(issues, &prepend_path(&1, segments))

  @doc ~S"""
  Renders a list of issues into a pretty-printed string.
  """
  @spec prettyprint([t, ...]) :: String.t()

  def prettyprint([_ | _] = issues) do
    summary =
      issues
      |> summarize()
      |> Enum.map(fn {path, messages} -> {dotnotated(path), Enum.join(messages, ", ")} end)
      |> Enum.map(fn {path, message} -> "  * Field `#{highlighted(path)}` #{message};" end)
      |> Enum.join("\n")

    """
    One or more fields failed validation:
    #{summary}
    """
  end

  @doc ~S"""
  Summarizes a list of issues into a map of paths to messages.
  """
  @spec summarize([t, ...]) :: %{optional([segment]) => [String.t(), ...]}

  def summarize([_ | _] = issues), do: Enum.group_by(issues, & &1.path, &message/1)

  #
  #   PRIVATE
  #

  defp dotnotated(segments), do: segments |> Enum.map(&to_string/1) |> Enum.join(".")

  defp highlighted(str), do: IO.ANSI.red() <> IO.ANSI.underline() <> str <> IO.ANSI.reset()

  defp render(value)
  defp render(nil), do: "null"
  defp render(true), do: "true"
  defp render(false), do: "false"
  defp render(value) when is_binary(value), do: "'#{value}'"
  defp render(value) when is_atom(value), do: inspect(value)
  defp render({:escaped, value}) when is_binary(value), do: value
  defp render({:conjunction, values}), do: render_list(conjunction: values)
  defp render({:disjunction, values}), do: render_list(disjunction: values)
  defp render(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp render(%Regex{} = value), do: "/#{value.source}/"
  defp render(value), do: to_string(value)

  defp render_list([{type, [head]}])
      when type in [:conjunction, :disjunction],
      do: render(head)

  defp render_list([{type, [_, _ | _] = list}])
      when type in [:conjunction, :disjunction] do
    [last, second_last | rest] =
      list
      |> Enum.map(&render/1)
      |> :lists.reverse()

    connector =
      case type do
        :conjunction -> "and"
        :disjunction -> "or"
      end

    case rest do
      [] -> "#{second_last} #{connector} #{last}"
      _ -> (rest |> :lists.reverse() |> Enum.join(", ")) <> ", #{second_last} #{connector} #{last}"
    end
  end
end
