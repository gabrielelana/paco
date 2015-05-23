defmodule Paco.Parser do
  import Paco.Macro

  defstruct id: nil, name: nil, combine: nil, parse: nil

  def from(%Paco.Parser{} = p), do: p
  def from(%Regex{} = r), do: re(r)

  defp notify_loaded(_text, %Paco.State{collector: nil}), do: nil
  defp notify_loaded(_text, %Paco.State{silent: true}), do: nil
  defp notify_loaded(text, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:loaded, text})
  end

  defp notify_started(_parser, %Paco.State{collector: nil}), do: nil
  defp notify_started(_parser, %Paco.State{silent: true}), do: nil
  defp notify_started(parser, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:started, Paco.describe(parser)})
  end

  defp notify_ended(result, %Paco.State{collector: nil}), do: result
  defp notify_ended(result, %Paco.State{silent: true}), do: result
  defp notify_ended(%Paco.Success{} = success, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:matched, success.from, success.to, success.at})
    success
  end
  defp notify_ended(%Paco.Failure{} = failure, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:failed, failure.at})
    failure
  end


  parser_ whitespace, as: while(&Paco.String.whitespace?/1, 1)
                          |> silent

  parser_ whitespaces, as: while(&Paco.String.whitespace?/1, {:at_least, 1})
                           |> silent

  parser_ lex(s), as: lit(s)
                      |> surrounded_by(maybe(whitespaces))
                      |> silent
  # parser_ lex(s), as: sequence_of([skip(while(&Paco.String.whitespace?/1, {0, :infinity})),
  #                                  lit(s),
  #                                  skip(while(&Paco.String.whitespace?/1, {0, :infinity}))])
  #                     |> bind(&List.first/1)

  parser_ surrounded_by(parser, around), do: surrounded_by(parser, around, around)
  # parser_ surrounded_by(parser, left, right),
  #   as: sequence_of([skip(left), parser, skip(right)]) |> bind(&List.first/1)
  parser_ surrounded_by(parser, left, right) do
    parser = sequence_of([skip(left), parser, skip(right)])
    fn state, this ->
      notify_started(this, state)
      case parser.parse.(state, parser) do
        %Paco.Success{result: [result]} = success ->
          %Paco.Success{success|result: result}
        %Paco.Failure{} = failure ->
          %Paco.Failure{failure|what: Paco.describe(this)}
      end
      |> notify_ended(state)
    end
  end

  parser_ many(p), forward_to: repeat(p)
  parser_ exactly(p, n), forward_to: repeat(p, n)
  parser_ at_least(p, n), forward_to: repeat(p, {n, :infinity})
  parser_ at_most(p, n), forward_to: repeat(p, {0, n})
  parser_ one_of_more(p), forward_to: repeat(p, {1, :infinity})
  parser_ zero_or_more(p), forward_to: repeat(p, {0, :infinity})

  parser_ repeat(parser), do: repeat(parser, {0, :infinity})
  parser_ repeat(parser, n) when is_integer(n), do: repeat(parser, {n, n})
  parser_ repeat(parser, {:more_than, n}), do: repeat(parser, {n+1, :infinity})
  parser_ repeat(parser, {:less_than, n}), do: repeat(parser, {0, n-1})
  parser_ repeat(parser, {:at_least, n}), do: repeat(parser, {n, :infinity})
  parser_ repeat(parser, {:at_most, n}), do: repeat(parser, {0, n})
  parser_ repeat(parser, {at_least, at_most}) do
    fn %Paco.State{at: at, text: text} = state, this ->
      notify_started(this, state)
      successes = Stream.unfold({state, 0},
                             fn {_, n} when n == at_most -> nil
                                {state, n} ->
                                  case parser.parse.(state, parser) do
                                    %Paco.Success{at: at, tail: tail, skip: true} ->
                                      {:skip, {%Paco.State{state|at: at, text: tail}, n + 1}}
                                    %Paco.Success{at: at, tail: tail} = success ->
                                      {success, {%Paco.State{state|at: at, text: tail}, n + 1}}
                                    %Paco.Failure{} ->
                                      nil
                                  end
                             end)
               |> Enum.filter(&match?(%Paco.Success{}, &1))
               |> Enum.to_list

      failure = %Paco.Failure{at: at, tail: text, what: Paco.describe(this)}
      case Enum.count(successes) do
        n when n != at_least and at_least == at_most ->
          because = "matched #{n} times instead of #{at_least}"
          %Paco.Failure{failure|because: because}
        n when n < at_least ->
          because = "matched #{n} times instead of at least #{at_least} times"
          %Paco.Failure{failure|because: because}
        n when n == 0 and at_least == 0 ->
          %Paco.Success{from: at, to: at, at: at, tail: text, result: []}
        _ ->
          last_success = List.last(successes)
          results = successes |> Enum.map(&(&1.result))
          %Paco.Success{last_success|from: at, result: results}
      end
      |> notify_ended(state)
    end
  end

  parser_ maybe(%Paco.Parser{} = parser, opts \\ []) do
    has_default = Keyword.has_key?(opts, :default)
    fn state, this ->
      notify_started(this, state)
      case parser.parse.(state, parser) do
        %Paco.Success{} = success ->
          success
        %Paco.Failure{at: at, tail: tail} when has_default ->
          result = Keyword.get(opts, :default)
          %Paco.Success{from: at, to: at, at: at, tail: tail, result: result}
        %Paco.Failure{at: at, tail: tail} ->
          %Paco.Success{from: at, to: at, at: at, tail: tail, skip: true}
      end
      |> notify_ended(state)
    end
  end

  parser_ silent(parser) do
    fn state, _ ->
      parser.parse.(%Paco.State{state|silent: true}, parser)
    end
  end

  parser_ skip(parser) do
    fn state, this ->
      notify_started(this, state)
      case parser.parse.(state, parser) do
        %Paco.Success{} = success ->
          %Paco.Success{success|skip: true}
        %Paco.Failure{} = failure ->
          failure
      end
      |> notify_ended(state)
    end
  end

  parser_ sequence_of(parsers) do
    fn %Paco.State{at: from, text: text} = state, this ->
      notify_started(this, state)
      result = Enum.reduce(parsers, {state, from, []},
                           fn
                             (%Paco.Parser{} = parser, {state, _, results}) ->
                               case parser.parse.(state, parser) do
                                 %Paco.Success{to: to, at: at, tail: tail, skip: true} ->
                                   {%Paco.State{state|at: at, text: tail}, to, results}
                                 %Paco.Success{to: to, at: at, tail: tail, result: result} ->
                                   {%Paco.State{state|at: at, text: tail}, to, [result|results]}
                                 %Paco.Failure{} = failure ->
                                   failure
                               end
                             (_, %Paco.Failure{} = failure) ->
                               failure
                           end)

      case result do
        {%Paco.State{at: at, text: text}, to, results} ->
          %Paco.Success{from: from, to: to, at: at, tail: text, result: Enum.reverse(results)}
        %Paco.Failure{} = failure ->
          %Paco.Failure{at: from, tail: text, what: Paco.describe(this), because: failure}
      end
      |> notify_ended(state)
    end
  end

  parser_ one_of([parser]), do: parser
  parser_ one_of([]) do
    raise ArgumentError, message: "Must give at least one parser to one_of combinator"
  end
  parser_ one_of(parsers) do
    fn %Paco.State{at: from, text: text} = state, this ->
      notify_started(this, state)
      result = Enum.reduce(parsers, [],
                           fn
                             (_, %Paco.Success{} = success) ->
                               success
                             (%Paco.Parser{} = parser, failures) ->
                               case parser.parse.(state, parser) do
                                 %Paco.Success{} = success ->
                                   success
                                 %Paco.Failure{} = failure ->
                                   [failure|failures]
                               end
                           end)

      case result do
         %Paco.Success{} = success ->
           success
         _ ->
           %Paco.Failure{at: from, tail: text, what: Paco.describe(this)}
       end
       |> notify_ended(state)
    end
  end

  parser_ re(r) do
    fn %Paco.State{at: from, text: text, stream: stream} = state, this ->
      case Regex.run(anchor(r), text, return: :index) do
        [{_, len}] ->
          case Paco.String.seek(text, from, len) do
            {_, "", _, _} when is_pid(stream) ->
              wait_for_more_and_continue(state, this)
            {s, tail, to, at} ->
              notify_started(this, state)
              success = %Paco.Success{from: from, to: to, at: at,
                                      tail: tail, result: s}
              notify_ended(success, state)
          end
        [{_, len}|captures] ->
          case Paco.String.seek(text, from, len) do
            {_, "", _, _} when is_pid(stream) ->
              wait_for_more_and_continue(state, this)
            {s, tail, to, at} ->
              captures = case Regex.names(r) do
                [] ->
                  captures
                  |> Enum.map(fn({from, len}) -> String.slice(text, from, len) end)
                _ ->
                  [Regex.named_captures(r, text)]
              end
              notify_started(this, state)
              success = %Paco.Success{from: from, to: to, at: at,
                                      tail: tail, result: [s|captures]}
              notify_ended(success, state)
          end
        nil when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        nil ->
          notify_started(this, state)
          failure = %Paco.Failure{at: from, tail: text, what: Paco.describe(this)}
          notify_ended(failure, state)
      end
    end
  end

  parser_ lit(s) do
    fn %Paco.State{at: from, text: text, stream: stream} = state, this ->
      case Paco.String.consume(text, s, from) do
        {tail, to, at} ->
          notify_started(this, state)
          success = %Paco.Success{from: from, to: to, at: at, tail: tail, result: s}
          notify_ended(success, state)
        :end_of_input when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        _ ->
          notify_started(this, state)
          failure = %Paco.Failure{at: from, tail: text, what: Paco.describe(this)}
          notify_ended(failure, state)
      end
    end
  end

  parser_ any(n \\ 1) do
    fn %Paco.State{at: from, text: text, stream: stream} = state, this ->
      case Paco.String.consume_any(text, n, from) do
        {consumed, tail, to, at} ->
          notify_started(this, state)
          success = %Paco.Success{from: from, to: to, at: at, tail: tail, result: consumed}
          notify_ended(success, state)
        :end_of_input when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        :end_of_input ->
          notify_started(this, state)
          failure = %Paco.Failure{at: from, tail: text, what: Paco.describe(this),
                                  because: "reached the end of input"}
          notify_ended(failure, state)
      end
    end
  end

  parser_ until(p, opts \\ []) do
    fn %Paco.State{at: from, text: text, stream: stream} = state, this ->
      case Paco.String.consume_until(text, p, from) do
        {_, "", _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {consumed, tail, to, at} ->
          notify_started(this, state)
          success = %Paco.Success{from: from, to: to, at: at, tail: tail, result: consumed}
          notify_ended(success, state)
        _ ->
          notify_started(this, state)
          failure = %Paco.Failure{at: from, tail: text, what: Paco.describe(this)}
          notify_ended(failure, state)
      end
    end
  end

  parser_ while(p), do: while(p, {0, :infinity})
  parser_ while(p, n) when is_integer(n), do: while(p, {n, n})
  parser_ while(p, {:more_than, n}), do: while(p, {n+1, :infinity})
  parser_ while(p, {:less_than, n}), do: while(p, {0, n-1})
  parser_ while(p, {:at_least, n}), do: while(p, {n, :infinity})
  parser_ while(p, {:at_most, n}), do: while(p, {0, n})
  parser_ while(p, {at_least, at_most}) do
    fn %Paco.State{at: from, text: text, stream: stream} = state, this ->
      case Paco.String.consume_while(text, p, {at_least, at_most}, from) do
        {_, "", _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {consumed, tail, to, at} ->
          notify_started(this, state)
          success = %Paco.Success{from: from, to: to, at: at, tail: tail, result: consumed}
          notify_ended(success, state)
        :end_of_input when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        _ ->
          notify_started(this, state)
          failure = %Paco.Failure{at: from, tail: text, what: Paco.describe(this)}
          notify_ended(failure, state)
      end
    end
  end

  defp wait_for_more_and_continue(state, this) do
    %Paco.State{text: text, stream: stream} = state
    send(stream, {self, :more})
    receive do
      {:load, more_text} ->
        notify_loaded(more_text, state)
        this.parse.(%Paco.State{state|text: text <> more_text}, this)
      :halted ->
        # The stream is over, switching to a non stream mode is equal to
        # tell the parser to behave knowing that more input will never come
        this.parse.(%Paco.State{state|stream: nil}, this)
    end
  end

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

defimpl Inspect, for: Paco.Parser do
  import Inspect.Algebra
  alias Inspect.Opts

  def inspect(%Paco.Parser{id: nil, name: name, combine: []}, _opts), do: "#{name}"
  def inspect(%Paco.Parser{id: nil, name: name, combine: nil}, _opts), do: "#{name}"
  def inspect(%Paco.Parser{id: nil, name: name}, %Opts{width: 0}), do: "#{name}"
  def inspect(%Paco.Parser{id: nil, name: name, combine: args}, opts) do
    concat ["#{name}", surround_many("(", args, ")", %Opts{opts|width: 0}, &to_doc/2)]
  end
  def inspect(%Paco.Parser{id: id, name: name, combine: []}, _opts), do: "#{name}##{id}"
  def inspect(%Paco.Parser{id: id, name: name, combine: nil}, _opts), do: "#{name}##{id}"
  def inspect(%Paco.Parser{id: id, name: name}, %Opts{width: 0}), do: "#{name}##{id}"
  def inspect(%Paco.Parser{id: id, name: name, combine: args}, opts) do
    concat ["#{name}##{id}", surround_many("(", args, ")", %Opts{opts|width: 0}, &to_doc/2)]
  end
end
