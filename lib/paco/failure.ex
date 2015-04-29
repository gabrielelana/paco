defmodule Paco.Failure do
  @type t :: %__MODULE__{at: Paco.Input.position,
                         what: String.t,
                         because: t | nil}

  defstruct at: {0, 0, 0}, what: "", because: nil

  def format(%Paco.Failure{at: {_, line, column}, what: what, because: nil}) do
    """
    Failed to match #{what} at line: #{line}, column: #{column}
    """
  end
  def format(%Paco.Failure{at: {_, line, column}, what: what, because: failure}) do
    """
    Failed to match #{what} at line: #{line}, column: #{column} <because> #{String.strip(format(failure))}
    """
  end
end
