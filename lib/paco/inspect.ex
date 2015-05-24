defmodule Paco.Inspect do
  import Inspect.Algebra, except: [surround_many: 5]

  def parser(p, opts, custom_opts \\ []) do
    custom_opts = Keyword.merge([stop_at_level: 3, show_id: false], custom_opts)
    case {Keyword.get(custom_opts, :stop_at_level), p.combine} do
      {0, _} ->
        do_inspect_parser_name(p, custom_opts)
      {_, []} ->
        do_inspect_parser_name(p, custom_opts)
      {n, _} ->
        custom_opts = Keyword.put(custom_opts, :stop_at_level, decrement(n))
        concat [do_inspect_parser_name(p, custom_opts),
                surround_many("(", p.combine, ")", opts,
                              &do_inspect_parser_argument(&1, &2, custom_opts))]
    end
  end

  defp do_inspect_parser_name(%Paco.Parser{id: id, name: name}, custom_opts) do
    if Keyword.get(custom_opts, :show_id) do
      concat([to_string(name), "#", to_string(id)])
    else
      to_string(name)
    end
  end

  # Hopefully most of the following code will be gone as soon as a couple of
  # pull request will be merged in master

  defp do_inspect_parser_argument(%Paco.Parser{} = arg, opts, custom_opts) do
    parser(arg, opts, custom_opts)
  end
  defp do_inspect_parser_argument([], _opts, _custom_opts), do: empty
  defp do_inspect_parser_argument({}, _opts, _custom_opts), do: empty
  defp do_inspect_parser_argument([%Paco.Parser{}|_] = arg, opts, custom_opts) do
    # IO.puts("LIST OF PARSERS #{inspect(arg)}")
    surround_many("[", arg, "]", opts, &do_inspect_parser_argument(&1, &2, custom_opts))
  end
  defp do_inspect_parser_argument(arg, opts, custom_opts) when is_tuple(arg) do
    # IO.puts("TUPLE OF PARSERS #{inspect(arg)}")
    case Tuple.to_list(arg) do
      [%Paco.Parser{}|_] ->
        surround_many("{", arg, "}", opts, &do_inspect_parser_argument(&1, &2, custom_opts))
      _ ->
        to_doc(arg, opts)
    end
  end
  defp do_inspect_parser_argument(arg, opts, custom_opts) when is_map(arg) do
    # IO.puts("MAP OF PARSERS #{inspect(arg)}")
    case Map.to_list(arg) do
      [%Paco.Parser{}|_] ->
        surround_many("%{", arg, "}", opts, &do_inspect_parser_argument(&1, &2, custom_opts))
      _ ->
        to_doc(arg, opts)
    end
  end
  defp do_inspect_parser_argument(%{__struct__: struct} = arg, opts, custom_opts) do
    # IO.puts("STRUCT OF PARSERS #{inspect(arg)}")
    case Map.to_list(Map.delete(arg, :__struct__)) do
      [%Paco.Parser{}|_] ->
        surround_many("%#{inspect(struct)}{", arg, "}", opts,
                      &do_inspect_parser_argument(&1, &2, custom_opts))
      _ ->
        to_doc(arg, opts)
    end
  end
  defp do_inspect_parser_argument(arg, opts, _custom_opts) when is_function(arg) do
    about_fn = :erlang.fun_info(arg)
    if Keyword.get(about_fn, :type) == :external do
      to_doc(arg, opts)
    else
      "fn/#{Keyword.get(about_fn, :arity)}"
    end
  end
  defp do_inspect_parser_argument(arg, opts, _custom_opts) do
    # IO.puts("OTHER ARGUMENT #{inspect(arg)}")
    to_doc(arg, opts)
  end

  defp decrement(:infinity), do: :infinity
  defp decrement(counter), do: counter - 1











  # Patch to Inspect.Algebra.surround_many implementation

  @empty :doc_nil
  @surround_separator ","
  @tail_separator " |"

  defp surround_many(left, docs, right, opts, fun, separator \\ @surround_separator) do
    do_surround_many(left, docs, right, opts.limit, opts, fun, separator)
  end

  defp do_surround_many(left, [], right, _, _opts, _fun, _) do
    concat(left, right)
  end

  defp do_surround_many(left, docs, right, limit, _opts, fun, sep) do
    surround(left, do_surround_many(docs, limit, _opts, fun, sep), right)
  end

  defp do_surround_many(_, 0, _opts, _fun, _sep) do
    "..."
  end

  defp do_surround_many([], _limit, _opts, _fun, _sep), do: @empty
  defp do_surround_many([h|t], limit, opts, fun, sep) do
    limit = decrement(limit)
    case fun.(h, %{opts | limit: limit}) do
      @empty ->
        do_surround_many(t, limit, opts, fun, sep)
      h ->
        case do_surround_many(t, limit, opts, fun, sep) do
          @empty ->
            h
          t ->
            glue(concat(h, sep), t)
        end
    end
  end
end
