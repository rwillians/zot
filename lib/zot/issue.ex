defmodule Zot.Issue do
  @moduledoc ~S"""
  """

  alias __MODULE__

  @typedoc ~S"""
  """
  @type segment :: atom | String.t() | integer

  @typedoc ~S"""
  """
  @type t :: %Issue{
          path: [segment],
          template: String.t(),
          variables: keyword
        }

  defexception path: [],
               template: nil,
               variables: []

  @impl Exception
  def message(%Issue{} = issue) do
    Enum.reduce(issue.variables, issue.template, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", format(value))
    end)
  end

  @doc ~S"""
  Creates a new issue.
  """
  @spec issue(message) :: t
        when message: String.t()

  def issue(message)
      when is_binary(message),
      do: %Issue{template: message}

  @doc ~S"""
  Creates a new issue.
  """
  @spec issue(template, variables) :: t
        when template: String.t(),
             variables: keyword
  @spec issue(path, message) :: t
        when path: [segment],
             message: String.t()

  def issue(template, variables)
      when is_binary(template) and is_list(variables),
      do: %Issue{template: template, variables: variables}

  def issue(path, message)
      when is_list(path) and is_binary(message),
      do: %Issue{path: path, template: message}

  @doc ~S"""
  Creates a new issue.
  """
  @spec issue(path, template, variables) :: t
        when path: [segment],
             template: String.t(),
             variables: keyword

  def issue(path, template, variables)
      when is_list(path) and is_binary(template) and is_list(variables),
      do: %Issue{path: path, template: template, variables: variables}

  @doc ~S"""
  Prepends segments to the issue's path.
  """
  @spec prepend_path(issue, segments) :: issue
        when issue: t,
             segments: [term]

  def prepend_path(%Issue{} = issue, []), do: issue
  def prepend_path(%Issue{} = issue, [_ | _] = segments), do: %{issue | path: segments ++ issue.path}

  #
  #   PRIVATE
  #

  defp human_readable_list([_, _ | _] = list, which, opts)
      when which in [:conjunction, :disjunction] do
    separator =
      case which do
        :conjunction -> "and"
        :disjunction -> "or"
      end

    [last, second_last | rest] =
      list
      |> Enum.map(&to_string/1)
      |> Enum.map(&maybe_quote(&1, opts[:quote]))
      |> :lists.reverse()

    rest
    |> :lists.reverse()
    |> Enum.concat(["#{second_last} #{separator} #{last}"])
    |> Enum.join(", ")
  end

  defp format(%Date{} = value), do: Date.to_iso8601(value)
  defp format(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp format(%Decimal{} = value), do: Decimal.to_string(value)
  defp format(%Regex{} = value), do: "/#{value.source}/"
  defp format(value) when is_binary(value), do: "'#{value}'"
  defp format({:unquoted, value}) when is_binary(value), do: value
  defp format(value) when is_boolean(value), do: to_string(value)
  defp format({which, value, opts}) when which in [:conjunction, :disjunction], do: human_readable_list(value, which, opts)
  defp format(value), do: inspect(value)

  defp maybe_quote(value, nil), do: value
  defp maybe_quote(value, true), do: "'#{value}'"
  defp maybe_quote(value, char) when is_binary(char), do: "#{char}#{value}#{char}"
end
