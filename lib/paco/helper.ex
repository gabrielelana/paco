defmodule Paco.Helper do

  defmacro parser_(definition, do: {:__block__, [], _} = block) do
    parser__(definition, do: block)
  end
  defmacro parser_(definition, do: {:fn, _, _} = expression) do
    parser__(definition, do: {:__block__, [], [expression]})
  end
  defmacro parser_(definition, do: {_, _, _} = expression) do
    quote do
      def unquote(definition), do: unquote(expression)
    end
  end


  defp parser__({name, _, arguments} = definition, do: block) do
    quote do
      def unquote(definition) do
        %Paco.Parser{
          name: to_string(unquote(name)),
          combine: unquote(normalize_parser_arguments(arguments)),
          parse: unquote(block)
        }
      end
    end
  end


  defmacro parser({name, _, arguments} = definition, do: block) do
    quote do
      @paco_parsers unquote(name)
      def unquote(definition) do
        %Paco.Parser{
          name: to_string(unquote(name)),
          combine: unquote(normalize_parser_arguments(arguments)),
          parse: fn %Paco.Input{} = input, _this ->
                   case (unquote(block)) do
                     %Paco.Parser{} = parser ->
                       case parser.parse.(input, parser) do
                         %Paco.Success{} = success ->
                           success
                         %Paco.Failure{} = failure ->
                           %Paco.Failure{failure | what: unquote(name)}
                       end
                     _ ->
                       raise RuntimeError, message: "A parser must return a %Paco.Parser"
                   end
                 end}
      end
    end
  end

  defp normalize_parser_arguments([parsers | _options]), do: parsers
  defp normalize_parser_arguments(nil), do: []

  # root parser aaa do ...
  defmacro root({:parser, _, [{name, _, nil} = definition]}, do: block) do
    quote do
      @paco_root_parser unquote(name)
      parser unquote(definition) do
        unquote(block)
      end
    end
  end

  # root parser aaa, do: ...
  defmacro root({:parser, _, [{name, _, nil} = definition, [do: block]]}) do
    quote do
      @paco_root_parser unquote(name)
      parser unquote(definition) do
        unquote(block)
      end
    end
  end

  # root aaa
  defmacro root({name, _, _}) do
    quote do
      @paco_root_parser unquote(name)
    end
  end
end
