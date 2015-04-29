defmodule Paco.Helper do

  defmacro parser({name, _, _} = definition, do: {:fn, _, _} = block) do
    quote do
      def unquote(definition) do
        %Paco.Parser{
          name: unquote(name),
          parse: unquote(block)
        }
      end
    end
  end

  defmacro parser({name, _, _} = definition, do: block) do
    # TODO: what about we give something else of %Paco.Input?
    quote do
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

end
