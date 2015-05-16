defmodule Paco.Macro do

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

  defp parser__({name, _, args} = definition, do: block) do
    quote do
      def unquote(definition) do
        %Paco.Parser{
          id: id,
          name: to_string(unquote(name)),
          combine: unquote(normalize(args)),
          parse: unquote(block)
        }
      end
    end
  end

  defmacro parser({name, _, args} = definition, do: block) do
    quote do
      @paco_parsers unquote(name)
      def unquote(definition) do
        %Paco.Parser{
          id: id,
          name: to_string(unquote(name)),
          combine: unquote(normalize(args)),
          parse: fn %Paco.State{} = state, _this ->
                   case (unquote(block)) do
                     %Paco.Parser{} = parser ->
                       case parser.parse.(state, parser) do
                         %Paco.Success{} = success ->
                           success
                         %Paco.Failure{} = failure ->
                           %Paco.Failure{failure | what: unquote(name)}
                       end
                     _ ->
                       raise RuntimeError, message: "Expected a %Paco.Parser"
                   end
                 end}
      end
    end
  end

  def id do
    id = Process.get(:paco, 1)
    Process.put(:paco, id + 1)
    id
  end

  def normalize(nil), do: []
  def normalize(args) do
    args |> Enum.map(fn({:\\, _, [arg, _]}) -> arg; a -> a end)
  end

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
