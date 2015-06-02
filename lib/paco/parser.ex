defmodule Paco.Parser do
  import Paco.Macro.ParserDefinition
  import Paco.Collector

  defstruct id: nil, name: nil, combine: nil, parse: nil

  def as(%Paco.Parser{} = p, name), do: %Paco.Parser{p|name: name}

  def box(%Paco.Parser{} = p), do: p
  def box(%Regex{} = r), do: rex(r)
  def box(s) when is_binary(s), do: lit(s)
  def box(nil), do: always(nil)
  def box(t), do: Paco.Parsable.to_parser(t)


  defmacro then(p, form, [do: clauses]) do
    ensure_are_all_arrow_clauses(clauses, "bind combinator")
    quote do
      then_with(unquote(p), unquote(do_clauses_to_function(form, clauses)))
      |> as("then")
    end
  end

  defmacro then(p, [do: clauses]) do
    ensure_are_all_arrow_clauses(clauses, "bind combinator")
    quote do
      then_with(unquote(p), unquote(do_clauses_to_function(:result, clauses)))
      |> as("then")
    end
  end

  defmacro then(p, f) do
    quote do
      then_with(unquote(p), unquote(f))
      |> as("then")
    end
  end

  parser then_with(box(p), f) when is_function(f) do
    {:arity, arity} = :erlang.fun_info(f, :arity)
    fn state, this ->
      Paco.Collector.notify_started(this, state)
      case p.parse.(state, p) do
        %Paco.Success{result: result} = success ->
          try do
            case arity do
              1 -> f.(result)
              2 -> f.(result, Paco.State.update(state, success))
            end
          catch
            _kind, reason ->
              Paco.Failure.at(state, Paco.describe(this),
                              "raised an exception: #{Exception.message(reason)}")
          else
            p ->
              p = box(p)
              p.parse.(Paco.State.update(state, success), p)
          end
        %Paco.Failure{} = failure ->
          failure
      end
      |> Paco.Collector.notify_ended(state)
    end
  end





  defmacro bind(p, form, [do: clauses]) do
    ensure_are_all_arrow_clauses(clauses, "bind combinator")
    quote do
      bind_to(unquote(p), unquote(do_clauses_to_function(form, clauses)))
      |> as("bind")
    end
  end

  defmacro bind(p, [do: clauses]) do
    ensure_are_all_arrow_clauses(clauses, "bind combinator")
    quote do
      bind_to(unquote(p), unquote(do_clauses_to_function(:result, clauses)))
      |> as("bind")
    end
  end

  defmacro bind(p, f) do
    quote do
      bind_to(unquote(p), unquote(f))
      |> as("bind")
    end
  end

  parser bind_to(box(p), f) when is_function(f) do
    {:arity, arity} = :erlang.fun_info(f, :arity)
    fn state, this ->
      Paco.Collector.notify_started(this, state)
      case p.parse.(state, p) do
        %Paco.Success{result: result} = success ->
          try do
            case arity do
              1 -> f.(result)
              2 -> f.(result, Paco.State.update(state, success))
            end
          catch
            _kind, reason ->
              Paco.Failure.at(state, Paco.describe(this),
                              "raised an exception: #{Exception.message(reason)}")
          else
            result ->
              %Paco.Success{success|result: result}
          end
        %Paco.Failure{} = failure ->
          failure
      end
      |> Paco.Collector.notify_ended(state)
    end
  end

  defp ensure_are_all_arrow_clauses(clauses, where) do
    unless all_arrow_clauses?(clauses) do
      raise ArgumentError, "expected -> clauses for do in #{where}"
    end
  end

  defp all_arrow_clauses?(clauses) when not is_list(clauses), do: false
  defp all_arrow_clauses?(clauses) do
    Enum.all?(clauses, fn {:->, _, _} -> true; _ -> false end)
  end

  defp do_clauses_to_function(:result, clauses) do
    quote do
      fn(r) ->
        case r do
          unquote(clauses)
        end
      end
    end
  end
  defp do_clauses_to_function(:result_and_state, clauses) do
    quote do
      fn(r, s) ->
        case {r, s} do
          unquote(clauses)
        end
      end
    end
  end


  parser whitespace, as: while(&Paco.String.whitespace?/1, 1)
                         |> silent

  parser whitespaces, as: while(&Paco.String.whitespace?/1, {:at_least, 1})
                          |> silent

  parser lex(s), as: lit(s)
                     |> surrounded_by(maybe(whitespaces))
                     |> silent

  parser join(p, joiner \\ ""), as: bind(p, &Enum.join(&1, joiner))

  parser surrounded_by(parser, around) when is_binary(around),
    to: surrounded_by(parser, lex(around), lex(around))
  parser surrounded_by(parser, around),
    to: surrounded_by(parser, around, around)

  parser surrounded_by(parser, left, right) when is_binary(left) and is_binary(right),
    to: surrounded_by(parser, lex(left), lex(right))
  parser surrounded_by(box(parser), left, right),
    as: sequence_of([skip(left), parser, skip(right)])
        |> bind do: ([r] -> r; r -> r)

  parser many(p), to: repeat(p)
  parser exactly(p, n), to: repeat(p, n)
  parser at_least(p, n), to: repeat(p, {n, :infinity})
  parser at_most(p, n), to: repeat(p, {0, n})
  parser one_or_more(p), to: repeat(p, {1, :infinity})
  parser zero_or_more(p), to: repeat(p, {0, :infinity})

  parser repeat(p), to: repeat(p, {0, :infinity})
  parser repeat(p, n) when is_integer(n), to: repeat(p, {n, n})
  parser repeat(p, {:more_than, n}), to: repeat(p, {n+1, :infinity})
  parser repeat(p, {:less_than, n}), to: repeat(p, {0, n-1})
  parser repeat(p, {:at_least, n}), to: repeat(p, {n, :infinity})
  parser repeat(p, {:at_most, n}), to: repeat(p, {0, n})
  parser repeat(box(p), {at_least, at_most}) do
    fn %Paco.State{at: at, text: text} = state, this ->
      notify_started(this, state)
      successes = Stream.unfold({state, 0},
                             fn {_, n} when n == at_most -> nil
                                {state, n} ->
                                  case p.parse.(state, p) do
                                    %Paco.Success{skip: true} = success ->
                                      {:skip, {Paco.State.update(state, success), n + 1}}
                                    %Paco.Success{} = success ->
                                      {success, {Paco.State.update(state, success), n + 1}}
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


  parser always(t) do
    fn %Paco.State{at: at, text: text} = state, this ->
      notify_started(this, state)
      %Paco.Success{from: at, to: at, at: at, tail: text, result: t}
      |> notify_ended(state)
    end
  end

  parser maybe(box(p), opts \\ []) do
    has_default = Keyword.has_key?(opts, :default)
    fn state, this ->
      notify_started(this, state)
      case p.parse.(state, p) do
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

  parser silent(parser) do
    fn state, _ ->
      parser.parse.(%Paco.State{state|silent: true}, parser)
    end
  end

  parser skip(box(p)) do
    fn state, this ->
      notify_started(this, state)
      case p.parse.(state, p) do
        %Paco.Success{keep: true} = success ->
          %Paco.Success{success|keep: false}
        %Paco.Success{} = success ->
          %Paco.Success{success|skip: true}
        %Paco.Failure{} = failure ->
          failure
      end
      |> notify_ended(state)
    end
  end

  parser keep(box(p)) do
    fn state, this ->
      notify_started(this, state)
      case p.parse.(state, p) do
        %Paco.Success{skip: true} = success ->
          %Paco.Success{success|skip: false}
        %Paco.Success{} = success ->
          %Paco.Success{success|keep: true}
        %Paco.Failure{} = failure ->
          failure
      end
      |> notify_ended(state)
    end
  end

  parser only_if(box(p), f) do
    {:arity, arity} = :erlang.fun_info(f, :arity)
    fn state, this ->
      notify_started(this, state)
      case p.parse.(state, p) do
        %Paco.Success{result: result} = success ->
          try do
            case arity do
              1 -> f.(result)
              2 -> f.(result, Paco.State.update(state, success))
            end
          catch
            _kind, reason ->
              Paco.Failure.at(state, Paco.describe(this),
                              "raised an exception: #{Exception.message(reason)}")
          else
            true ->
              success
            false ->
              Paco.Failure.at(state, Paco.describe(this),
                              "considered #{inspect(result)} not acceptable")
          end
        %Paco.Failure{} = failure ->
          failure
      end
      |> notify_ended(state)
    end
  end

  parser sequence_of(box_each(ps)) do
    fn %Paco.State{at: from, text: text} = state, this ->
      notify_started(this, state)
      result = Enum.reduce(ps, {state, from, []},
                           fn
                             (_, %Paco.Failure{} = failure) ->
                               failure
                             (p, {state, to, results}) ->
                               case p.parse.(state, p) do
                                 %Paco.Success{from: at, to: at, at: at, skip: true} ->
                                   {state, to, results}
                                 %Paco.Success{from: at, to: at, at: at, result: result} ->
                                   {state, to, [result|results]}
                                 %Paco.Success{to: to, skip: true} = success ->
                                   {Paco.State.update(state, success), to, results}
                                 %Paco.Success{to: to, result: result} = success ->
                                   {Paco.State.update(state, success), to, [result|results]}
                                 %Paco.Failure{} = failure ->
                                   failure
                               end
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

  parser one_of(box_each(ps)) do
    fn %Paco.State{at: from, text: text} = state, this ->
      notify_started(this, state)
      result = Enum.find_value(ps,
                               fn(p) ->
                                 case p.parse.(state, p) do
                                   %Paco.Success{} = success -> success
                                   _ -> false
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

  parser rex(r) do
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

  parser lit(s) do
    fn %Paco.State{at: from, text: text, stream: stream} = state, this ->
      case Paco.String.consume(text, s, from) do
        {tail, to, at} ->
          notify_started(this, state)
          success = %Paco.Success{from: from, to: to, at: at, tail: tail, result: s}
          notify_ended(success, state)
        :end_of_input when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        error ->
          notify_started(this, state)
          description = Paco.describe(this)
          reason = if error == :end_of_input, do: "reached the end of input", else: nil
          failure = %Paco.Failure{at: from, tail: text, what: description, because: reason}
          notify_ended(failure, state)
      end
    end
  end

  parser any(n \\ 1) do
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

  parser until(p, opts \\ []) do
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

  parser while(p), to: while(p, {0, :infinity})
  parser while(p, n) when is_integer(n), to: while(p, {n, n})
  parser while(p, {:more_than, n}), to: while(p, {n+1, :infinity})
  parser while(p, {:less_than, n}), to: while(p, {0, n-1})
  parser while(p, {:at_least, n}), to: while(p, {n, :infinity})
  parser while(p, {:at_most, n}), to: while(p, {0, n})
  parser while(p, {at_least, at_most}) do
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
        error ->
          notify_started(this, state)
          description = Paco.describe(this)
          reason = if error == :end_of_input, do: "reached the end of input", else: nil
          failure = %Paco.Failure{at: from, tail: text, what: description, because: reason}
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
  def inspect(p, opts) do
    Paco.Inspect.parser(p, opts)
  end
end
