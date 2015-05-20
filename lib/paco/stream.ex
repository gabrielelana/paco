defmodule Paco.Stream do

  def parse!(upstream, %Paco.Parser{} = parser, opts \\ []) do
    parse(upstream, parser, Keyword.merge(opts, [on_failure: :raise]))
  end

  def parse(upstream, %Paco.Parser{} = parser, opts \\ []) do
    opts = case Keyword.get(opts, :on_failure, :halt) do
             :halt -> Keyword.merge([format: :flat, on_failure: :halt, wait_for_more: true], opts)
             :yield -> Keyword.merge([format: :tagged, wait_for_more: true], opts)
             :raise -> Keyword.merge([format: :flat, wait_for_more: true], opts)
           end
    &do_parse(upstream, {start_link(parser, opts), parser, opts}, &1, &2)
  end

  defp do_parse(upstream, configuration, {:suspend, downstream_accumulator}, downstream_reducer) do
    {:suspended, downstream_accumulator, &do_parse(upstream, configuration, &1, downstream_reducer)}
  end
  defp do_parse(_, {running_parser, _, _}, {:halt, downstream_accumulator}, _) do
    stop(running_parser)
    {:halted, downstream_accumulator}
  end
  defp do_parse(upstream, {running_parser, _, _} = configuration, downstream_command, downstream_reducer) do
    stream = Stream.transform(upstream, configuration, &transform/2)
    run(stream, running_parser, downstream_command, downstream_reducer)
  end

  defp start_link(parser, opts) do
    # IO.puts("START PARSER PROCESS")
    running_parser = spawn_link(parse_and_send_back_to(self, parser, opts))
    consume_request_for_more_data_from(running_parser)
    running_parser
  end

  defp transform(upstream_element, {running_parser, parser, opts}) do
    # IO.puts("LOAD #{upstream_element} TO #{inspect(running_parser)}")
    send(running_parser, {:load, upstream_element})
    receive do
      {^running_parser, :more} ->
        # IO.puts("PARSER NEEDS MORE INPUT")
        {[], {running_parser, parser, opts}}
      {^running_parser, %Paco.Success{from: x, to: x, at: x}} ->
        # IO.puts("FAILURE! DIDN'T CONSUME ANY INPUT")
        failure = %Paco.Failure{at: x, what: Paco.describe(parser), because: "^didn't consume any input"}
        {:halt, Paco.Failure.format(failure, Keyword.get(opts, :format))}
      {^running_parser, %Paco.Success{} = success} ->
        # IO.puts("SUCCESS! #{inspect(success)}")
        formatted = Paco.Success.format(success, Keyword.get(opts, :format))
        {[formatted], {start_link(parser, opts), parser, opts}}
      {^running_parser, %Paco.Failure{} = failure} ->
        # IO.puts("FAILURE! #{inspect(failure)}")
        case Keyword.get(opts, :on_failure) do
          :halt ->
            {:halt, Paco.Failure.format(failure, Keyword.get(opts, :format))}
          :yield ->
            formatted = Paco.Failure.format(failure, Keyword.get(opts, :format))
            {[formatted], {start_link(parser, opts), parser, opts}}
          :raise ->
            raise failure
        end
    end
  end

  defp run(stream, running_parser, downstream_command, downstream_reducer) do
    try do
      Enumerable.reduce(stream, downstream_command, downstream_reducer)
    catch
      kind, reason ->
        stacktrace = System.stacktrace
        stop(running_parser)
        :erlang.raise(kind, reason, stacktrace)
    else
      {:suspended, acc, downstream_continuation} ->
        {:suspended, acc, &run(stream, running_parser, &1, downstream_continuation)}
      {_, _} = halted_or_done ->
        # IO.puts("UPSTRAM IS #{inspect(halted_or_done)}")
        stop(running_parser)
        halted_or_done
    end
  end

  defp stop(running_parser) do
    # IO.puts("STOP PARSER PROCESS")
    if Process.alive?(running_parser) do
      send(running_parser, :halt)
      receive do
        {^running_parser, result} -> result
      end
    end
  end

  defp parse_and_send_back_to(stream, parser, opts) do
    fn ->
      opts = [stream: stream, format: :raw, on_failure: :yield,
              wait_for_more: Keyword.get(opts, :wait_for_more)]
      send(stream, {self, Paco.parse(parser, "", opts)})
    end
  end

  defp consume_request_for_more_data_from(running_parser) do
    receive do
      {^running_parser, :more} -> :ok
    end
  end
end
