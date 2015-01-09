defmodule Paco do
  defmodule Source do
    defstruct at: 0, text: ""

    def from(s) when is_binary(s), do: %__MODULE__{at: 0, text: s}
  end

  defmodule Success, do: defstruct from: 0, to: 0, tail: "", result: ""

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
        %Success{result: result} ->
          {:ok, result}
      end
    end

    def whitespace(opts \\ []), do: re(~r/\s/, opts)
    def whitespaces(opts \\ []), do: re(~r/\s+/, opts)

    def eof(_opts \\ []) do
      fn
        %Source{at: at, text: ""} ->
          %Success{from: at, to: at, tail: "", result: ""}
        %Source{at: at} ->
          %Failure{at: at, message: "Expected the end of input"}
      end
    end

    def re(r, opts \\ []) do
      map = Keyword.get(opts, :map, fn(x) -> x end)
      fn %Source{at: at, text: text} ->
        case Regex.run(anchor(r), text, return: :index) do
          [{from, len}] ->
            to = from + len - 1
            {_, tail} = String.split_at(text, to)
            %Success{from: from, to: to, tail: tail, result: map.(String.slice(text, from, len))}
          [{from, len} | subpatterns] ->
            to = from + len - 1
            {_, tail} = String.split_at(text, to)
            result = Enum.map(subpatterns, fn({from, len}) ->
              String.slice(text, from, len)
            end)
            %Success{from: from, to: from + len - 1, tail: tail, result: map.(result)}
          nil ->
            %Failure{at: at, message: "Expected re(~r/#{Regex.source(r)}/)"}
        end
      end
    end

    def string(s, opts \\ []) do
      map = Keyword.get(opts, :map, fn(x) -> x end)
      fn %Source{at: at, text: text} ->
        case consume(s, text, 0) do
          {consumed, tail} ->
            %Success{from: at + 1, to: at + consumed, tail: tail, result: map.(s)}
          :fail ->
            %Failure{at: at, message: "Expected string(#{s})"}
        end
      end
    end

    def many(parser, _opts \\ []) do
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

        results = successes |> Enum.map(&(&1.result))
        {to, tail} = case successes do
          [] ->
            {at, text}
          successes ->
            last_success = List.last(successes)
            {last_success.to, last_success.tail}
        end
        %Success{from: at, to: to, tail: tail, result: results}
      end
    end

    def maybe(parser, _opts \\ []) do
      fn %Source{at: at, text: text} = source ->
        case parser.(source) do
          %Success{} = success ->
            success
          %Failure{} ->
            %Success{from: at, to: at, tail: text, result: :nothing}
        end
      end
    end

    def one_of(parsers, _opts \\ []) do
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
    end

    def seq(parsers, _opts \\ []) do
      fn %Source{} = source ->
        result =
          Enum.reduce(parsers, {source, []}, fn
            (parser, {%Source{} = source, results}) ->
              case parser.(source) do
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
    end

    def recursive(parser) do
      fn(source) ->
        parser.(recursive(parser)).(source)
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
