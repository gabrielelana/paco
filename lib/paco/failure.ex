defmodule Paco.Failure do
  @type t :: %__MODULE__{at: Paco.State.position,
                         what: String.t,
                         because: t | nil}

  defexception at: {0, 0, 0}, what: "", because: nil

  def message(%Paco.Failure{} = failure), do: format(failure, :flat)

  def format(%Paco.Failure{} = failure, :raw), do: failure
  def format(%Paco.Failure{at: {_, line, column}, what: what, because: nil}, :flat) do
    """
    Failed to match #{what} at #{line}:#{column}
    """
  end
  def format(%Paco.Failure{at: {_, line, column}, what: what, because: failure}, :flat) do
    failure = Regex.replace(~r/^F/, String.strip(format(failure, :flat)), "f")
    """
    Failed to match #{what} at #{line}:#{column}, because it #{failure}
    """
  end
  def format(%Paco.Failure{} = failure, :tagged), do: {:error, Paco.Failure.format(failure, :flat)}
end
