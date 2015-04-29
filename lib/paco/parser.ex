defmodule Paco.Parser do
  import Paco.Helper

  defstruct name: nil, parse: nil

  parser seq(parsers) do
    fn %Paco.Input{at: from, stream: stream} = input ->
      result = Enum.reduce(parsers, {input, []},
                           fn
                             (%Paco.Parser{} = parser, {input, results}) ->
                               case parser.parse.(input) do
                                 %Paco.Success{to: to, tail: tail, skip: true} ->
                                   {%Paco.Input{at: to, text: tail, stream: stream}, results}
                                 %Paco.Success{to: to, tail: tail, result: result} ->
                                   {%Paco.Input{at: to, text: tail, stream: stream}, [result|results]}
                                 %Paco.Failure{} = failure ->
                                   failure
                               end
                             (_, %Paco.Failure{} = failure) ->
                               failure
                           end)

      case result do
        {%Paco.Input{at: to, text: text}, results} ->
          %Paco.Success{from: from, to: to, tail: text, result: Enum.reverse(results)}
        %Paco.Failure{} = failure ->
          %Paco.Failure{at: from,
                   what: "seq",
                   because: failure}
      end
    end
  end

  parser one_of(parsers) do
    fn %Paco.Input{at: from} = input ->
      result = Enum.reduce(parsers, [],
                           fn
                             (_, %Paco.Success{} = success) ->
                               success
                             (%Paco.Parser{} = parser, failures) ->
                               case parser.parse.(input) do
                                 %Paco.Success{} = success ->
                                   success
                                 %Paco.Failure{} = failure ->
                                   [failure | failures]
                               end
                           end)

      case result do
        %Paco.Success{} = success ->
          success
        failures ->
          whats = failures |> Enum.reverse |> Enum.map(&(&1.what)) |> Enum.join(" | ")
          %Paco.Failure{at: from, what: "one_of(#{whats})"}
      end
    end
  end


  parser string(s) do
    fn %Paco.Input{at: from, text: text} ->
      case consume(s, text, from) do
        {to, tail} ->
          %Paco.Success{from: from, to: to, tail: tail, result: s}
        :fail ->
          %Paco.Failure{at: from, what: "string(#{s})"}
      end
    end
  end





  # parser one_of(parsers) do
  #   fn %Input{at: from} = input ->
  #     []
  #   end
  # end

  # def one_of(parsers) do
  #   # if the do argument *is* an anonymous function
  #   %Parser{
  #     name: "one_of",
  #     parse: fn %Input{at: from} = input ->
  #       []
  #     end}
  # end

  # parser date do
  #   seq([
  #     digit(4) |> as(:year), "-",
  #     digit(2) |> as(:month), "-",
  #     digit(2) |> as(:day)
  #   ])
  #   |> flatten
  # end

  # def date do
  #   # if the do argument *is not* an anonymous function
  #   %Parser{
  #     name: "date",
  #     parse: fn %Input{} = input ->
  #              parser = seq([
  #                digit(4) |> as(:year), "-",
  #                digit(2) |> as(:month), "-",
  #                digit(2) |> as(:day)
  #              ])
  #              |> flatten
  #              case parser do
  #                %Parser{} -> parser.parse.(input)
  #                _ -> :error
  #              end
  #            end
  # end







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
