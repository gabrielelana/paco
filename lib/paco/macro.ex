defmodule Paco.Macro do

  # parser_ maybe(parser) do ... end
  defmacro parser_(definition, do: {:__block__, _, _} = block) do
    # IO.puts("BLOCK IMPLEMENTATION FOR #{definition |> elem(0)}")
    parser__(definition, do: block)
  end

  # parser_ skip(parser), do: fn %Paco.State{} -> ... end
  defmacro parser_(definition, do: {:fn, _, _} = function) do
    # IO.puts("FN IMPLEMENTATION FOR #{definition |> elem(0)}")
    parser__(definition, do: {:__block__, [], [function]})
  end

  # parser_ surrounded_by(parser, around), do: surrounded_by(parser, around, around)
  defmacro parser_(definition, do: {_, _, _} = expression) do
    # IO.puts("EXPRESSION IMPLEMENTATION FOR #{definition |> elem(0)}")
    quote do
      def unquote(definition), do: unquote(expression)
    end
  end

  defmacro parser_(definition, forward_to: {_, _, _} = parser) do
    # IO.puts("FORWARD IMPLEMENTATION FOR #{definition |> elem(0)}")
    quote do
      def unquote(definition), do: unquote(parser)
    end
  end

  defmacro parser_(definition, as: {_, _, _} = parser) do
    # IO.puts("AS IMPLEMENTATION FOR #{definition |> elem(0)}")
    quote do
      parser_ unquote(definition) do
        parser = unquote(parser)
        fn %Paco.State{collector: collector} = state, this ->
          notify(collector, {:started, Paco.describe(this)})
          case parser.parse.(state, parser) do
            %Paco.Success{from: from, to: to, at: at} = success ->
              notify(collector, {:matched, from, to, at})
              success
            %Paco.Failure{at: at, tail: tail, because: because} ->
              notify(collector, {:failed, at})
              %Paco.Failure{at: at, tail: tail, what: Paco.describe(this), because: because}
          end
        end
      end
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
                           %Paco.Failure{failure|what: unquote(name)}
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
