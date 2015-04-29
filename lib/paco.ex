defmodule Paco do

  def parse(%Paco.Parser{} = parser, text) do
    case parser.parse.(Paco.Input.from(text)) do
      %Paco.Failure{} = failure ->
        {:error, failure}
      %Paco.Success{skip: true} ->
        {:ok, []}
      %Paco.Success{result: result} ->
        {:ok, result}
    end
  end

  def parse!(%Paco.Parser{} = parser, text) do
    case parser.parse.(parser, text) do
      {:ok, result} ->
        result
      {:error, failure} ->
        raise Error, message: Paco.Failure.format(failure)
    end
  end

end
