defmodule Paco.Parser do
  import Paco.Macro.ParserDefinition

  defstruct id: nil, name: nil, description: nil, combine: nil, parse: nil

  def as(%Paco.Parser{} = p, description), do: %Paco.Parser{p|description: description}

  def box(%Paco.Parser{} = p), do: p
  def box(%Regex{} = r), do: re(r)
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

  parser whitespaces, as: while(&Paco.String.whitespace?/1, {:at_least, 1})

  parser lex(s), as: lit(s)
                     |> surrounded_by(maybe(whitespaces))

  parser join(p, joiner \\ ""), as: bind(p, &Enum.join(&1, joiner))

  parser replace_with(box(p), v), as: bind(p, fn _ -> v end)

  parser separated_by(p, s) when is_binary(s), to: separated_by(p, lex(s))
  parser separated_by(box(p), box(s)),
    as: (import Paco.Transform, only: [flatten_first: 1]
         tail = many(sequence_of([skip(s), p])) |> bind(&flatten_first/1)
         sequence_of([p, tail]) |> bind(&flatten_first/1))

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
    end
  end


  parser always(t) do
    fn %Paco.State{at: at, text: text}, _ ->
      %Paco.Success{from: at, to: at, at: at, tail: text, result: t}
    end
  end

  parser maybe(box(p), opts \\ []) do
    has_default = Keyword.has_key?(opts, :default)
    fn state, _ ->
      case p.parse.(state, p) do
        %Paco.Success{} = success ->
          success
        %Paco.Failure{at: at, tail: tail} when has_default ->
          result = Keyword.get(opts, :default)
          %Paco.Success{from: at, to: at, at: at, tail: tail, result: result}
        %Paco.Failure{at: at, tail: tail} ->
          %Paco.Success{from: at, to: at, at: at, tail: tail, skip: true}
      end
    end
  end

  parser skip(box(p)) do
    fn state, _ ->
      case p.parse.(state, p) do
        %Paco.Success{keep: true} = success ->
          %Paco.Success{success|keep: false}
        %Paco.Success{} = success ->
          %Paco.Success{success|skip: true}
        %Paco.Failure{} = failure ->
          failure
      end
    end
  end

  parser keep(box(p)) do
    fn state, _ ->
      case p.parse.(state, p) do
        %Paco.Success{skip: true} = success ->
          %Paco.Success{success|skip: false}
        %Paco.Success{} = success ->
          %Paco.Success{success|keep: true}
        %Paco.Failure{} = failure ->
          failure
      end
    end
  end

  parser only_if(box(p), f) do
    {:arity, arity} = :erlang.fun_info(f, :arity)
    fn state, this ->
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
    end
  end



  parser sequence_of(box_each(ps)) do
    fn %Paco.State{at: from} = state, this ->
      case reduce_sequence_of(ps, state, from) do
        {%Paco.State{at: at, text: text}, to, results} ->
          %Paco.Success{from: from, to: to, at: at, tail: text, result: Enum.reverse(results)}
        %Paco.Failure{} = failure ->
          Paco.Failure.stack(failure, this)
      end
    end
  end

  defp reduce_sequence_of(ps, state, from) do
    Enum.reduce(ps, {state, from, []}, &reduce_sequence_of/2)
  end

  defp reduce_sequence_of(_, %Paco.Failure{} = failure), do: failure
  defp reduce_sequence_of(p, {state, to, results}) do
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
  end



  parser one_of(box_each(ps)) do
    fn state, _ ->
      case reduce_one_of(ps, state) do
        # [] -> ???
        %Paco.Success{} = success ->
          success
        failures ->
          keep_farthest_failure(failures)
      end
    end
  end

  defp reduce_one_of(ps, state) do
    Enum.reduce(ps, {state, []}, &reduce_one_of_each/2) |> elem(1)
  end

  defp reduce_one_of_each(_, {_, %Paco.Success{}} = success), do: success
  defp reduce_one_of_each(p, {state, failures}) do
    case p.parse.(state, p) do
      %Paco.Success{} = success -> {state, success}
      %Paco.Failure{} = failure -> {state, [failure|failures]}
    end
  end

  defp keep_farthest_failure(failures) do
    Enum.reduce(failures, nil, &keep_farthest_failure/2)
  end

  defp keep_farthest_failure(failure, nil), do: failure
  defp keep_farthest_failure(%Paco.Failure{at: {n,_,_}} = failure,
                             %Paco.Failure{at: {m,_,_}})
                             when n >= m, do: failure
  defp keep_farthest_failure(_, failure), do: failure



  parser re(r) do
    fn %Paco.State{at: from, text: text, stream: stream} = state, this ->
      case Regex.run(anchor(r), text, return: :index) do
        [{_, n}] ->
          case Paco.String.seek(text, n, from) do
            {"", _, _, _} when is_pid(stream) ->
              wait_for_more_and_continue(state, this)
            {tail, s, to, at} ->
              %Paco.Success{from: from, to: to, at: at, tail: tail, result: s}
          end
        [{_, n}|captures] ->
          case Paco.String.seek(text, n, from) do
            {"", _, _, _} when is_pid(stream) ->
              wait_for_more_and_continue(state, this)
            {tail, s, to, at} ->
              captures = case Regex.names(r) do
                [] ->
                  captures
                  |> Enum.map(fn({from, len}) -> String.slice(text, from, len) end)
                _ ->
                  Regex.named_captures(r, text)
              end
              %Paco.Success{from: from, to: to, at: at, tail: tail, result: {s, captures}}
          end
        nil when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        nil ->
          %Paco.Failure{at: from, tail: text, expected: {:re, r},
                        stack: Paco.Failure.stack(this)}
      end
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

  parser lit(s) do
    fn %Paco.State{at: from, text: text, stream: stream} = state, this ->
      case Paco.String.consume(text, s, from) do
        {tail, _, to, at} ->
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: s}
        {:not_enough, _, _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {_, _, consumed, _, _} ->
          %Paco.Failure{at: from, tail: text, expected: s,
                        confidence: String.length(consumed) + 1,
                        stack: Paco.Failure.stack(this)}
      end
    end
  end

  parser any, to: any({1, 1})
  parser any(n) when is_integer(n), to: any({n, n})
  parser any(opts) when is_list(opts), to: any(extract_limits(opts))
  parser any({at_least, at_most}) do
    fn %Paco.State{at: from, text: text, stream: stream} = state, this ->
      case Paco.String.consume_any(text, {at_least, at_most}, from) do
        {"", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {tail, consumed, to, at} ->
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: consumed}
        {:not_enough, _, _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {:not_enough, _, _, _, _} ->
          %Paco.Failure{at: from, tail: text,
                        expected: {:any, at_least, at_most},
                        stack: Paco.Failure.stack(this)}
      end
    end
  end

  parser until(p, [escaped_with: escape]), to: until({p, escape})
  parser until(p) do
    fn %Paco.State{at: from, text: text, stream: stream} = state, this ->
      case Paco.String.consume_until(text, p, from) do
        {"", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {tail, consumed, to, at} ->
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: consumed}
        {:not_enough, "", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {:not_enough, _, _, _, _} ->
          %Paco.Failure{at: from, tail: text,
                        expected: {:until, p},
                        stack: Paco.Failure.stack(this)}
      end
    end
  end


  parser while(p), to: while(p, {0, :infinity})
  parser while(p, n) when is_integer(n), to: while(p, {n, n})
  parser while(p, opts) when is_list(opts), to: while(p, extract_limits(opts))
  parser while(p, {at_least, at_most}) do
    fn %Paco.State{at: from, text: text, stream: stream} = state, this ->
      case Paco.String.consume_while(text, p, {at_least, at_most}, from) do
        {"", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {tail, consumed, to, at} ->
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: consumed}
        {:not_enough, "", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {:not_enough, _, consumed, _, _} ->
          %Paco.Failure{at: from, tail: text,
                        expected: {:while, p, at_least, at_most},
                        confidence: String.length(consumed),
                        stack: Paco.Failure.stack(this)}
      end
    end
  end

  defp extract_limits([exactly: n]), do: {n, n}
  defp extract_limits([more_than: n]), do: {n+1, :infinity}
  defp extract_limits([less_than: n]), do: {0, n-1}
  defp extract_limits([more_than: n, less_than: m]) when n < m, do: {n+1, n-1}
  defp extract_limits([at_least: n]), do: {n, :infinity}
  defp extract_limits([at_most: n]), do: {0, n}
  defp extract_limits([at_least: n, at_most: m]) when n <= m, do: {n, m}

  defp wait_for_more_and_continue(state, this) do
    %Paco.State{text: text, stream: stream} = state
    send(stream, {self, :more})
    receive do
      {:load, more_text} ->
        this.parse.(%Paco.State{state|text: text <> more_text}, this)
      :halted ->
        # The stream is over, switching to a non stream mode is equal to
        # tell the parser to behave knowing that more input will never come
        this.parse.(%Paco.State{state|stream: nil}, this)
    end
  end
end

defimpl Inspect, for: Paco.Parser do
  def inspect(p, opts) do
    Paco.Inspect.parser(p, opts)
  end
end
