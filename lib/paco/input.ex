defmodule Paco.Input do
  @type zero_or_more :: non_neg_integer
  @type position :: {zero_or_more, zero_or_more, zero_or_more}
  @type t :: %__MODULE__{at: position,
                         text: String.t,
                         target: pid | nil,
                         stream: boolean}

  defstruct at: {0, 0, 0}, text: "", target: nil, stream: false

  def from(s, opts \\ []) when is_binary(s) do
    %__MODULE__{at: {0, 1, 1}, text: s, target: Keyword.get(opts, :target, nil)}
  end
end
