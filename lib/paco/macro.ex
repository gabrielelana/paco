defmodule Paco.Macro.ParserDefinition do
  # parser_ maybe(parser) do ... end
  defmacro parser(definition, do: {:__block__, _, _} = block) do
    define_parser(definition, do: block)
  end

  # parser_ skip(parser), do: fn %Paco.State{} -> ... end
  defmacro parser(definition, do: {:fn, _, _} = function) do
    define_parser(definition, do: {:__block__, [], [function]})
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
          Paco.Collector.notify_started(this, state)
          case parser.parse.(state, parser) do
            %Paco.Success{} = success ->
              success
            %Paco.Failure{} = failure ->
              %Paco.Failure{failure|what: Paco.describe(this), because: failure.because}
          end
          |> Paco.Collector.notify_ended(state)
        end
      end
    end
  end

  defp define_parser({:when, _, [{name, _, args}, guards]}, do: block) do
    quote do
      def unquote(name)(unquote_splicing(args)) when unquote(guards) do
        %Paco.Parser{
          id: Paco.Macro.ParserDefinition.id,
          name: to_string(unquote(name)),
          combine: unquote(Paco.Macro.ParserDefinition.normalize(args)),
          parse: unquote(block)
        }
      end
    end
  end

  defp define_parser({name, _, args} = definition, do: block) do
    quote do
      def unquote(definition) do
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
