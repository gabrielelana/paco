defmodule Paco.Failure do
  @type t :: %__MODULE__{at: Paco.State.position,
                         tail: String.t,
                         rank: integer,
                         expected: String.t | nil,
                         message: String.t | nil,
                         stack: [String.t]}

  defexception at: {0, 0, 0}, tail: "", rank: 0, expected: nil, message: nil, stack: []


  def at(%Paco.State{at: at, text: text}, opts \\ []) do
    %Paco.Failure{at: at, tail: text,
                  rank: Keyword.get(opts, :rank, 0),
                  expected: Keyword.get(opts, :expected, nil),
                  message: Keyword.get(opts, :message, nil),
                  stack: Keyword.get(opts, :stack, [])}
  end


  def stack(%Paco.Parser{description: nil}), do: []
  def stack(%Paco.Parser{description: description}), do: [description]

  def stack(failure, %Paco.Parser{description: nil}), do: failure
  def stack(failure, %Paco.Parser{description: description}) do
    %Paco.Failure{failure|stack: [description|failure.stack]}
  end


  def compose(failures), do: compose(failures, nil)

  defp compose([], composed), do: composed
  defp compose([failure|failures], nil), do: compose(failures, failure)
  defp compose([%Paco.Failure{at: at, tail: tail, rank: rank} = failure|failures],
               %Paco.Failure{at: at, tail: tail, rank: rank} = composed) do
    compose(failures, %Paco.Failure{at: at, tail: tail, rank: rank,
                                    expected: compose_expectations(failure, composed),
                                    stack: compose_stack(failure, composed)})
  end

  defp compose_expectations(%Paco.Failure{expected: {:composed, f}},
                            %Paco.Failure{expected: {:composed, c}}),
                            do: {:composed, concat_expectations(c, f)}
  defp compose_expectations(%Paco.Failure{expected: f},
                            %Paco.Failure{expected: {:composed, c}}),
                            do: {:composed, concat_expectations(c, [f])}
  defp compose_expectations(%Paco.Failure{expected: {:composed, f}},
                            %Paco.Failure{expected: c}),
                            do: {:composed, concat_expectations([c], f)}
  defp compose_expectations(%Paco.Failure{expected: f},
                            %Paco.Failure{expected: f}),
                            do: f
  defp compose_expectations(%Paco.Failure{expected: f},
                            %Paco.Failure{expected: c}),
                            do: {:composed, [c, f]}

  defp concat_expectations(c, f), do: Enum.concat(c, f) |> Enum.uniq

  defp compose_stack(%Paco.Failure{stack: t},
                     %Paco.Failure{stack: t}), do: t
  defp compose_stack(%Paco.Failure{stack: [_|t]},
                     %Paco.Failure{stack: [_|t]}), do: t
  defp compose_stack(%Paco.Failure{stack: t},
                     %Paco.Failure{stack: [_|t]}), do: t
  defp compose_stack(%Paco.Failure{stack: [_|t]},
                     %Paco.Failure{stack: t}), do: t


  def message(%Paco.Failure{} = failure), do: format(failure, :flat)


  def format(%Paco.Failure{} = failure, :raw), do: failure
  def format(%Paco.Failure{} = failure, :tagged), do: {:error, format(failure, :flat)}
  def format(%Paco.Failure{message: nil} = failure, :flat) do
    [ "expected",
      format_expected(failure.expected),
      format_stack(failure.stack),
      format_position(failure.at),
      "but got",
      format_tail(failure.tail, failure.expected)
    ]
    |> Enum.reject(&(&1 === :empty))
    |> Enum.join(" ")
  end
  def format(%Paco.Failure{} = failure, :flat) do
    format_message(failure)
  end

  defp format_message(failure) do
    failure.message
    |> String.split("%", trim: true)
    |> Enum.map(&String.strip/1)
    |> Enum.map(fn("EXPECTED") -> format_expected(failure.expected)
                  ("STACK")    -> format_stack(failure.stack)
                  ("AT")       -> format_position(failure.at)
                  ("TAIL")     -> format_tail(failure.tail, failure.expected)
                  (token)      -> token
                end)
    |> Enum.reject(&(&1 == :empty or &1 == ""))
    |> Enum.join(" ")
  end

  defp format_expected({:re, r}) do
    inspect(r)
  end
  defp format_expected({:until, p}) do
    ["something ended by", format_description({:until, p})]
    |> Enum.join(" ")
  end
  defp format_expected({:while, p, n, m}) do
    [format_limits({n, m}), "characters", format_description({:while, p})]
    |> Enum.join(" ")
  end
  defp format_expected({:any, n, m}) do
    [format_limits({n, m}), "characters"]
    |> Enum.join(" ")
  end
  defp format_expected({:composed, expectations}) do
    ["one of [", Enum.map(expectations, &format_expected/1) |> Enum.join(", "), "]"]
    |> Enum.join("")
  end
  defp format_expected(s) when is_binary(s) do
    quoted(s)
  end

  defp format_stack([]), do: :empty
  defp format_stack(descriptions) do
    ["(", descriptions |> Enum.reverse |> Enum.join(" < "), ")"]
    |> Enum.join("")
  end

  defp format_position({_, line, column}), do: "at #{line}:#{column}"

  defp format_tail("", _), do: "the end of input"
  defp format_tail(tail, s) when is_binary(s) do
    quoted(String.slice(tail, 0, String.length(s)))
  end
  defp format_tail(tail, {:while, _, n, _}) do
    quoted(String.slice(tail, 0, n))
  end
  defp format_tail(tail, _) do
    tail = Paco.String.line_at(tail, 0)
    case String.length(tail) do
      n when n > 21 -> quoted(String.slice(tail, 0, 42) <> "...")
      _             -> quoted(tail)
    end
  end

  defp format_limits({n, n}), do: "exactly #{n}"
  defp format_limits({n, _}), do: "at least #{n}"

  defp format_description({:until, p}) when is_function(p) do
    "a character which satisfy #{format_function(p)}"
  end
  defp format_description({:until, {p, _}}) do
    quoted(p)
  end
  defp format_description({:until, p}) do
    quoted(p)
  end
  defp format_description({:while, p}) when is_binary(p) do
    "in alphabet #{quoted(p)}"
  end
  defp format_description({:while, p}) when is_function(p) do
    "which satisfy #{format_function(p)}"
  end

  defp format_function(f) do
    about_f = :erlang.fun_info(f)
    if Keyword.get(about_f, :type) == :external do
      Keyword.get(about_f, :name)
    else
      "fn/#{Keyword.get(about_f, :arity)}"
    end
  end

  defp quoted(text), do: ~s|"#{text}"|
end
