defmodule Paco.Chunk do
  def chunks?([]), do: true
  def chunks?([{_, text}|tail]) when is_binary(text), do: chunks?(tail)
  def chunks?([{_, text, :drop}|tail]) when is_binary(text), do: chunks?(tail)
  def chunks?(_), do: false

  def drop([]), do: []
  def drop([{_, _, :drop} = chunk|tail]), do: [chunk|drop(tail)]
  def drop([{at, text}|tail]), do: [{at, text, :drop}|drop(tail)]
end
