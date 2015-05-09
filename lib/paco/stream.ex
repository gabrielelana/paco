defmodule Paco.Stream do

  def from(upstream, %Paco.Parser{} = parser) do
    &parse(upstream, start_link(parser), &1, &2)
  end

  defp parse(upstream, parser, {:suspend, downstream_accumulator}, downstream_reducer) do
    {:suspended, downstream_accumulator, &parse(upstream, parser, &1, downstream_reducer)}
  end
  defp parse(_upstream, parser, {:halt, downstream_accumulator}, _downstream_reducer) do
    stop(parser)
    {:halted, downstream_accumulator}
  end
  defp parse(upstream, parser, downstream_command, downstream_reducer) do
    stream = Stream.transform(upstream, parser, &transform/2)
    run(stream, parser, downstream_command, downstream_reducer)
  end

  defp start_link(parser) do
    # IO.puts("START PARSER PROCESS")
    pid = spawn_link(Paco, :parse, [parser, "", [stream: self]])
    # TODO: extract consume_request_for_more_input
    receive do
      {^pid, :more} ->
        # IO.puts("PARSER NEEDS MORE INPUT")
        :ok
    end
    pid
  end

  defp transform(upstream_element, parser) do
    # IO.puts("LOAD #{upstream_element} TO #{inspect(parser)}")
    # {[upstream_element], parser}
    send(parser, {:load, upstream_element})
    receive do
      {^parser, :more} ->
        # IO.puts("PARSER NEEDS MORE INPUT")
        {[], parser}
      {^parser, {:ok, parsed}} ->
        # IO.puts("PARSED! #{inspect(parsed)}")
        # TODO: restart the parser, you will need the parser beside the parser process
        {[parsed], parser}
      {^parser, {:error, failure}} ->
        # IO.puts("FAILURE! #{inspect(failure)}")
        # TODO: if Paco.stream, restart the parser, you will need the parser beside the parser process
        {[failure], parser}
        # TODO: if Paco.stream!, {:halt, nil}
    end
  end

  defp run(stream, parser, downstream_command, downstream_reducer) do
    try do
      Enumerable.reduce(stream, downstream_command, downstream_reducer)
    catch
      kind, reason ->
        stacktrace = System.stacktrace
        stop(parser)
        :erlang.raise(kind, reason, stacktrace)
    else
      {:suspended, acc, downstream_continuation} ->
        {:suspended, acc, &run(stream, parser, &1, downstream_continuation)}
      {_, _} = halted_or_done ->
        # IO.puts("UPSTRAM IS #{inspect(halted_or_done)}")
        stop(parser)
        halted_or_done
    end
  end

  defp stop(parser) do
    # IO.puts("STOP PARSER PROCESS")
    if Process.alive?(parser) do
      send(parser, :halt)
      receive do
        {^parser, {:error, failure}} -> failure
      end
    end
  end
end
