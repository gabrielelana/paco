defmodule Paco.Success do
  alias Paco.Success

  @type t :: %Success{from: Paco.State.position,
                      to: Paco.State.position,
                      at: Paco.State.position,
                      tail: [Paco.State.chunk],
                      result: any,
                      cut: boolean,
                      sew: boolean,
                      skip: boolean,
                      keep: boolean}

  defstruct from: {0, 0, 0}, to: {0, 0, 0}, at: {0, 0, 0}, tail: [], result: "",
            cut: false, sew: false, skip: false, keep: false

  def format(%Success{} = success, :raw), do: success
  def format(%Success{skip: true}, :flat), do: ""
  def format(%Success{result: result}, :flat), do: result
  def format(%Success{} = success, :tagged), do: {:ok, Success.format(success, :flat)}
end
