defmodule Paco.Failure do
  @type t :: %__MODULE__{at: Paco.State.position,
                         tail: String.t,
                         expected: any,
                         message: String.t,
                         what: any, because: any,
                         stack: [String.t]}

  defexception at: {0, 0, 0}, tail: "", message: "", expected: nil, stack: [], what: nil, because: nil

  def at(%Paco.State{at: at, text: text}, expected, opts \\ []) do
    %Paco.Failure{at: at, tail: text, expected: expected,
                  message: Keyword.get(:message, opts, ""),
                  stack: Keyword.get(:stack, opts, [])}
  end

  def message(%Paco.Failure{} = failure), do: format(failure, :flat)

  def format(%Paco.Failure{} = failure, :raw), do: failure
  def format(%Paco.Failure{} = failure, :tagged), do: {:error, format(failure, :flat)}
  def format(%Paco.Failure{at: {_, line, column}, tail: "", expected: expected}, :flat) do
    ~s|expected "#{expected}" at #{line}:#{column} but got the end of input|
  end
  def format(%Paco.Failure{at: {_, line, column}, tail: tail, expected: expected}, :flat) do
    ~s|expected "#{expected}" at #{line}:#{column} but got "#{tail}"|
  end

  # def format(%Paco.Failure{at: {_, line, column}, what: what, because: nil}, :flat) do
  #   """
  #   Failed to match #{what} at #{line}:#{column}
  #   """
  # end
  # def format(%Paco.Failure{at: {_, line, column}, what: what, because: reason}, :flat) do
  #   reason = case reason do
  #     %Paco.Failure{} -> String.strip(Paco.Failure.format(reason, :flat))
  #     reason when is_binary(reason) -> reason
  #   end
  #   reason = Regex.replace(~r/^\p{Lu}/, reason, &String.downcase/1)
  #   """
  #   Failed to match #{what} at #{line}:#{column}, because it #{reason}
  #   """
  # end
  # def format(%Paco.Failure{} = failure, :tagged), do: {:error, Paco.Failure.format(failure, :flat)}
end
