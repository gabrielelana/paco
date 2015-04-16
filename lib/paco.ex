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



  defmodule Parser do

    def parse(parser, text) do
      case parser.(Input.from(text)) do
        %Failure{} = failure ->
          {:error, failure}
        %Success{skip: true} ->
          {:ok, []}
        %Success{result: result} ->
          {:ok, result}
      end
    end

    def parse!(parser, text) do
      case parse(parser, text) do
        {:ok, result} ->
          result
        {:error, failure} ->
          raise Error, message: Failure.format(failure)
      end
    end



    def seq(parsers) do
      fn %Input{at: from, stream: stream} = input ->
        result = Enum.reduce(parsers, {input, []},
                             fn
                               (parser, {input, results}) ->
                                 case parser.(input) do
                                   %Success{to: to, tail: tail, skip: true} ->
                                     {%Input{at: to, text: tail, stream: stream}, results}
                                   %Success{to: to, tail: tail, result: result} ->
                                     {%Input{at: to, text: tail, stream: stream}, [result|results]}
                                   %Failure{} = failure ->
                                     failure
                                 end
                               (_, %Failure{} = failure) ->
                                 failure
                             end)

        case result do
          {%Input{at: to, text: text}, results} ->
            %Success{from: from, to: to, tail: text, result: Enum.reverse(results)}
          %Failure{} = failure ->
            %Failure{at: from,
                     what: "seq",
                     because: failure}
        end
      end
    end

    def one_of(parsers) do
      fn %Input{at: from} = input ->
        result = Enum.reduce(parsers, [],
                             fn
                               (_, %Success{} = success) ->
                                 success
                               (parser, failures) ->
                                 case parser.(input) do
                                   %Success{} = success ->
                                     success
                                   %Failure{} = failure ->
                                     [failure | failures]
                                 end
                             end)

        case result do
          %Success{} = success ->
            success
          failures ->
            whats = failures |> Enum.reverse |> Enum.map(&(&1.what)) |> Enum.join(" | ")
            %Failure{at: from, what: "one_of(#{whats})"}
        end
      end
    end


    def string(s) do
      fn %Input{at: from, text: text} ->
        case consume(s, text, from) do
          {to, tail} ->
            %Success{from: from, to: to, tail: tail, result: s}
          :fail ->
            %Failure{at: from, what: "string(#{s})"}
        end
      end
    end


    @nl ["\x{000A}",         # LF:    Line Feed, U+000A
         "\x{000B}",         # VT:    Vertical Tab, U+000B
         "\x{000C}",         # FF:    Form Feed, U+000C
         "\x{000D}",         # CR:    Carriage Return, U+000D
         "\x{000D}\x{000A}", # CR+LF: CR (U+000D) followed by LF (U+000A)
         "\x{0085}",         # NEL:   Next Line, U+0085
         "\x{2028}",         # LS:    Line Separator, U+2028
         "\x{2029}"          # PS:    Paragraph Separator, U+2029
        ]

    Enum.each @nl, fn nl ->
      defp consume(<<unquote(nl)::utf8, t1::binary>>,
                   <<unquote(nl)::utf8, t2::binary>>,
                   {n, l, _}) do
        consume(t1, t2, {n + 1, l + 1, 1})
      end
    end
    defp consume(<<h::utf8, t1::binary>>, <<h::utf8, t2::binary>>, {n, l, c}) do
      consume(t1, t2, {n + byte_size(<<h>>), l, c + 1})
    end
    defp consume("", tail, position), do: {position, tail}
    defp consume(_, _, _), do: :fail
  end
end
