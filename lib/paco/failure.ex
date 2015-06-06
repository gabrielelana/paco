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

  def stack(%Paco.Parser{description: nil}), do: []
  def stack(%Paco.Parser{description: description}), do: [description]

  def message(%Paco.Failure{} = failure), do: format(failure, :flat)

  def format(%Paco.Failure{} = failure, :raw), do: failure
  def format(%Paco.Failure{} = failure, :tagged), do: {:error, format(failure, :flat)}
  def format(%Paco.Failure{} = failure, :flat) do
    [ format_expected(failure),
      format_unexpected(failure)
    ]
    |> Enum.reject(&(&1 === :empty))
    |> Enum.join(", ")
  end

  defp format_expected(%Paco.Failure{} = failure) do
    [ "expected",
      format_expected(failure.expected),
      format_stack(failure.stack),
      format_position(failure.from),
      "but got",
      format_tail(failure.text)
    ]
    |> Enum.reject(&(&1 === :empty))
    |> Enum.join(" ")
  end
  defp format_expected(s) when is_binary(s), do: inspect(s)
  defp format_expected({p, at_least, at_most}) do
    "#{format_limits({at_least, at_most})} characters #{format_description(p)}"
  end

  defp format_unexpected(%Paco.Failure{text: ""}), do: :empty
  defp format_unexpected(%Paco.Failure{unexpected: nil}), do: :empty
  defp format_unexpected(%Paco.Failure{} = failure) do
    [ "unexpected",
      format_unexpected(failure.unexpected),
      format_position(failure.at),
    ]
    |> Enum.reject(&(&1 === :empty))
    |> Enum.join(" ")
  end
  defp format_unexpected(unexpected) when is_binary(unexpected) do
    {unexpected, _} = String.next_grapheme(unexpected)
    inspect(unexpected)
  end

  defp format_stack([]), do: :empty
  defp format_stack(descriptions), do: "(#{Enum.join(descriptions, ">")})"

  defp format_position({_, line, column}), do: "at #{line}:#{column}"

  defp format_tail(""), do: "the end of input"
  defp format_tail(text), do: inspect(text)

  defp format_limits({n, n}), do: "exactly #{n}"
  defp format_limits({n, _}), do: "at least #{n}"

  defp format_description(p) when is_binary(p) do
    "in alphabet #{inspect(p)}"
  end
  defp format_description(p) when is_function(p) do
    about_p = :erlang.fun_info(p)
    if Keyword.get(about_p, :type) == :external do
      "which satisfy #{Keyword.get(about_p, :name)}"
    else
      "which satisfy fn/#{Keyword.get(about_p, :arity)}"
    end
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
