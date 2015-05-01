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

  def parse(%Paco.Parser{} = parser, text) do
    case parser.parse.(Paco.Input.from(text), parser) do
      %Paco.Failure{} = failure ->
        {:error, failure}
      %Paco.Success{skip: true} ->
        {:ok, []}
      %Paco.Success{result: result} ->
        {:ok, result}
    end
  end

  def parse!(%Paco.Parser{} = parser, text) do
    case parse(parser, text) do
      {:ok, result} ->
        result
      {:error, failure} ->
        raise Error, message: Paco.Failure.format(failure)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    root_parser = pick_root_parser_between(
      Module.get_attribute(env.module, :paco_root_parser),
      Module.get_attribute(env.module, :paco_parsers) |> Enum.reverse
    )
    quote do
      def parse(s), do: Paco.parse(apply(__MODULE__, unquote(root_parser), []), s)
      def parse!(s), do: Paco.parse!(apply(__MODULE__, unquote(root_parser), []), s)
    end
  end

  defp pick_root_parser_between(nil, []), do: nil
  defp pick_root_parser_between(nil, [pn]), do: pn
  defp pick_root_parser_between(nil, [_|pns]), do: pick_root_parser_between(nil, pns)
  defp pick_root_parser_between(pn, _) when is_atom(pn), do: pn
  defp pick_root_parser_between(pn, _) when is_binary(pn), do: String.to_atom(pn)
end
