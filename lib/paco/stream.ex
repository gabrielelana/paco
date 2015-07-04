defmodule Paco.Stream do

  def parse!(upstream, parser, opts \\ []) do
    parse(upstream, parser, Keyword.merge(opts, [on_failure: :raise]))
  end

  def parse(upstream, parser, opts \\ []) do
    parser = Paco.Parser.box(parser)
    opts = case Keyword.get(opts, :on_failure, :hide) do
             :hide -> Keyword.merge([format: :flat, on_failure: :hide, wait_for_more: true], opts)
             :yield -> Keyword.merge([format: :tagged, wait_for_more: true], opts)
             :raise -> Keyword.merge([format: :flat, wait_for_more: true], opts)
           end
    &do_parse(upstream, {start_link(parser, opts), opts}, &1, &2)
  end

  defp do_parse(upstream, configuration, {:suspend, downstream_accumulator}, downstream_reducer) do
    {:suspended, downstream_accumulator, &do_parse(upstream, configuration, &1, downstream_reducer)}
  end
  defp do_parse(_, {running_parser, _}, {:halt, downstream_accumulator}, _) do
    stop(running_parser)
    {:halted, downstream_accumulator}
  end
  defp do_parse(upstream, {running_parser, opts}, downstream_command, downstream_reducer) do
    eos_probe = make_ref
    upstream = upstream
               |> Stream.concat([eos_probe])
               |> transform({running_parser, eos_probe, opts}, &transform_with_parser/2)
    run(upstream, running_parser, downstream_command, downstream_reducer)
  end

  defp start_link(parser, opts) do
    # IO.puts("[STREAM] START PARSER PROCESS")
    running_parser = spawn_link(parse_and_send_back_to(self, parser, opts))
    consume_request_for_more_data_from(running_parser)
    running_parser
  end

  defp transform_with_parser(eos_probe, {running_parser, eos_probe, _} = accumulator) do
    # IO.puts("[STREAM] END OF INPUT")
    send(running_parser, :halted)
    collect_from_parser([], accumulator, true)
  end
  defp transform_with_parser(upstream_element, {running_parser, _, _} = accumulator) do
    # IO.puts("[STREAM] LOAD #{upstream_element} TO PARSER")
    send(running_parser, {:load, upstream_element})
    collect_from_parser([], accumulator, false)
  end

  defp collect_from_parser(successes, {running_parser, _, opts} = accumulator, eos) do
    receive do
      {^running_parser, :more} ->
        # IO.puts("[STREAM] PARSER NEEDS MORE INPUT -> YIELD COLLECTED")
        {successes |> Enum.reverse, accumulator}
      {^running_parser, %Paco.Success{} = success} ->
        # IO.puts("[STREAM] COLLECT SUCCESS: #{inspect(success)}")
        formatted = Paco.Success.format(success, Keyword.get(opts, :format))
        collect_from_parser([formatted|successes], accumulator, eos)
      {^running_parser, %Paco.Failure{}} when eos ->
        # IO.puts("[STREAM] END OF INPUT -> YIELD COLLECTED")
        {successes |> Enum.reverse, accumulator}
      {^running_parser, %Paco.Failure{} = failure} ->
        # IO.puts("[STREAM] FAILURE! #{inspect(failure)}")
        case {Keyword.get(opts, :on_failure), successes} do
          {:hide, []} ->
            {:halt, accumulator}
          {:hide, _} ->
            {:halt, successes, accumulator}
          {:yield, _} ->
            formatted = Paco.Failure.format(failure, Keyword.get(opts, :format))
            {:halt, [formatted|successes] |> Enum.reverse, accumulator}
          {:raise, _} ->
            raise failure
        end
    end
  end

  defp run(stream, running_parser, downstream_command, downstream_reducer) do
    try do
      Enumerable.Function.reduce(stream, downstream_command, downstream_reducer)
    catch
      kind, reason ->
        stacktrace = System.stacktrace
        stop(running_parser)
        :erlang.raise(kind, reason, stacktrace)
    else
      {:suspended, acc, downstream_continuation} ->
        # IO.puts("[STREAM] UPSTRAM IS SUSPENDED")
        {:suspended, acc, &run(stream, running_parser, &1, downstream_continuation)}
      {_, _} = halted_or_done ->
        # IO.puts("[STREAM] UPSTRAM IS #{inspect(halted_or_done)}")
        # We already know that the stream is over because we have a probe at
        # the end of the stream, when transform_with_parser sees the probe it
        # shuts down the parser. Here we don't have to do anything in
        # particular.
        #
        # But this **is** the place to do that kind of things, the probe is an
        # hack, problem is I still need to figure out how it works :-(
        halted_or_done
    end
  end

  defp parse_and_send_back_to(stream, parser, opts) do
    fn ->
      at = Keyword.get(opts, :at, {0, 1, 1})
      opts = [stream: stream, format: :raw, on_failure: :yield,
              wait_for_more: Keyword.get(opts, :wait_for_more)]

      # IO.puts("[PARSER] START")
      Stream.unfold({at, "", :cont},
                    fn {_, _, :halt} ->
                         # IO.puts("[PARSER] HALT!")
                         nil
                       {at, text, :cont} ->
                         # IO.puts("[PARSER] GOING TO PARSE #{inspect(text)}")
                         opts = Keyword.put(opts, :at, at)
                         case Paco.parse(parser, text, opts) do
                           %Paco.Success{from: at, to: at, at: at} ->
                             # IO.puts("[PARSER] FAILURE! DIDN'T CONSUME ANY INPUT")
                             message = "failure! parser didn't consume any input"
                             failure = %Paco.Failure{at: at, tail: text, message: message}
                             {failure, {at, "", :halt}}
                           %Paco.Success{at: at, tail: tail} = success ->
                             # IO.puts("[PARSER] SUCCESS! #{inspect(success)}")
                             {success, {at, tail, :cont}}
                           %Paco.Failure{at: at} = failure ->
                             # IO.puts("[PARSER] FAILURE #{inspect(failure)}")
                             {failure, {at, "", :halt}}
                         end
                    end)
      |> Stream.map(&(send(stream, {self, &1})))
      |> Stream.run
    end
  end

  defp consume_request_for_more_data_from(running_parser) do
    receive do
      {^running_parser, :more} -> :ok
      {^running_parser, result} -> send(self, {running_parser, result})
    end
  end

  defp stop(running_parser) do
    # IO.puts("[STREAM] STOP PARSER PROCESS")
    if Process.alive?(running_parser) do
      send(running_parser, :halted)
      receive do
        {^running_parser, result} -> result
      end
    end
  end












  defp transform(enum, acc, reducer) do
    &do_transform(enum, acc, reducer, &1, &2)
  end

  defp do_transform(enumerables, user_acc, user, inner_acc, fun) do
    inner = &do_transform_each(&1, &2, fun)
    step  = &do_transform_step(&1, &2)
    next  = &Enumerable.reduce(enumerables, &1, step)
    do_transform(user_acc, user, fun, [], next, inner_acc, inner)
  end

  defp do_transform(user_acc, user, fun, next_acc, next, inner_acc, inner) do
    case next.({:cont, next_acc}) do
      {:suspended, [val|next_acc], next} ->
        try do
          user.(val, user_acc)
        catch
          kind, reason ->
            stacktrace = System.stacktrace
            next.({:halt, next_acc})
            :erlang.raise(kind, reason, stacktrace)
        else
          {[], user_acc} ->
            do_transform(user_acc, user, fun, next_acc, next, inner_acc, inner)
          {list, user_acc} when is_list(list) ->
            do_list_transform(user_acc, user, fun, next_acc, next, inner_acc, inner,
                              &Enumerable.List.reduce(list, &1, fun), :cont)
          {:halt, list, _user_acc} when is_list(list) ->
            do_list_transform(user_acc, user, fun, next_acc, next, inner_acc, inner,
                              &Enumerable.List.reduce(list, &1, fun), :halt)
          {:halt, _user_acc} ->
            next.({:halt, next_acc})
            {:halted, elem(inner_acc, 1)}
        end
      {reason, _} ->
        {reason, elem(inner_acc, 1)}
    end
  end

  defp do_list_transform(user_acc, user, fun, next_acc, next, inner_acc, inner, reduce, command) do
    try do
      reduce.(inner_acc)
    catch
      kind, reason ->
        stacktrace = System.stacktrace
        next.({:halt, next_acc})
        :erlang.raise(kind, reason, stacktrace)
    else
      {:done, acc} ->
        case command do
          :halt ->
            next.({:halt, next_acc})
            {:halted, acc}
          :cont ->
            do_transform(user_acc, user, fun, next_acc, next, {:cont, acc}, inner)
        end
      {:halted, acc} ->
        next.({:halt, next_acc})
        {:halted, acc}
      {:suspended, acc, continuation} ->
        continuation = &do_list_transform(user_acc, user, fun, next_acc,
                                          next, &1, inner, continuation, command)
        {:suspended, acc, continuation}
    end
  end

  defp do_transform_each(x, [:outer|acc], f) do
    case f.(x, acc) do
      {:halt, res} -> {:halt, [:inner|res]}
      {op, res}    -> {op, [:outer|res]}
    end
  end

  defp do_transform_step(x, acc) do
    {:suspend, [x|acc]}
  end
end
