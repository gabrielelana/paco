defmodule Paco.Success do
  @type t :: %__MODULE__{from: Paco.Input.position,
                         to: Paco.Input.position,
                         at: Paco.Input.position,
                         tail: String.t,
                         result: any,
                         skip: boolean}

  defstruct from: {0, 0, 0}, to: {0, 0, 0}, at: {0, 0, 0}, tail: "", result: "", skip: false
end
