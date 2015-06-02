defmodule Paco.Success do
  @type t :: %__MODULE__{from: Paco.State.position,
                         to: Paco.State.position,
                         at: Paco.State.position,
                         tail: String.t,
                         result: any,
                         skip: boolean,
                         keep: boolean}

  defstruct from: {0, 0, 0}, to: {0, 0, 0}, at: {0, 0, 0},
            tail: "", result: "", skip: false, keep: false

  def format(%Paco.Success{skip: true}, :flat), do: []
  def format(%Paco.Success{skip: true}, :raw), do: []
  def format(%Paco.Success{} = success, :raw), do: success
  def format(%Paco.Success{result: result}, :flat), do: result
  def format(%Paco.Success{} = success, :tagged), do: {:ok, Paco.Success.format(success, :flat)}
end
