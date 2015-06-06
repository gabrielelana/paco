defmodule Paco.Macro.ParserDefinition do

  defmacro parser(definition, do: block) do
    define_parser(definition, do: block)
  end

  defmacro parser(definition, to: {_, _, _} = parser) do
    quote do
      def unquote(definition), do: unquote(parser)
    end
  end

  defmacro parser(definition, as: {_, _, _} = parser) do
    quote do
      parser unquote(definition) do
        parser = unquote(parser)
        fn %Paco.State{} = state, this ->
          case parser.parse.(state, parser) do
            %Paco.Success{} = success ->
              success
            %Paco.Failure{} = failure ->
              %Paco.Failure{failure|what: Paco.describe(this), because: failure.because}
          end
        end
      end
    end
  end

  defp define_parser({:when, _, [{name, _, args}, guards]}, do: block) do
    {args, boxing} = Paco.Macro.ParserDefinition.extract_boxing(args)
    quote do
      def unquote(name)(unquote_splicing(args)) when unquote(guards) do
        unquote_splicing(boxing)
        %Paco.Parser{
          id: Paco.Macro.ParserDefinition.id,
          name: to_string(unquote(name)),
          combine: unquote(Paco.Macro.ParserDefinition.normalize(args)),
          parse: unquote(block)
        }
      end
    end
  end

  defp define_parser({name, _, args}, do: block) do
    {args, boxing} = Paco.Macro.ParserDefinition.extract_boxing(args)
    quote do
      def unquote(name)(unquote_splicing(args)) do
        unquote_splicing(boxing)
        %Paco.Parser{
          id: Paco.Macro.ParserDefinition.id,
          name: to_string(unquote(name)),
          combine: unquote(Paco.Macro.ParserDefinition.normalize(args)),
          parse: unquote(block)
        }
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

  def extract_boxing(nil), do: {[], []}
  def extract_boxing(args), do: extract_boxing(args, {[], []})

  def extract_boxing([], {args, boxing}), do: {Enum.reverse(args), Enum.reverse(boxing)}
  def extract_boxing([{:box, _, [arg]}|tail], {args, boxing}) do
    box = quote do
      unquote(arg) = Paco.Parser.box(unquote(arg))
    end
    extract_boxing(tail, {[arg|args], [box|boxing]})
  end
  def extract_boxing([{:box_each, _, [arg]}|tail], {args, boxing}) do
    box = quote do
      unquote(arg) = Enum.map(unquote(arg), &Paco.Parser.box/1)
    end
    extract_boxing(tail, {[arg|args], [box|boxing]})
  end
  def extract_boxing([arg|tail], {args, boxing}) do
    extract_boxing(tail, {[arg|args], boxing})
  end
end


defmodule Paco.Macro.ParserModuleDefinition do
  defmacro parser(definition, do: block) do
    name = extract_name(definition)
    quote do
      require Paco.Macro.ParserDefinition
      @paco_parsers unquote(name)
      Paco.Macro.ParserDefinition.parser unquote(definition) do
        fn %Paco.State{} = state, _this ->
          case (unquote(block)) do
            %Paco.Parser{} = parser ->
              case parser.parse.(state, parser) do
                %Paco.Success{} = success ->
                  success
                %Paco.Failure{} = failure ->
                  %Paco.Failure{failure|what: unquote(name)}
              end
            _ ->
              raise RuntimeError, message: "Expected a %Paco.Parser"
          end
        end
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

  defp extract_name(definition) do
    case definition do
      {:when, _, [{name, _, _}|_]} -> name
      {name, _, _} -> name
    end
  end
end
