ExUnit.start()

defmodule Paco.Test.Helper do
  def streams_of(text) when is_binary(text), do: split(text) |> streams_of
  def streams_of([h]), do: [[h]]
  def streams_of([h|t]) do
    append = for p <- streams_of(t), do: [h|p]
    glue = for [ph|pt] <- streams_of(t), do: [h<>ph|pt]
    Enum.concat(append, glue)
  end

  defp split(text) when is_binary(text) do
    Stream.unfold(text, &String.next_grapheme/1)
    |> Enum.intersperse("")
    |> (&["", &1, ""]).()
    |> List.flatten
  end
end
