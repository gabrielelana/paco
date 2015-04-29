defmodule Paco do

  defmodule Input do
    @type zero_or_more :: non_neg_integer
    @type position :: {zero_or_more, zero_or_more, zero_or_more}
    @type t :: %__MODULE__{at: position,
                           text: String.t,
                           stream: boolean}

    defstruct at: {0, 0, 0}, text: "", stream: false

    def from(s) when is_binary(s), do: %__MODULE__{at: {0, 1, 1}, text: s}
  end

  defmodule Success do
    @type t :: %__MODULE__{from: Paco.Input.position,
                           to: Paco.Input.position,
                           tail: String.t,
                           result: any,
                           skip: boolean}

    defstruct from: {0, 0, 0}, to: {0, 0, 0}, tail: "", result: "", skip: false
  end

  defmodule Failure do
    @type t :: %__MODULE__{at: Paco.Input.position,
                           what: String.t,
                           because: t | nil}

    defstruct at: {0, 0, 0}, what: "", because: nil

    def format(%Failure{at: {_, line, column}, what: what, because: nil}) do
      """
      Failed to match #{what} at line: #{line}, column: #{column}
      """
    end
    def format(%Failure{at: {_, line, column}, what: what, because: failure}) do
      """
      Failed to match #{what} at line: #{line}, column: #{column} <because> #{String.strip(format(failure))}
      """
    end
  end


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
