defmodule Paco do
  defmodule Source do
    defstruct at: 0, text: ""

    def from(s) when is_binary(s), do: %__MODULE__{at: 0, text: s}
  end

  defmodule Success, do: defstruct from: 0, to: 0, tail: "", result: [], skip: false

  defmodule Failure do
    defstruct at: 0, message: ""

    def format(failure, text) do
      {line, column} = {line(text, failure.at), column(text, failure.at)}
      """
      #{failure.message} at line: #{line}, column: #{column}, but got
      #{context(text, failure.at, line, column)}
      """
    end

    defp line(text, at), do: line(text, at, 1)
    defp line(_, 0, ln), do: ln
    defp line(<<"\n"::utf8, text::binary>>, at, ln), do: line(text, at - 1, ln + 1)
    defp line(<<"\r"::utf8, text::binary>>, at, ln), do: line(text, at - 1, ln + 1)
    defp line(<<"\r\n"::utf8, text::binary>>, at, ln), do: line(text, at - 2, ln + 1)
    defp line(<<_::utf8, text::binary>>, at, ln), do: line(text, at - 1, ln)

    defp column(text, at), do: column(text, at, 0)
    defp column(_, 0, cn), do: cn
    defp column(<<"\n"::utf8, text::binary>>, at, _cn), do: column(text, at - 1, 0)
    defp column(<<"\r"::utf8, text::binary>>, at, _cn), do: column(text, at - 1, 0)
    defp column(<<"\r\n"::utf8, text::binary>>, at, _cn), do: column(text, at - 2, 0)
    defp column(<<_::utf8, text::binary>>, at, cn), do: column(text, at - 1, cn + 1)

    defp context(text, at, _line, column) do
      at_first_in_line = at - column
      before_at_in_line = String.slice(text, at_first_in_line, column)
      after_at = String.slice(text, at, 60 - column)
      "> #{before_at_in_line}|#{after_at}"
    end
  end

  defmodule Parser do

    defmodule Error, do: defexception [:message]

    def parse!(parser, text) do
      case parse(parser, text) do
        {:ok, result} ->
          result
        {:error, error} ->
          raise Error, message: error
      end
    end

    def parse(parser, text) do
      case parser.(Source.from(text)) do
        %Failure{} = failure ->
          {:error, Failure.format(failure, text)}
        %Success{skip: true} ->
          {:ok, []}
        %Success{result: result} ->
          {:ok, result}
      end
    end

    def whitespace(opts \\ []), do: match(~r/\s/, opts)
    def whitespaces(opts \\ []), do: match(~r/\s+/, opts)

    def eof do
      fn
        %Source{at: at, text: ""} ->
          %Success{from: at, to: at, tail: "", result: []}
        %Source{at: at} ->
          %Failure{at: at, message: "Expected the end of input"}
      end
    end

    def nl do
      fn %Source{} = source ->
        case match(~r/\n|\r\n|\r/).(source) do
          %Success{} = success -> success
          %Failure{} = failure -> %Failure{failure | message: "Expected the end of line"}
        end
      end
    end

    def lrp, do: skip(string("("))
    def rrp, do: skip(string(")"))
    def comma, do: skip(string(","))

    def match(r, opts \\ []) do
      decorate(opts,
        fn %Source{at: at, text: text} ->
          case Regex.run(anchor(r), text, return: :index) do
            [{from, len}] ->
              to = from + len
              {_, tail} = String.split_at(text, to)
              %Success{from: from, to: to, tail: tail, result: String.slice(text, from, len)}
            [{from, len} | subpatterns] ->
              to = from + len
              {_, tail} = String.split_at(text, to)
              result = Enum.map(subpatterns, fn({from, len}) ->
                String.slice(text, from, len)
              end)
              %Success{from: from, to: from + len - 1, tail: tail, result: result}
            nil ->
              %Failure{at: at, message: "Expected match(~r/#{Regex.source(r)}/)"}
          end
        end
      )
    end

    def between(around) do
      between(around, around, [])
    end
    def between(left, right, opts \\ []) do
      decorate(opts,
        seq([skip(left), until(right), skip(right)], to: fn([between]) -> between end)
      )
    end

    def until(p, opts \\ []) do
      concat_to_string = fn(nps) -> List.flatten(nps) |> Enum.join("") end
      decorate(opts,
        case Keyword.get(opts, :escape_with) do
          nil ->
            many(non(p), to: concat_to_string)
          escape ->
            many(one_of([seq([escape, p]), non(p)]), to: concat_to_string)
        end
      )
    end

    def non(p, opts \\ []) do
      decorate(opts,
        fn
          %Source{at: at, text: ""} ->
            %Failure{at: at, message: "Expected not(?)"}
          %Source{at: at, text: text} = source ->
            case p.(source) do
              %Success{} ->
                %Failure{at: at, message: "Expected not(?)"}
              %Failure{} ->
                <<matched::utf8, tail::binary>> = text
                %Success{from: at, to: at + 1, tail: tail, result: <<matched::utf8>>}
          end
        end
      )
    end

    def string(s, opts \\ []) do
      decorate(opts,
        fn %Source{at: at, text: text} ->
          case consume(s, text, 0) do
            {consumed, tail} ->
              %Success{from: at + 1, to: at + consumed, tail: tail, result: s}
            :fail ->
              %Failure{at: at, message: "Expected string(#{s})"}
          end
        end
      )
    end

    def line(p, opts \\ []) do
      decorate(opts,
        seq([skip(maybe(nl)), p, skip(nl)], to: fn [line] -> line end)
      )
    end

    def repeat(parser, exactly) do
      repeat(parser, exactly, exactly, [])
    end
    def repeat(parser, exactly, opts) when is_list(opts) do
      repeat(parser, exactly, exactly, opts)
    end
    def repeat(parser, at_least, at_most, opts \\ []) do
      decorate(opts,
        fn %Source{at: at, text: text} = source ->
          successes =
            Stream.unfold(source,
              fn(%Source{} = source) ->
                case parser.(source) do
                  %Success{to: to, tail: tail} = success ->
                    {success, %Source{at: to, text: tail}}
                  %Failure{} ->
                    nil
                end
              end
            )
            |> Enum.to_list

          case Enum.count(successes) do
            n when n != at_least and at_least == at_most ->
              %Failure{at: at, message: "Expected #{at_least} of ?"}
            n when n < at_least ->
              %Failure{at: at, message: "Expected at least #{at_least} of ?"}
            n when n > at_most ->
              %Failure{at: at, message: "Expected at most #{at_most} of ?"}
            n when n == 0 and at_least == 0 ->
              %Success{from: at, to: at, tail: text, result: []}
            _ ->
              %Success{
                List.last(successes) | from: at, result: successes |> Enum.map(&(&1.result))
              }
          end
        end
      )
    end

    def many(parser, opts \\ []), do: repeat(parser, 0, :infinite, opts)
    def at_least(parser, at_least, opts \\ []), do: repeat(parser, at_least, :infinite, opts)
    def at_most(parser, at_most, opts \\ []), do: repeat(parser, 0, at_most, opts)
    def one_or_more(parser, opts \\ []), do: repeat(parser, 1, :infinite, opts)
    def zero_or_more(parser, opts \\ []), do: repeat(parser, 0, :infinite, opts)

    def skip(parser, opts \\ []) do
      decorate(opts,
        fn %Source{} = source ->
          case parser.(source) do
            %Success{} = success ->
              %Success{success | skip: true}
            %Failure{} = failure ->
              failure
          end
        end
      )
    end

    def maybe(parser, opts \\ []) do
      decorate(opts,
        fn %Source{at: at, text: text} = source ->
          case parser.(source) do
            %Success{} = success ->
              success
            %Failure{} ->
              %Success{from: at, to: at, tail: text, skip: true}
          end
        end
      )
    end

    def peep(parser, opts \\ []) do
      decorate(opts,
        fn %Source{at: at, text: text} = source ->
          case parser.(source) do
            %Success{} ->
              %Success{from: at, to: at, tail: text, skip: true}
            %Failure{} = failure ->
              failure
          end
        end
      )
    end

    def always(result, opts \\ []) do
      decorate(opts,
        fn %Source{at: at, text: text} ->
          %Success{from: at, to: at, tail: text, result: result}
        end
      )
    end

    def one_of(parsers, opts \\ []) do
      decorate(opts,
        fn %Source{at: at} = source ->
          result =
            Enum.reduce(parsers, :nothing, fn
              (parser, :nothing) ->
                case parser.(source) do
                  %Success{} = success ->
                    success
                  %Failure{} ->
                    :nothing
                end
              (_parser, %Success{} = success) ->
                success
            end)
          case result do
            %Success{} = success ->
              success
            :nothing ->
              %Failure{at: at, message: "Expected one_of(?)"}
          end
        end
      )
    end

    def seq(parsers, opts \\ []) do
      decorate(opts,
        fn %Source{} = source ->
          result =
            Enum.reduce(parsers, {source, []}, fn
              (parser, {%Source{} = source, results}) ->
                case parser.(source) do
                  %Success{to: to, tail: tail, skip: true} ->
                    {%Source{at: to, text: tail}, results}
                  %Success{to: to, tail: tail, result: result} ->
                    {%Source{at: to, text: tail}, [result|results]}
                  %Failure{} = failure ->
                    failure
                end
              (_parser, %Failure{} = failure) ->
                failure
            end)
          case result do
            {%Source{at: at, text: text}, results} ->
              %Success{from: source.at, to: at, tail: text, result: Enum.reverse(results)}
            %Failure{} = failure ->
              failure
          end
        end
      )
    end

    def recursive(parser, opts \\ []) do
      decorate(opts,
        fn %Source{} = source ->
          parser.(recursive(parser, opts)).(source)
        end
      )
    end

    def separated_by(element, separator, opts \\ []) do
      decorate(opts,
        seq([element, many(seq([skip(separator), element], to: &List.first/1))],
          to: fn([l, r]) -> Enum.concat([l], r) end
        )
      )
    end

    def surrounded_by(element, around) do
      surrounded_by(element, around, around, [])
    end
    def surrounded_by(element, around, opts) when is_list(opts) do
      surrounded_by(element, around, around, opts)
    end
    def surrounded_by(element, preceding, following, opts \\ []) do
      decorate(opts,
        seq([skip(preceding), element, skip(following)], to: &List.first/1)
      )
    end


    defp decorate(opts, parse) do
      transform_to = Keyword.get(opts, :to, fn(x) -> x end)
      fn %Source{} = source ->
        case parse.(source) do
          %Success{result: result} = success ->
            %Success{success | result: transform_to.(result)}
          %Failure{} = failure ->
            failure
        end
      end
    end

    defp consume(<<h::utf8, t1::binary>>, <<h::utf8, t2::binary>>, c), do: consume(t1, t2, c + 1)
    defp consume("", rest, c), do: {c, rest}
    defp consume(_, _, _), do: :fail

    defp anchor(r) do
      source = Regex.source(r)
      if String.starts_with?(source, "\\A") do
        r
      else
        {:ok, r} = Regex.compile("\\A#{source}")
        r
      end
    end
  end
end
