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
    stream = transform(upstream, configuration, &transform/2)
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














  @doc """
  Transforms an existing stream.

  It expects an accumulator and a function that receives each stream item
  and an accumulator, and must return a tuple containing a new stream
  (often a list) with the new accumulator or a tuple with `:halt` as first
  element and the accumulator as second.

  Note: this function is similar to `Enum.flat_map_reduce/3` except the
  latter returns both the flat list and accumulator, while this one returns
  only the stream.

  ## Examples

  `Stream.transform/3` is useful as it can be used as the basis to implement
  many of the functions defined in this module. For example, we can implement
  `Stream.take(enum, n)` as follows:

      iex> enum = 1..100
      iex> n = 3
      iex> stream = Stream.transform(enum, 0, fn i, acc ->
      ...>   if acc < n, do: {[i], acc + 1}, else: {:halt, acc}
      ...> end)
      iex> Enum.to_list(stream)
      [1, 2, 3]

  """

  # @spec transform(Enumerable.t, acc, fun) :: Enumerable.t when
  #       fun: (element, acc -> {Enumerable.t, acc} | {:halt, acc}),
  #       acc: any

  def transform(enum, acc, reducer) do
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
                              &Enumerable.List.reduce(list, &1, fun))
          {:halt, _user_acc} ->
            next.({:halt, next_acc})
            {:halted, elem(inner_acc, 1)}
          {other, user_acc} ->
            do_enum_transform(user_acc, user, fun, next_acc, next, inner_acc, inner,
                              &Enumerable.reduce(other, &1, inner))
        end
      {reason, _} ->
        {reason, elem(inner_acc, 1)}
    end
  end

  defp do_list_transform(user_acc, user, fun, next_acc, next, inner_acc, inner, reduce) do
    try do
      reduce.(inner_acc)
    catch
      kind, reason ->
        stacktrace = System.stacktrace
        next.({:halt, next_acc})
        :erlang.raise(kind, reason, stacktrace)
    else
      {:done, acc} ->
        do_transform(user_acc, user, fun, next_acc, next, {:cont, acc}, inner)
      {:halted, acc} ->
        next.({:halt, next_acc})
        {:halted, acc}
      {:suspended, acc, c} ->
        {:suspended, acc, &do_list_transform(user_acc, user, fun, next_acc, next, &1, inner, c)}
    end
  end

  defp do_enum_transform(user_acc, user, fun, next_acc, next, {op, inner_acc}, inner, reduce) do
    try do
      reduce.({op, [:outer|inner_acc]})
    catch
      kind, reason ->
        stacktrace = System.stacktrace
        next.({:halt, next_acc})
        :erlang.raise(kind, reason, stacktrace)
    else
      {:halted, [:outer|acc]} ->
        do_transform(user_acc, user, fun, next_acc, next, {:cont, acc}, inner)
      {:halted, [:inner|acc]} ->
        next.({:halt, next_acc})
        {:halted, acc}
      {:done, [_|acc]} ->
        do_transform(user_acc, user, fun, next_acc, next, {:cont, acc}, inner)
      {:suspended, [_|acc], c} ->
        {:suspended, acc, &do_enum_transform(user_acc, user, fun, next_acc, next, &1, inner, c)}
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
