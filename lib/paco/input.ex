defmodule Paco.Input do
  @type zero_or_more :: non_neg_integer
  @type position :: {zero_or_more, zero_or_more, zero_or_more}
  @type t :: %__MODULE__{at: position,
                         text: String.t,
                         stream: boolean}

  defstruct at: {0, 0, 0}, text: "", stream: false

  def from(s) when is_binary(s), do: %__MODULE__{at: {0, 1, 1}, text: s}
end
