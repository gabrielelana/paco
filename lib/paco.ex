defmodule Paco do

  def parse!(%Paco.Parser{} = parser, text, opts \\ []) do
    parse(parser, text, Keyword.merge(opts, [on_failure: :raise]))
  end

  def parse(%Paco.Parser{} = parser, text, opts \\ []) do
    parser.parse.(Paco.State.from(text, opts), parser)
    |> handle_failure(Keyword.get(opts, :on_failure, :yield))
    |> format(Keyword.get(opts, :format, :tagged))
  end

  def parse_all!(%Paco.Parser{} = parser, text, opts \\ []) do
    parse_all(parser, text, Keyword.merge(opts, [on_failure: :raise]))
  end

  def parse_all(%Paco.Parser{} = parser, text, opts \\ []) do
    at = Keyword.get(opts, :at, {0, 1, 1})
    on_failure = Keyword.get(opts, :on_failure, :yield)
    wanted_format = Keyword.get(opts, :format, :tagged)
    opts = Keyword.put(opts, :format, :raw)
    Stream.unfold({at, text}, fn {_, ""} -> nil
                                 {at, text} ->
                                   opts = Keyword.put(opts, :at, at)
                                   case parse(parser, text, opts) do
                                     %Paco.Success{from: at, to: at, at: at} ->
                                       failure = %Paco.Failure{at: at,
                                                               tail: text,
                                                               what: describe(parser),
                                                               because: "didn't consume any input"}
                                       {failure, {at, ""}}
                                     %Paco.Success{at: at, tail: tail} = success ->
                                       {success, {at, tail}}
                                     %Paco.Failure{at: at} = failure ->
                                       {failure, {at, ""}}
                                   end
                              end)
    |> Enum.map(&handle_failure(&1, on_failure))
    |> Enum.map(&format(&1, wanted_format))
  end

  def describe(%Paco.Parser{} = p), do: inspect(p)

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

  @doc false
  defmacro __using__(_) do
    quote do
      import Paco.Macro
      import Paco.Parser

      Module.register_attribute(__MODULE__, :paco_root_parser, accumulate: false)
      Module.register_attribute(__MODULE__, :paco_parsers, accumulate: true)

      @before_compile Paco
    end
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

  defp format(%Paco.Success{} = success, how), do: Paco.Success.format(success, how)
  defp format(%Paco.Failure{} = failure, how), do: Paco.Failure.format(failure, how)

  defp handle_failure(%Paco.Failure{} = failure, :raise), do: raise failure
  defp handle_failure(result, _), do: result
end
