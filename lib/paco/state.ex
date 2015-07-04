defmodule Paco.State do
  alias Paco.State
  alias Paco.Success

  @type position :: {non_neg_integer, non_neg_integer, non_neg_integer}
  @type t :: %State{at: position,
                    text: String.t,
                    accumulator: term | nil,
                    stream: pid | nil}

  defstruct at: {0, 0, 0}, text: "", accumulator: nil, stream: nil

  def from(text, opts \\ []) when is_binary(text) do
    %State{at: Keyword.get(opts, :at, {0, 1, 1}),
           text: text,
           accumulator: Keyword.get(opts, :accumulator, nil),
           stream: Keyword.get(opts, :stream, nil)}
  end

  def update(state, %Success{at: at, tail: tail}),
    do: %State{state|at: at, text: tail}
end
