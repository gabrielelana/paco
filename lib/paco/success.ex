defmodule Paco.Success do
  @type t :: %__MODULE__{from: Paco.Input.position,
                         to: Paco.Input.position,
                         at: Paco.Input.position,
                         tail: String.t,
                         result: any,
                         skip: boolean}

  defstruct from: {0, 0, 0}, to: {0, 0, 0}, at: {0, 0, 0}, tail: "", result: "", skip: false


  def format(%Paco.Success{skip: true}, :flat), do: []
  def format(%Paco.Success{skip: true}, :raw), do: []
  def format(%Paco.Success{} = success, :raw), do: success
  def format(%Paco.Success{result: result}, :flat), do: result
  def format(%Paco.Success{} = success, :tagged), do: {:ok, Paco.Success.format(success, :flat)}
end
