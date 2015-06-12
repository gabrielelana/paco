defmodule Paco.Transform do
  def flatten_first(l), do: flatten_first(l, 1, [])
  def flatten_first([], _, acc), do: Enum.reverse(acc)
  def flatten_first([h|t], 1, acc) when is_list(h) do
    flatten_first(t, 1, Enum.reverse(flatten_first(h, 0, acc)))
  end
  def flatten_first([h|t], 1, acc) do
    flatten_first(t, 1, [h|acc])
  end
  def flatten_first([h|t], 0, acc) do
    flatten_first(t, 0, [h|acc])
  end


  def separated_by([h], _), do: h
  def separated_by([left, separator, right|t], f) do
    separated_by([f.(separator, left, right)|t], f)
  end
end
