defmodule Zot.Parameterized do
  @moduledoc ~S"""
  Describes a type setting with parameters, such as a custom error
  message.
  """

  defstruct [:value, :params]

  @typedoc ~S"""
  The value of a parameterized type setting.
  """
  @type t(type) :: %Zot.Parameterized{
          value: type,
          params: params
        }

  @typedoc ~S"""
  Fallback type for a parameterized type setting.
  """
  @type t :: t(term)

  @typedoc ~S"""
  The parameters for a parameterized type setting.
  """
  @type params :: %{
          error: String.t()
        }

  @doc ~S"""
  Creates a parameterized type setting.
  """
  @spec new(value, defaults, opts) :: t
        when value: term,
             defaults: map | keyword,
             opts: map | keyword

  def new(value, defaults \\ [], opts) do
    %Zot.Parameterized{
      value: value,
      params: Map.merge(Enum.into(defaults, %{}), Enum.into(opts, %{}))
    }
  end

  @doc ~S"""
  Creates a parameterized type setting.
  """
  defdelegate p(value, defaults \\ [], opts), to: __MODULE__, as: :new
end
