defmodule Paco.Chunk do
  def chunks?([]), do: true
  def chunks?([{_, text}|tail]) when is_binary(text), do: chunks?(tail)
  def chunks?([{_, text, :drop}|tail]) when is_binary(text), do: chunks?(tail)
  def chunks?(_), do: false
end
