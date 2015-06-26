defmodule Paco.State do
  alias Paco.State
  alias Paco.Success

  @type position :: {non_neg_integer, non_neg_integer, non_neg_integer}
  @type chunk :: {position, chunk::String.t} |
                 {position, chunk::String.t, :drop}
  @type t :: %State{at: position,
                    chunks: [chunk],
                    accumulator: term | nil,
                    stream: pid | nil}

  defstruct at: {0, 0, 0}, chunks: [], accumulator: nil, stream: nil

  def from(text, opts \\ [])

  def from(text, opts) when is_binary(text) do
    %State{at: Keyword.get(opts, :at, {0, 1, 1}),
           chunks: [{Keyword.get(opts, :at, {0, 1, 1}), text}],
           accumulator: Keyword.get(opts, :accumulator, nil),
           stream: Keyword.get(opts, :stream, nil)}
  end
  def from(chunks, opts) do
    [{at, _}|_] = chunks = chunks_from(chunks, Keyword.get(opts, :at, {0, 1, 1}))
    %State{at: at, chunks: chunks,
           accumulator: Keyword.get(opts, :accumulator, nil),
           stream: Keyword.get(opts, :stream, nil)}
  end


  def chunks_from(%State{at: at, chunks: chunks}), do: chunks_from(chunks, at)

  defp chunks_from([], at), do: [{at, ""}]
  defp chunks_from([{_, _, :drop}|chunks], at), do: chunks_from(chunks, at)
  defp chunks_from(chunks, _), do: chunks


  def chunks_from_result_of(%Success{from: from, result: text}) when is_binary(text),
    do: [{from, text}]
  def chunks_from_result_of(%Success{from: from, result: []}),
    do: [{from, ""}]
  def chunks_from_result_of(%Success{result: [{_, _}|_] = chunks}),
    do: chunks

  def update_with_chunks(state, [] = chunks),
    do: %State{state|chunks: chunks}
  def update_with_chunks(state, [{at, _}|_] = chunks),
    do: %State{state|at: at, chunks: chunks}
  def update_with_chunks(state, [{_, _, :drop}|chunks]),
    do: update_with_chunks(state, chunks)

  def update(state, %Success{at: at, tail: [{_, _, :drop}|tail]}),
    do: %State{state|at: at, chunks: tail}
  def update(state, %Success{at: at, tail: tail}),
    do: %State{state|at: at, chunks: tail}
end
