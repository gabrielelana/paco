defmodule Paco.Parser do
  import Paco.Helper

  defstruct name: nil, combine: [], parse: nil

  defp notify(nil, _what), do: :ok
  defp notify(target, what), do: GenEvent.notify(target, what)

  parser_ skip(%Paco.Parser{} = parser) do
    fn %Paco.Input{} = input, _this ->
      case parser.parse.(input, parser) do
        %Paco.Success{} = success ->
          %Paco.Success{success | skip: true}
        %Paco.Failure{} = failure ->
          failure
      end
    end
  end

  parser_ seq([]), do: (raise ArgumentError, message: "Must give at least one parser to seq combinator")
  parser_ seq(parsers) do
    fn %Paco.Input{at: from, target: target} = input, this ->
      notify(target, {:started, Paco.describe(this)})
      result = Enum.reduce(parsers, {input, from, []},
                           fn
                             (%Paco.Parser{} = parser, {input, _, results}) ->
                               case parser.parse.(input, parser) do
                                 %Paco.Success{to: to, at: at, tail: tail, skip: true} ->
                                   {%Paco.Input{input | at: at, text: tail}, to, results}
                                 %Paco.Success{to: to, at: at, tail: tail, result: result} ->
                                   {%Paco.Input{input | at: at, text: tail}, to, [result|results]}
                                 %Paco.Failure{} = failure ->
                                   failure
                               end
                             (_, %Paco.Failure{} = failure) ->
                               failure
                           end)

      case result do
        {%Paco.Input{at: at, text: text}, to, results} ->
          notify(target, {:matched, from, to})
          %Paco.Success{from: from, to: to, at: at, tail: text, result: Enum.reverse(results)}
        %Paco.Failure{} = failure ->
          notify(target, {:failed, from})
          %Paco.Failure{at: from, what: Paco.describe(this), because: failure}
      end
    end
  end

  parser_ one_of([]), do: (raise ArgumentError, message: "Must give at least one parser to one_of combinator")
  parser_ one_of([parser]), do: parser
  parser_ one_of(parsers) do
    fn %Paco.Input{at: from, target: target} = input, this ->
      notify(target, {:started, Paco.describe(this)})
      result = Enum.reduce(parsers, [],
                           fn
                             (_, %Paco.Success{} = success) ->
                               success
                             (%Paco.Parser{} = parser, failures) ->
                               case parser.parse.(input, parser) do
                                 %Paco.Success{} = success ->
                                   success
                                 %Paco.Failure{} = failure ->
                                   [failure | failures]
                               end
                           end)

      case result do
        %Paco.Success{from: from, to: to} = success ->
          notify(target, {:matched, from, to})
          success
        _ ->
          notify(target, {:failed, from})
          %Paco.Failure{at: from, what: Paco.describe(this)}
      end
    end
  end


  parser_ string(s) do
    fn %Paco.Input{at: from, text: text, target: target, stream: stream} = input, this ->
      case consume(s, text, from, from) do
        {to, at, tail} ->
          notify(target, {:started, Paco.describe(this)})
          notify(target, {:matched, from, to})
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: s}
        :end_of_input when is_pid(stream) ->
          send(stream, {self, :more})
          receive do
            {:load, string} ->
              notify(target, {:loaded, string})
              this.parse.(%Paco.Input{input|text: text <> string}, this)
          end
        _ ->
          notify(target, {:started, Paco.describe(this)})
          notify(target, {:failed, from})
          %Paco.Failure{at: from, what: Paco.describe(this)}
      end
    end
  end


  def label(parser, name) do
    %Paco.Parser{
      name: name,
      combine: [],
      parse: fn %Paco.Input{} = input, _this ->
               case parser.parse.(input, parser) do
                 %Paco.Success{} = success ->
                   success
                 %Paco.Failure{} = failure ->
                   %Paco.Failure{failure | what: name}
               end
             end}
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
                 _to,
                 {n, l, _} = at) do
      consume(t1, t2, at, {n + 1, l + 1, 1})
    end
  end
  defp consume(<<h::utf8, t1::binary>>,
               <<h::utf8, t2::binary>>,
               _to,
               {n, l, c} = at) do
    consume(t1, t2, at, {n + 1, l, c + 1})
  end
  defp consume("", tail, to, at), do: {to, at, tail}
  defp consume(_, "", _, _), do: :end_of_input
  defp consume(_, _, _, _), do: :failure
end
