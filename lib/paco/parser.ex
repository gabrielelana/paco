defmodule Paco.Parser do
  import Paco.Macro.ParserDefinition

  defstruct id: nil, name: nil, description: nil, parse: nil

  def as(p, description), do: %Paco.Parser{box(p)|description: description}

  def box(%Paco.Parser{} = p), do: p
  def box(%Regex{} = r), do: re(r)
  def box(s) when is_binary(s), do: lit(s)
  def box(nil), do: always(nil)
  def box(t), do: Paco.Parsable.to_parser(t)



  parser cut do
    fn %Paco.State{at: at, text: text}, _ ->
      %Paco.Success{from: at, to: at, at: at, tail: text, cut: true, skip: true}
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
        %Paco.Success{result: result} = success ->
          try do
            call_arity_wise(f, result, success, Paco.State.update(state, success))
          catch
            :error, reason ->
              message = if Exception.exception?(reason) do
                          "exception: #{Exception.message(reason)} %STACK% %AT%"
                        else
                          "error: #{inspect(reason)} %STACK% %AT%"
                        end
              Paco.Failure.at(state, message: message) |> Paco.Failure.stack(this)
          else
            %Paco.Failure{} = failure ->
              failure |> Paco.Failure.stack(this)
            %Paco.Success{} = success ->
              success
            result ->
              %Paco.Success{success|result: result}
          end
        %Paco.Failure{} = failure ->
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

  parser recursive(f) do
    fn state, this ->
      box(f.(this)).parse.(state, this)
    end
  end

  parser eof do
    fn
      %Paco.State{at: at, text: ""}, _ ->
        %Paco.Success{from: at, to: at, at: at, tail: "", result: "", skip: true}
      %Paco.State{at: at, text: text}, _ ->
        %Paco.Failure{at: at, tail: text, rank: at, message: "expected the end of input %AT%"}
    end
  end

  parser peek(box(p)) do
    fn %Paco.State{at: at, text: text} = state, this ->
      case p.parse.(state, p) do
        %Paco.Success{result: result} ->
          %Paco.Success{from: at, to: at, at: at, tail: text, result: result}
        %Paco.Failure{} = failure ->
          failure |> Paco.Failure.stack(this)
      end
    end
  end

  parser separated_by(p, s), to: separated_by(p, s, at_least: 0)
  parser separated_by(p, s, opts) when is_binary(s), to: separated_by(p, lex(s), opts)
  parser separated_by(box(p), box(s), opts),
    as: (import Paco.Transform, only: [flatten_first: 1]
         tail = repeat(sequence_of([skip(s), p]), opts)
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
    fn %Paco.State{at: from} = state, this ->
      case unfold_repeat(p, state, at_most) do
        {n, _, failure} when n < at_least ->
          failure |> Paco.Failure.stack(this)
        {0, _, _} ->
          %Paco.Success{from: from, to: from, at: from, tail: from, result: []}
        {_, successes, _} ->
          results = successes |> Enum.reject(&(&1.skip)) |>  Enum.map(&(&1.result))
          %Paco.Success{List.last(successes)|from: from, result: results}
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
      %Paco.Success{} = success ->
        state = Paco.State.update(state, success)
        unfold_repeat(p, state, n+1, m, [success|successes])
      %Paco.Failure{} = failure ->
        {n, successes |> Enum.reverse, failure}
    end
  end



  parser always(t) do
    fn %Paco.State{at: at, text: text}, _ ->
      %Paco.Success{from: at, to: at, at: at, tail: text, result: t}
    end
  end


  parser fail_with(p, message) do
    fn state, this ->
      case p.parse.(state, p) do
        %Paco.Success{} = success ->
          success
        %Paco.Failure{} = failure ->
          %Paco.Failure{failure|message: message}
          |> Paco.Failure.stack(this)
      end
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



  parser only_if(p, f), to:
    bind(p, fn(result, success, state) ->
              if call_arity_wise(f, result, success, state) do
                success
              else
                message = "#{inspect(result)} is not acceptable %STACK% %AT%"
                %Paco.Failure{at: success.to, tail: state.text,
                              rank: success.to, message: message}
              end
            end)



  parser sequence_of(box_each(ps)) do
    fn %Paco.State{at: from} = state, this ->
      case reduce_sequence_of(ps, state, from) do
        {%Paco.State{at: at, text: text}, to, results} ->
          %Paco.Success{from: from, to: to, at: at,
                        tail: text, result: Enum.reverse(results)}
        %Paco.Failure{} = failure ->
          failure |> Paco.Failure.stack(this)
      end
    end
  end

  defp reduce_sequence_of(ps, state, from) do
    Enum.reduce(ps, {state, from, []}, &reduce_sequence_of/2)
  end

  defp reduce_sequence_of(_, %Paco.Failure{} = failure), do: failure
  defp reduce_sequence_of(p, {state, to, results}) do
    case p.parse.(state, p) do
      %Paco.Success{from: at, to: at, at: at, cut: cut, skip: true} ->
        {%Paco.State{state|cut: cut}, to, results}
      %Paco.Success{from: at, to: at, at: at, cut: cut, result: result} ->
        {%Paco.State{state|cut: cut}, to, [result|results]}
      %Paco.Success{to: to, skip: true} = success ->
        {Paco.State.update(state, success), to, results}
      %Paco.Success{to: to, result: result} = success ->
        {Paco.State.update(state, success), to, [result|results]}
      %Paco.Failure{} = failure ->
        failure
    end
  end



  parser one_of(box_each(ps)) do
    fn %Paco.State{at: at, text: text} = state, this ->
      case reduce_one_of(ps, state) do
        [] ->
          %Paco.Success{from: at, to: at, at: at, tail: text, result: ""}
        %Paco.Success{} = success ->
          success
        failures ->
          farthest_failure(failures) |> Paco.Failure.stack(this)
      end
    end
  end

  defp reduce_one_of(ps, state) do
    Enum.reduce(ps, {state, []}, &reduce_one_of_each/2) |> elem(1)
  end

  defp reduce_one_of_each(_, {_, [%Paco.Failure{fatal: true}]} = failure), do: failure
  defp reduce_one_of_each(_, {_, %Paco.Success{}} = success), do: success
  defp reduce_one_of_each(p, {state, failures}) do
    case p.parse.(state, p) do
      %Paco.Success{} = success -> {state, success}
      %Paco.Failure{fatal: true} = failure -> {state, [failure]}
      %Paco.Failure{} = failure -> {state, [failure|failures]}
    end
  end

  defp farthest_failure(failures) do
    Enum.reduce(failures, nil, &farthest_failure/2)
  end

  defp farthest_failure(failure, nil),
                        do: failure
  defp farthest_failure(%Paco.Failure{rank: n} = failure,
                        %Paco.Failure{rank: m})
                        when n > m,
                        do: failure
  defp farthest_failure(%Paco.Failure{rank: n} = fl,
                        %Paco.Failure{rank: n} = fr),
                        do: Paco.Failure.compose([fl, fr])
  defp farthest_failure(_, failure),
                        do: failure



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
    fn %Paco.State{at: from, text: text, cut: cut, stream: stream} = state, this ->
      case Paco.String.consume(text, s, from) do
        {tail, _, to, at} ->
          %Paco.Success{from: from, to: to, at: at,
                        tail: tail, result: s, cut: cut}
        {:not_enough, _, _, _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {_, _, _, _, {n, _, _}} ->
          %Paco.Failure{at: from, tail: text, expected: s,
                        stack: Paco.Failure.stack(this),
                        rank: n+1, fatal: cut}
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
        {:not_enough, _, _, _, {n, _, _}} ->
          %Paco.Failure{at: from, tail: text, expected: {:any, at_least, at_most},
                        rank: n, stack: Paco.Failure.stack(this)}
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
        {:not_enough, _, _, _, {n, _, _}} ->
          %Paco.Failure{at: from, tail: text, expected: {:until, p},
                        rank: n, stack: Paco.Failure.stack(this)}
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
        {:not_enough, _, _, _, {n, _, _}} ->
          %Paco.Failure{at: from, tail: text, expected: {:while, p, at_least, at_most},
                        rank: n, stack: Paco.Failure.stack(this)}
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

  defp call_arity_wise(f, result, success, state) do
    {:arity, arity} = :erlang.fun_info(f, :arity)
    case arity do
      1 -> f.(result)
      2 -> f.(result, success)
      3 -> f.(result, success, state)
    end
  end
end
