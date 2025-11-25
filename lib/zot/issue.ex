defmodule Zot.Issue do
  @moduledoc ~S"""
  Represents an issue encountered while parsing a value with a zot
  type.
  """
  @moduledoc since: "0.1.0"

  import Zot.Helpers, only: [nes: 1]

  @typedoc ~S"""
  The issue struct contains the information needed to compute the
  final message, and some other metadata used internally by zot.

  - `path`:     the path to the value where the issue was found.
  - `template`: the template message for the issue, before
    interpolation.
  - `context`:  the contextual information that's used to form the
    final, interpolated error message.
  - `__meta__`: a map of metadata used internally by zot.
  """
  @type t :: %Zot.Issue{
          path: [atom | String.t()],
          template: String.t(),
          context: keyword,
          __meta__: map
        }

  defexception path: [],
               template: nil,
               context: [],
               __meta__: %{}

  @impl Exception
  def message(%Zot.Issue{} = issue) do
    Enum.reduce(issue.context, issue.template, fn {key, value}, acc ->
      with [match | rest] <- Regex.run(~r/%\{#{key}(\s+\|\s+([^\}]+))?}/, acc) do
        flags = Enum.at(rest, 1, "")
        flags = String.split(flags, "+", trim: true)
        value = apply_flags(to_string(value), flags)

        String.replace(acc, match, value)
      else
        _ -> acc
      end
    end)
  end

  @doc ~S"""
  builds a new `Zot.Issue` from the given message.
  """
  @spec issue(message :: String.t) :: t

  def issue(nes(_) = message), do: %Zot.Issue{template: message}

  @doc ~S"""
  builds a new `Zot.Issue` from the given template message and
  contextual information for interpolation.
  """
  @spec issue(template :: String.t, context :: keyword) :: t

  def issue(nes(_) = template, [{_, _} | _] = context), do: %Zot.Issue{template: template, context: context}

  @doc ~S"""
  Appends the given segments to the issue's path.

      Zot.Issue.append_path(issue, [:data, "users", 0])

  """
  @spec append_path(issue, segments) :: issue
        when issue: t,
             segments: [atom | String.t() | integer]

  def append_path(%Zot.Issue{} = issue, [_ | _] = segments), do: %{issue | path: issue.path ++ segments}

  @doc ~S"""
  Prepends the given segments to the issue's path.

      Zot.Issue.prepend_path(issue, [:data, "users", 0])

  """
  @spec prepend_path(issue, segments) :: issue
        when issue: t,
             segments: [atom | String.t() | integer]

  def prepend_path(%Zot.Issue{} = issue, [_ | _] = segments), do: %{issue | path: segments ++ issue.path}

  #
  #   PRIVATE
  #

  defp apply_flags(value, []), do: value
  defp apply_flags(value, ["quoted" | flags]), do: apply_flags(~s("#{value}"), flags)
end
