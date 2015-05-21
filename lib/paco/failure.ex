defmodule Paco.Failure do
  @type t :: %__MODULE__{at: Paco.State.position,
                         tail: String.t,
                         what: String.t,
                         because: t | nil}

  defexception at: {0, 0, 0}, tail: "", what: "", because: nil

  def message(%Paco.Failure{} = failure), do: format(failure, :flat)

  def format(%Paco.Failure{} = failure, :raw), do: failure
  def format(%Paco.Failure{at: {_, line, column}, what: what, because: nil}, :flat) do
    """
    Failed to match #{what} at #{line}:#{column}
    """
  end
  def format(%Paco.Failure{at: {_, line, column}, what: what, because: reason}, :flat) do
    reason = case reason do
      %Paco.Failure{} -> String.strip(Paco.Failure.format(reason, :flat))
      reason when is_binary(reason) -> reason
    end
    reason = Regex.replace(~r/^\p{Lu}/, reason, &String.downcase/1)
    """
    Failed to match #{what} at #{line}:#{column}, because it #{reason}
    """
  end
  def format(%Paco.Failure{} = failure, :tagged), do: {:error, Paco.Failure.format(failure, :flat)}
end
