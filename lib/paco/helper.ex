defmodule Paco.Helper do

  # TODO: how to not use attributes with internal parsers?

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

  # TODO: what about we give something else then %Paco.Input?

  defmacro parser({name, _, _} = definition, do: block) do
    quote do
      @paco_parsers unquote(name)
      def unquote(definition) do
        %Paco.Parser{
          name: unquote(name),
          parse: fn %Paco.Input{} = input ->
                   case (unquote(block)) do
                     %Paco.Parser{} = parser -> parser.parse.(input)
                     _ -> raise Error, message: "parser macro do block must return a %Paco.Parser struct"
                   end
                 end}
      end
    end
  end

  # TODO: clause with not nil for a better error message
  # TODO: check if @paco_root_parser is an atom
  # TODO: if not @paco_root_parser then take the last parser

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
