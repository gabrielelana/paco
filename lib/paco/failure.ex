defmodule Paco.Failure do
  @type t :: %__MODULE__{from: Paco.State.position,
                         text: String.t,
                         expected: String.t,
                         at: Paco.State.position | nil,
                         unexpected: String.t | nil,
                         message: String.t | nil,
                         stack: [String.t],

                         tail: String.t, what: any, because: any}

  defexception from: {0, 0, 0}, text: "", expected: "",
               at: nil, unexpected: nil, message: nil,
               stack: [],
               tail: "", what: nil, because: nil

  def at(%Paco.State{at: at, text: text}, expected, opts \\ []) do
    %Paco.Failure{from: at, text: text, expected: expected,
                  at: Keyword.get(:at, opts, nil),
                  unexpected: Keyword.get(:unexpected, opts, nil),
                  message: Keyword.get(:message, opts, nil),
                  stack: Keyword.get(:stack, opts, [])}
  end

  def message(%Paco.Failure{} = failure), do: format(failure, :flat)

  def format(%Paco.Failure{} = failure, :raw), do: failure
  def format(%Paco.Failure{} = failure, :tagged), do: {:error, format(failure, :flat)}
  def format(%Paco.Failure{text: ""} = failure, :flat), do: format_expected(failure)
  def format(%Paco.Failure{unexpected: nil} = failure, :flat), do: format_expected(failure)
  def format(%Paco.Failure{} = failure, :flat) do
    Enum.join([format_expected(failure), format_unexpected(failure)], ", ")
  end

  defp format_expected(%Paco.Failure{from: {_, line, column}, text: "", expected: expected}) do
    ~s|expected #{expected} at #{line}:#{column} but got the end of input|
  end
  defp format_expected(%Paco.Failure{from: {_, line, column}, text: tail, expected: expected}) do
    ~s|expected #{expected} at #{line}:#{column} but got "#{tail}"|
  end

  defp format_unexpected(%Paco.Failure{at: {_, line, column}, unexpected: unexpected}) do
    ~s|unexpected #{unexpected} at #{line}:#{column}|
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
