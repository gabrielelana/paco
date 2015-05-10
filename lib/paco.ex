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

  def parse(%Paco.Parser{} = parser, text, opts \\ []) do
    input = Paco.Input.from(text, opts)
    deliver = fn(result, nil)    -> result
                (result, stream) -> send(stream, {self, result})
              end
    deliver.(case parser.parse.(input, parser) do
               %Paco.Failure{} = failure ->
                 {:error, failure}
               %Paco.Success{skip: true} ->
                 {:ok, []}
               %Paco.Success{result: result} ->
                 {:ok, result}
             end,
             input.stream)
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
    GenEvent.add_handler(pid, Paco.Explainer, [])
    GenEvent.notify(pid, {:loaded, text})
    parse(parser, text, collector: pid)
    report = GenEvent.call(pid, Paco.Explainer, :report)
    GenEvent.stop(pid)
    report
  end

  def stream!(enum, %Paco.Parser{} = parser) do
    stream(enum, parser, raise_on_failure: true)
  end

  def stream(enum, %Paco.Parser{} = parser, opts \\ []) do
    cof = Keyword.get(opts, :continue_on_failure, false)
    rof = Keyword.get(opts, :raise_on_failure, false)
    case {cof, rof} do
      {false, false} -> Paco.Stream.from(enum, parser, :halt)
      {_, true} -> Paco.Stream.from(enum, parser, :raise)
      {_, _} -> Paco.Stream.from(enum, parser, :continue)
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
