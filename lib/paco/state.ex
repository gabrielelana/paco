defmodule Paco.State do
  @type position :: {non_neg_integer, non_neg_integer, non_neg_integer}
  @type t :: %__MODULE__{at: position,
                         text: String.t,
                         accumulator: term | nil,
                         cut: boolean,
                         stream: pid | nil}

  defstruct at: {0, 1, 1}, text: "", accumulator: nil, cut: false, stream: nil

  def from(text, opts \\ []) when is_binary(text) do
    %__MODULE__{at: Keyword.get(opts, :at, {0, 1, 1}),
                text: text,
                stream: Keyword.get(opts, :stream, nil)}
  end

  def update(state, %Paco.Success{at: at, tail: tail, cut: cut}) do
    %Paco.State{state|at: at, text: tail, cut: cut}
  end
end
