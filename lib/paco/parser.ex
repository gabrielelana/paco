defmodule Paco.Parser do
  alias Paco.Parser
  alias Paco.State
  alias Paco.Success
  alias Paco.Failure

  import Paco.Macro.ParserDefinition

  defstruct id: nil, name: nil, description: nil, parse: nil

  def as(p, description), do: %Parser{box(p)|description: description}

  def box(%Parser{} = p), do: p
  def box(%Regex{} = r), do: re(r)
  def box(s) when is_binary(s), do: lit(s)
  def box(nil), do: always(nil)
  def box(t), do: Paco.Parsable.to_parser(t)



  parser line(opts \\ []), to: (
    p = until(Paco.ASCII.nl, Keyword.put(opts, :eof, true))
    p = if Keyword.get(opts, :skip_empty, false) do
          p |> followed_by(many(one_of(Paco.ASCII.nl)))
            |> preceded_by(many(one_of(Paco.ASCII.nl)))
            |> bind(fn("", success) -> %Success{success|skip: true}
                      (_ , success) -> success
                    end)
        else
          p |> followed_by(maybe(one_of(Paco.ASCII.nl)))
        end
    p |> only_if(&consumed_any_input?(&1, &2, "an empty string is not a line %AT%")))



  parser otherwise(p, f) when is_function(f), to: otherwise(p, f.(p))
  parser otherwise(box(p), box(n)) do
    fn state, this ->
      case p.parse.(state, p) do
        %Success{} = success ->
          success
        %Failure{fatal: true} = failure ->
          failure |> Failure.stack(this)
        %Failure{} = failure ->
          case n.parse.(state, n) do
            %Success{} = success ->
              success
            %Failure{} = alternative_failure ->
              [failure, alternative_failure]
              |> compose_failures
              |> Failure.stack(this)
          end
      end
    end
  end



  parser within(box(inner), box(outer)) do
    fn state, _ ->
      case outer.parse.(state, outer) do
        %Success{skip: true} = success ->
          success
        %Success{from: from, to: to, at: at, tail: tail} = success ->
          chunks = State.chunks_from_result_of(success)
          case reduce_within(inner, state, chunks, []) do
            %Failure{} = failure ->
              failure
            %Success{} = success ->
              %Success{success|from: from, to: to, at: at, tail: tail}
            successes ->
              results = Enum.map(successes, fn(%Success{result: result}) -> result end)
              %Success{from: from, to: to, at: at, tail: tail, result: results}
          end
        %Failure{} = failure ->
          failure
      end
    end
  end

  defp reduce_within(_, _, [], [success]), do: success
  defp reduce_within(_, _, [], successes), do: Enum.reverse(successes)
  defp reduce_within(inner, state, [chunk|chunks], successes) do
    state = State.update_with_chunk(state, chunk)
    case inner.parse.(state, inner) do
      %Success{} = success ->
        reduce_within(inner, state, chunks, [success|successes])
      %Failure{} = failure ->
        failure
    end
  end



  parser cut(box(p)) do
    fn %State{at: at} = state, _ ->
      case p.parse.(state, p) do
        %Success{at: ^at} = success ->
          success
        %Success{sew: true} = success ->
          %Success{success|sew: false}
        %Success{} = success ->
          %Success{success|cut: true}
        %Failure{} = failure ->
          failure
      end
    end
  end

  parser cut do
    fn %State{at: at, chunks: chunks}, _ ->
      %Success{from: at, to: at, at: at, tail: chunks, cut: true, skip: true}
    end
  end

  parser sew(box(p)) do
    fn %State{at: at} = state, _ ->
      case p.parse.(state, p) do
        %Success{at: ^at} = success ->
          success
        %Success{cut: true} = success ->
          %Success{success|cut: false}
        %Success{} = success ->
          %Success{success|sew: true}
        %Failure{} = failure ->
          failure
      end
    end
  end

  parser sew do
    fn %State{at: at, chunks: chunks}, _ ->
      %Success{from: at, to: at, at: at, tail: chunks, sew: true, skip: true}
    end
  end



  parser next(p, f) when is_function(f), as:
    bind(p, f)
    |> bind(fn(p) -> box(p) end)
    |> bind(fn(p, _, s) -> p.parse.(s, p) end)

  parser next(p, box(next)), as:
    bind(p, fn(_, _, s) -> next.parse.(s, next) end)



  parser bind(box(p), f) when is_function(f) do
    fn state, this ->
      case p.parse.(state, p) do
        %Success{skip: true} = success ->
          success
        %Success{result: result} = success ->
          try do
            call_arity_wise(f, result, success, State.update(state, success))
          catch
            :error, reason ->
              message = if Exception.exception?(reason) do
                          "exception: #{Exception.message(reason)} %STACK% %AT%"
                        else
                          "error: #{inspect(reason)} %STACK% %AT%"
                        end
              Failure.at(state, message: message) |> Failure.stack(this)
          else
            %Failure{} = failure ->
              failure |> Failure.stack(this)
            %Success{} = success ->
              success
            result ->
              %Success{success|result: result}
          end
        %Failure{} = failure ->
          failure
      end
    end
  end



  parser whitespace, as: while(&Paco.String.whitespace?/1, exactly: 1)
                         |> fail_with("expected 1 whitespace %AT% but got %TAIL%")

  parser whitespaces, as: while(&Paco.String.whitespace?/1, at_least: 1)
                          |> fail_with("expected at least 1 whitespace %AT% but got %TAIL%")

  parser lex(s), as: lit(s) |> surrounded_by(maybe(whitespaces))

  parser join(p, joiner \\ ""), as: bind(p, &Enum.join(&1, joiner))

  parser replace_with(p, v), as: bind(p, fn _ -> v end)

  parser followed_by(p, t), as: bind([p, skip(t)], &List.first/1)

  parser preceded_by(p, t), as: bind([skip(t), p], &List.first/1)

  parser recursive(f) do
    fn state, this ->
      box(f.(this)).parse.(state, this)
    end
  end

  parser eof do
    fn
      %State{at: at, chunks: []}, _ ->
        %Success{from: at, to: at, at: at, skip: true}
      %State{at: at, chunks: [{_, ""}]}, _ ->
        %Success{from: at, to: at, at: at, skip: true}
      %State{at: at, chunks: chunks}, _ ->
        %Failure{at: at, tail: chunks, rank: at,
                 message: "expected the end of input %AT%"}
    end
  end

  parser peek(box(p)) do
    fn %State{at: at, chunks: chunks} = state, this ->
      case p.parse.(state, p) do
        %Success{result: result} ->
          %Success{from: at, to: at, at: at, tail: chunks, result: result}
        %Failure{} = failure ->
          failure |> Failure.stack(this)
      end
    end
  end

  parser separated_by(p, s), to: separated_by(p, s, at_least: 0)
  parser separated_by(p, s, opts) when is_binary(s), to: separated_by(p, lex(s), opts)
  parser separated_by(box(p), box(s), opts),
    as: (import Paco.Transform, only: [flatten_first: 1]
         tail = repeat(sequence_of([cut(skip(s)), p]), opts)
                |> bind(&flatten_first/1)
         sequence_of([p, tail])
         |> bind(fn([h, []]) -> [h]; ([h, t]) -> [h|t] end))

  parser surrounded_by(parser, around) when is_binary(around),
    to: surrounded_by(parser, lex(around), lex(around))
  parser surrounded_by(parser, around),
    to: surrounded_by(parser, around, around)

  parser surrounded_by(parser, left, right) when is_binary(left) and is_binary(right),
    to: surrounded_by(parser, lex(left), lex(right))
  parser surrounded_by(box(parser), left, right),
    as: sequence_of([skip(left), parser, skip(right)])
        |> bind(fn([r]) -> r; (r) -> r end)

  parser many(p), to: repeat(p)
  parser exactly(p, n), to: repeat(p, n)
  parser at_least(p, n), to: repeat(p, {n, :infinity})
  parser at_most(p, n), to: repeat(p, {0, n})
  parser one_or_more(p), to: repeat(p, {1, :infinity})
  parser zero_or_more(p), to: repeat(p, {0, :infinity})

  parser repeat(p), to: repeat(p, {0, :infinity})
  parser repeat(p, n) when is_integer(n), to: repeat(p, {n, n})
  parser repeat(p, opts) when is_list(opts), to: repeat(p, extract_limits(opts))
  parser repeat(box(p), {at_least, at_most}) do
    fn %State{at: from, chunks: chunks} = state, this ->
      case unfold_repeat(p, state, at_most) do
        {_, _, %Failure{fatal: true} = failure} ->
          failure |> Failure.stack(this)
        {n, _, failure} when n < at_least ->
          failure |> Failure.stack(this)
        {0, _, _} ->
          %Success{from: from, to: from, at: from, tail: chunks, result: []}
        {_, successes, _} ->
          last = List.last(successes)
          results = successes |> Enum.reject(&(&1.skip)) |>  Enum.map(&(&1.result))
          %Success{from: from, to: last.to, at: last.at,
                   tail: last.tail, result: results}
      end
    end
  end

  defp unfold_repeat(p, state, at_most) do
    unfold_repeat(p, state, 0, at_most, [])
  end

  defp unfold_repeat(_, _, n, n, successes) do
    {n, successes |> Enum.reverse, nil}
  end
  defp unfold_repeat(p, state, n, m, successes) do
    case p.parse.(state, p) do
      %Success{} = success ->
        state = State.update(state, success)
        unfold_repeat(p, state, n+1, m, [success|successes])
      %Failure{} = failure ->
        {n, successes |> Enum.reverse, failure}
    end
  end



  parser always(t) do
    fn %State{at: at, chunks: chunks}, _ ->
      %Success{from: at, to: at, at: at, tail: chunks, result: t}
    end
  end


  parser fail_with(p, message) do
    fn state, this ->
      case p.parse.(state, p) do
        %Success{} = success ->
          success
        %Failure{} = failure ->
          %Failure{failure|message: message}
          |> Failure.stack(this)
      end
    end
  end



  parser maybe(box(p), opts \\ []) do
    has_default = Keyword.has_key?(opts, :default)
    fn state, _ ->
      case p.parse.(state, p) do
        %Success{} = success ->
          success
        %Failure{at: at, tail: tail} when has_default ->
          result = Keyword.get(opts, :default)
          %Success{from: at, to: at, at: at, tail: tail, result: result}
        %Failure{at: at, tail: tail} ->
          %Success{from: at, to: at, at: at, tail: tail, skip: true}
      end
    end
  end



  parser skip(box(p)) do
    fn state, _ ->
      case p.parse.(state, p) do
        %Success{keep: true} = success ->
          %Success{success|keep: false}
        %Success{} = success ->
          %Success{success|skip: true}
        %Failure{} = failure ->
          failure
      end
    end
  end



  parser keep(box(p)) do
    fn state, _ ->
      case p.parse.(state, p) do
        %Success{skip: true} = success ->
          %Success{success|skip: false}
        %Success{} = success ->
          %Success{success|keep: true}
        %Failure{} = failure ->
          failure
      end
    end
  end



  parser only_if(p, f), to:
    bind(p, fn(result, success, state) ->
              case call_arity_wise(f, result, success, state) do
                true ->
                  success
                false ->
                  message = "#{inspect(result)} is not acceptable %STACK% %AT%"
                  %Failure{at: success.from, tail: success.tail, message: message}
                {false, message} ->
                  message = String.replace(message, "%RESULT%", inspect(result))
                  %Failure{at: success.from, tail: success.tail, message: message}
              end
            end)



  parser sequence_of(box_each(ps)) do
    fn %State{at: from} = state, this ->
      case reduce_sequence_of(ps, state, from) do
        {%State{at: at, chunks: chunks}, to, results, _} ->
          %Success{from: from, to: to, at: at, tail: chunks, result: Enum.reverse(results)}
        %Failure{} = failure ->
          failure |> Failure.stack(this)
      end
    end
  end

  defp reduce_sequence_of(ps, state, from) do
    Enum.reduce(ps, {state, from, [], {false, false}}, &reduce_sequence_of/2)
  end

  defp reduce_sequence_of(_, %Failure{} = failure), do: failure
  defp reduce_sequence_of(p, {state, at, results, {cut, sew}}) do
    case p.parse.(state, p) do
      %Success{from: ^at, to: ^at, at: ^at, skip: true} = success ->
        {cut, sew} = cut_and_sew(success.cut, success.sew, cut, sew)
        {state, at, results, {cut, sew}}
      %Success{from: ^at, to: ^at, at: ^at, result: result} = success ->
        {cut, sew} = cut_and_sew(success.cut, success.sew, cut, sew)
        {state, at, [result|results], {cut, sew}}
      %Success{to: to, skip: true} = success ->
        {cut, sew} = cut_and_sew(success.cut, success.sew, cut, sew)
        {State.update(state, success), to, results, {cut, sew}}
      %Success{to: to, result: result} = success ->
        {cut, sew} = cut_and_sew(success.cut, success.sew, cut, sew)
        {State.update(state, success), to, [result|results], {cut, sew}}
      %Failure{} = failure when cut ->
        %Failure{failure|fatal: true}
      %Failure{} = failure ->
        failure
    end
  end

  defp cut_and_sew(true, _, _, true),  do: {false, false}
  defp cut_and_sew(true, _, _, false), do: {true, false}
  defp cut_and_sew(_, true, true, _),  do: {false, false}
  defp cut_and_sew(_, true, false, _), do: {false, true}
  defp cut_and_sew(_, _, cut, sew),    do: {cut, sew}



  parser one_of(box_each(ps)) do
    fn %State{at: at, chunks: chunks} = state, this ->
      case reduce_one_of(ps, state) do
        [] ->
          %Success{from: at, to: at, at: at, tail: chunks, skip: true}
        %Success{} = success ->
          success
        failures ->
          compose_failures(failures) |> Failure.stack(this)
      end
    end
  end

  defp reduce_one_of(ps, state) do
    Enum.reduce(ps, {state, []}, &reduce_one_of_each/2) |> elem(1)
  end

  defp reduce_one_of_each(_, {_, [%Failure{fatal: true}]} = failure), do: failure
  defp reduce_one_of_each(_, {_, %Success{}} = success), do: success
  defp reduce_one_of_each(p, {state, failures}) do
    case p.parse.(state, p) do
      %Success{} = success -> {state, success}
      %Failure{fatal: true} = failure -> {state, [failure]}
      %Failure{} = failure -> {state, [failure|failures]}
    end
  end

  defp compose_failures(failures) do
    Enum.reduce(failures, nil, &compose_failures/2)
  end

  defp compose_failures(failure, nil),
                        do: failure
  defp compose_failures(%Failure{rank: n} = failure,
                        %Failure{rank: m})
                        when n > m,
                        do: failure
  defp compose_failures(%Failure{rank: n} = fl,
                        %Failure{rank: n} = fr),
                        do: Failure.compose([fl, fr])
  defp compose_failures(_, failure),
                        do: failure



  parser re(r) do
    fn %State{stream: stream} = state, this ->
      [{from, text}|chunks] = State.chunks_from(state)
      case Regex.run(anchor(r), text, return: :index) do
        [{_, n}] ->
          case Paco.String.seek(text, n, from) do
            {"", _, _, _} when is_pid(stream) ->
              wait_for_more_and_continue(state, this)
            {"", consumed, to, at} ->
              %Success{from: from, to: to, at: at,
                       tail: chunks, result: consumed}
            {tail, consumed, to, at} ->
              %Success{from: from, to: to, at: at,
                       tail: [{at, tail}|chunks], result: consumed}
          end
        [{_, n}|captures] ->
          case Paco.String.seek(text, n, from) do
            {"", _, _, _} when is_pid(stream) ->
              wait_for_more_and_continue(state, this)
            {"", consumed, to, at} ->
              captures = extract_captures(r, captures, text)
              %Success{from: from, to: to, at: at,
                       tail: chunks,
                       result: {consumed, captures}}
            {tail, consumed, to, at} ->
              captures = extract_captures(r, captures, text)
              %Success{from: from, to: to, at: at,
                       tail: [{at, tail}|chunks],
                       result: {consumed, captures}}
          end
        nil when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        nil ->
          %Failure{at: from, tail: [{from, text}|chunks],
                   expected: {:re, r}, stack: Failure.stack(this)}
      end
    end
  end

  defp extract_captures(r, captures, text) do
    case Regex.names(r) do
      [] ->
        captures |> Enum.map(fn({from, len}) -> String.slice(text, from, len) end)
      _ ->
        Regex.named_captures(r, text)
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
    fn %State{stream: stream} = state, this ->
      [{from, text}|chunks] = State.chunks_from(state)
      case Paco.String.consume(text, s, from) do
        {"", _, to, at} ->
          %Success{from: from, to: to, at: at, tail: chunks, result: s}
        {tail, _, to, at} ->
          %Success{from: from, to: to, at: at, tail: [{at, tail}|chunks], result: s}
        {:not_enough, _, _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {_, _, _, _, {n, _, _}} ->
          %Failure{at: from, tail: [{from, text}|chunks], expected: s,
                   stack: Failure.stack(this), rank: n+1}
      end
    end
  end



  parser any, to: any({1, 1})
  parser any(n) when is_integer(n), to: any({n, n})
  parser any(opts) when is_list(opts), to: any(extract_limits(opts))
  parser any({at_least, at_most}) do
    fn %State{stream: stream} = state, this ->
      [{from, text}|chunks] = State.chunks_from(state)
      case Paco.String.consume_any(text, {at_least, at_most}, from) do
        {"", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {"", consumed, to, at} ->
          %Success{from: from, to: to, at: at, tail: chunks, result: consumed}
        {tail, consumed, to, at} ->
          %Success{from: from, to: to, at: at, tail: [{at, tail}|chunks], result: consumed}
        {:not_enough, _, _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {:not_enough, _, _, _, {n, _, _}} ->
          %Failure{at: from, tail: [{from, text}|chunks],
                   expected: {:any, at_least, at_most},
                   rank: n, stack: Failure.stack(this)}
      end
    end
  end



  parser until(p), to: until(p, [])
  parser until(p, opts) when not is_list(p), to: until([p], opts)
  parser until(p, opts) do
    {p, opts} = escape_boundaries(p, opts)
    fn %State{stream: stream} = state, this ->
      [{from, text}|chunks] = State.chunks_from(state)
      case Paco.String.consume_until(text, p, from, opts) do
        {"", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {"", consumed, to, at} ->
          %Success{from: from, to: to, at: at, tail: chunks, result: consumed}
        {tail, consumed, to, at} ->
          %Success{from: from, to: to, at: at, tail: [{at, tail}|chunks], result: consumed}
        {:not_enough, "", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {:not_enough, _, _, _, {n, _, _}} ->
          %Failure{at: from, tail: [{from, text}|chunks],
                   expected: {:until, p}, rank: n,
                   stack: Failure.stack(this)}
      end
    end
  end

  defp escape_boundaries(boundaries, opts) do
    boundaries = List.flatten(boundaries)
    if Keyword.has_key?(opts, :escaped_with) do
      escape = Keyword.get(opts, :escaped_with)
      boundaries = boundaries
                   |> Enum.map(fn({_, _} = escaped) -> escaped
                                 (boundary) -> {boundary, escape}
                               end)
      opts = Keyword.delete(opts, :escaped_with)
    end
    {boundaries, opts}
  end



  parser while(p), to: while(p, {0, :infinity})
  parser while(p, n) when is_integer(n), to: while(p, {n, n})
  parser while(p, opts) when is_list(opts), to: while(p, extract_limits(opts))
  parser while(p, {at_least, at_most}) do
    fn %State{stream: stream} = state, this ->
      [{from, text}|chunks] = State.chunks_from(state)
      case Paco.String.consume_while(text, p, {at_least, at_most}, from) do
        {"", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {"", consumed, to, at} ->
          %Success{from: from, to: to, at: at, tail: chunks, result: consumed}
        {tail, consumed, to, at} ->
          %Success{from: from, to: to, at: at, tail: [{at, tail}|chunks], result: consumed}
        {:not_enough, "", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {:not_enough, _, _, _, {n, _, _}} ->
          %Failure{at: from, tail: [{from, text}|chunks],
                   expected: {:while, p, at_least, at_most},
                   rank: n, stack: Failure.stack(this)}
      end
    end
  end



  parser while_not(p), to: while_not(p, {0, :infinity})
  parser while_not(p, n) when is_integer(n), to: while_not(p, {n, n})
  parser while_not(p, opts) when is_list(opts), to: while_not(p, extract_limits(opts))
  parser while_not(p, {at_least, at_most}) do
    fn %State{stream: stream} = state, this ->
      [{from, text}|chunks] = State.chunks_from(state)
      f = case p do
            chrs when is_binary(p) ->
              expected = Stream.unfold(chrs, &String.next_grapheme/1) |> Enum.to_list
              fn(h) -> not Enum.member?(expected, h) end
            f when is_function(f) ->
              fn(h) -> not f.(h) end
          end
      case Paco.String.consume_while(text, f, {at_least, at_most}, from) do
        {"", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {"", consumed, to, at} ->
          %Success{from: from, to: to, at: at, tail: chunks, result: consumed}
        {tail, consumed, to, at} ->
          %Success{from: from, to: to, at: at, tail: [{at, tail}|chunks], result: consumed}
        {:not_enough, "", _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {:not_enough, _, _, _, {n, _, _}} ->
          %Failure{at: from, tail: [{from, text}|chunks],
                   expected: {:while_not, p, at_least, at_most},
                   rank: n, stack: Failure.stack(this)}
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

  defp wait_for_more_and_continue(%State{stream: stream} = state, this) do
    send(stream, {self, :more})
    receive do
      {:load, more_text} ->
        [{at, text}] = State.chunks_from(state)
        this.parse.(%State{state|chunks: [{at, text <> more_text}]}, this)
      :halted ->
        # The stream is over, switching to a non stream mode is equal to
        # tell the parser to behave knowing that more input will never come
        this.parse.(%State{state|stream: nil}, this)
    end
  end

  defp call_arity_wise(f, result, success, state) do
    {:arity, arity} = :erlang.fun_info(f, :arity)
    case arity do
      1 -> f.(result)
      2 -> f.(result, success)
      3 -> f.(result, success, state)
    end
  end

  defp consumed_any_input?(_, %Success{from: {n, _, _}, at: {m, _, _}}, message) do
    if m > n, do: true, else: {false, message}
  end
end
