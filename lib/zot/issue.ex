defmodule Zot.Issue do
  @moduledoc ~S"""
  An issue that describes a validation failure.
  """
  @moduledoc since: "0.1.0"

  import Zot.Helpers, only: [f: 1, is_non_empty_string: 1]

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
          path: [],
          template: String.t(),
          context: keyword,
          __meta__: map
        }

  @typedoc ~S"""
  A segment in the path to the value where the issue was found.
  """
  @type segment :: atom | String.t() | integer

  defexception path: [],
               template: nil,
               context: [],
               __meta__: %{}

  @impl Exception
  def message(%Zot.Issue{} = issue) do
    Enum.reduce(issue.context, issue.template, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", f(value))
    end)
  end

  @doc ~S"""
  Builds a new `Zot.Issue`.
  """
  @spec issue(message :: String.t()) :: t

  def issue(message)
      when is_non_empty_string(message),
      do: %Zot.Issue{template: message}

  @doc ~S"""
  Builds a new `Zot.Issue`.
  """
  @spec issue(template :: String.t(), context :: keyword) :: t
  @spec issue(path :: [segment, ...], template :: String.t()) :: t

  def issue(template, [{_, _} | _] = context)
      when is_non_empty_string(template),
      do: %Zot.Issue{template: template, context: context}

  def issue([_ | _] = path, template)
      when is_non_empty_string(template),
      do: %Zot.Issue{path: path, template: template}

  @doc ~S"""
  Builds a new `Zot.Issue`.
  """
  @spec issue(path :: [segment, ...], template :: String.t(), context :: keyword) :: t

  def issue([_ | _] = path, template, [{_, _} | _] = context)
      when is_non_empty_string(template),
      do: %Zot.Issue{path: path, template: template, context: context}

  @doc ~S"""
  Prepends the given segments to the issue's path.

      iex> assert %Zot.Issue{path: [:data, "users", 0, :name]} =
      iex>   issue([:name], "is required")
      iex>   |> prepend_path([:data, "users", 0])

  """
  @spec prepend_path(issue, segments) :: issue
        when issue: t,
             segments: [atom | String.t() | integer]

  def prepend_path(%Zot.Issue{} = issue, [_ | _] = segments), do: %{issue | path: segments ++ issue.path}

  @doc ~S"""
  Given some issues, returns a flat map of errors by field, where the
  field's path is represented in dot notation.

      iex> Zot.Issue.treefy([])
      %{}

      iex> Zot.Issue.treefy([
      iex>   issue([:users, 0, :name], "should have at most %{a} characters, got %{b} characters", a: 100, b: 101),
      iex>   issue([:users, 0, :email], "is invalid"),
      iex> ])
      %{
        "users.0.name" => ["should have at most 100 characters, got 101 characters"],
        "users.0.email" => ["is invalid"]
      }

  """
  def treefy([]), do: %{}

  def treefy([_ | _] = issues) do
    issues
    |> Enum.map(&{dn(&1.path), message(&1)})
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.into(%{})
  end

  #
  #   PRIVATE
  #

  #    ↓ [d]ot-[n]otation
  defp dn([]), do: ""
  defp dn([_ | _] = path), do: Enum.map_join(path, ".", &to_string/1)
end
