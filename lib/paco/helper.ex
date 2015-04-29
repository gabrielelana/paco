defmodule Paco.Helper do

  defmacro parser({name, _, _} = definition, do: {:fn, _, _} = block) do
    quote do
      @paco_parsers unquote(name)
      def unquote(definition) do
        %Paco.Parser{
          name: unquote(name),
          parse: unquote(block)
        }
      end
    end
  end

  defmacro parser({name, _, _} = definition, do: block) do
    quote do
      @paco_parsers unquote(name)
      def unquote(definition) do
        %Paco.Parser{
          name: unquote(name),
          parse: fn %Paco.Input{} = input ->
                   case (unquote(block)) do
                     %Paco.Parser{} = parser -> parser.parse.(input)
                     _ -> raise Error, message: "A parser must return a %Paco.Parser"
                   end
                 end}
      end
    end
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
