defmodule Paco do

  defmacro __using__(_) do
    quote do
      import Paco.Helper
      import Paco.Parser

      Module.register_attribute(__MODULE__, :paco_root_parser, accumulate: false)
      Module.register_attribute(__MODULE__, :paco_parsers, accumulate: true)

      @before_compile Paco
    end
  end

  defp format(%Paco.Success{} = success, how), do: Paco.Success.format(success, how)
  defp format(%Paco.Failure{} = failure, how), do: Paco.Failure.format(failure, how)

  defp deliver(result, nil), do: result
  defp deliver(result, stream) when is_pid(stream), do: send(stream, {self, result})

  def parse(%Paco.Parser{} = parser, text, opts \\ []) do
    parser.parse.(Paco.Input.from(text, opts), parser)
      |> format(Keyword.get(opts, :format, :flat_tagged))
      |> deliver(Keyword.get(opts, :stream, nil))
  end

  def parse!(%Paco.Parser{} = parser, text, opts \\ []) do
    case parse(parser, text, opts) do
      {:ok, result} ->
        result
      {:error, failure} ->
        raise Error, message: Paco.Failure.format(failure)
    end
  end

  def explain(%Paco.Parser{} = parser, text) do
    {:ok, pid} = GenEvent.start_link()
    try do
      GenEvent.add_handler(pid, Paco.Explainer, [])
      parse(parser, text, collector: pid)
      GenEvent.call(pid, Paco.Explainer, :report)
    after
      GenEvent.stop(pid)
    end
  end

  def describe("\n"), do: "\\n"
  def describe(string) when is_binary(string), do: string
  def describe(%Regex{} = r), do: inspect(r)
  def describe(%Paco.Parser{name: name, combine: []}), do: name
  def describe(%Paco.Parser{name: name, combine: parsers}) when is_list(parsers) do
    parsers = parsers |> Enum.map(&describe/1) |> Enum.join(", ")
    "#{name}([#{parsers}])"
  end
  def describe(%Paco.Parser{name: name, combine: parser}) do
    "#{name}(#{describe(parser)})"
  end


  @doc false
  defmacro __before_compile__(env) do
    root_parser = pick_root_parser_between(
      Module.get_attribute(env.module, :paco_root_parser),
      Module.get_attribute(env.module, :paco_parsers) |> Enum.reverse
    )
    quote do
      def parse(s, opts \\ []), do: Paco.parse(apply(__MODULE__, unquote(root_parser), []), s, opts)
      def parse!(s, opts \\ []), do: Paco.parse!(apply(__MODULE__, unquote(root_parser), []), s, opts)
    end
  end

  defp pick_root_parser_between(nil, []), do: nil
  defp pick_root_parser_between(nil, [pn]), do: pn
  defp pick_root_parser_between(nil, [_|pns]), do: pick_root_parser_between(nil, pns)
  defp pick_root_parser_between(pn, _) when is_atom(pn), do: pn
  defp pick_root_parser_between(pn, _) when is_binary(pn), do: String.to_atom(pn)
end
