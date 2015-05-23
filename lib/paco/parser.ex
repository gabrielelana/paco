defmodule Paco.Parser do
  import Paco.Macro

  defstruct id: nil, name: nil, combine: nil, parse: nil

  def from(%Paco.Parser{} = p), do: p
  def from(%Regex{} = r), do: re(r)

  defp notify(nil, _what), do: :ok
  defp notify(collector, what), do: GenEvent.notify(collector, what)

  parser_ whitespace, as: while(&Paco.String.whitespace?/1, 1)
  parser_ whitespaces, as: while(&Paco.String.whitespace?/1, {:gte, 1})

  parser_ lex(s), as: lit(s) |> surrounded_by(maybe(whitespaces))
  # parser_ lex(s), as: sequence_of([skip(while(&Paco.String.whitespace?/1, {0, :infinity})),
  #                                  lit(s),
  #                                  skip(while(&Paco.String.whitespace?/1, {0, :infinity}))])

  parser_ surrounded_by(parser, around), do: surrounded_by(parser, around, around)
  # parser_ surrounded_by(parser, left, right),
  #   as: sequence_of([skip(left), parser, skip(right)]) |> bind(fn [r] -> r end)
  parser_ surrounded_by(parser, left, right) do
    parser = sequence_of([skip(left), parser, skip(right)])
    fn %Paco.State{collector: collector} = state, this ->
      notify(collector, {:started, Paco.describe(this)})
      case parser.parse.(state, parser) do
        %Paco.Success{from: from, to: to, at: at, result: [result]} = success ->
          notify(collector, {:matched, from, to, at})
          %Paco.Success{success|result: result}
        %Paco.Failure{at: at, tail: tail, because: because} ->
          notify(collector, {:failed, at})
          %Paco.Failure{at: at, tail: tail, what: Paco.describe(this), because: because}
      end
    end
  end

  parser_ maybe(%Paco.Parser{} = parser, opts \\ []) do
    has_default = Keyword.has_key?(opts, :default)
    fn %Paco.State{collector: collector} = state, this ->
      notify(collector, {:started, Paco.describe(this)})
      case parser.parse.(state, parser) do
        %Paco.Success{from: from, to: to, at: at} = success ->
          notify(collector, {:matched, from, to, at})
          success
        %Paco.Failure{at: at, tail: tail} when has_default ->
          notify(collector, {:matched, at, at, at})
          %Paco.Success{from: at, to: at, at: at, tail: tail, result: Keyword.get(opts, :default)}
        %Paco.Failure{at: at, tail: tail} ->
          notify(collector, {:matched, at, at, at})
          %Paco.Success{from: at, to: at, at: at, tail: tail, skip: true}
      end
    end
  end

  parser_ skip(%Paco.Parser{} = parser) do
    fn %Paco.State{collector: collector} = state, this ->
      notify(collector, {:started, Paco.describe(this)})
      case parser.parse.(state, parser) do
        %Paco.Success{from: from, to: to, at: at} = success ->
          notify(collector, {:matched, from, to, at})
          %Paco.Success{success|skip: true}
        %Paco.Failure{at: at} = failure ->
          notify(collector, {:failed, at})
          failure
      end
    end
  end

  parser_ sequence_of([]) do
    raise ArgumentError, message: "Must give at least one parser to sequence_of combinator"
  end
  parser_ sequence_of(parsers) do
    fn %Paco.State{at: from, text: text, collector: collector} = state, this ->
      notify(collector, {:started, Paco.describe(this)})
      result = Enum.reduce(parsers, {state, from, []},
                           fn
                             (%Paco.Parser{} = parser, {state, _, results}) ->
                               case parser.parse.(state, parser) do
                                 %Paco.Success{to: to, at: at, tail: tail, skip: true} ->
                                   {%Paco.State{state|at: at, text: tail}, to, results}
                                 %Paco.Success{to: to, at: at, tail: tail, result: result} ->
                                   {%Paco.State{state|at: at, text: tail}, to, [result|results]}
                                 %Paco.Failure{} = failure ->
                                   failure
                               end
                             (_, %Paco.Failure{} = failure) ->
                               failure
                           end)

      case result do
        {%Paco.State{at: at, text: text}, to, results} ->
          notify(collector, {:matched, from, to, at})
          %Paco.Success{from: from, to: to, at: at, tail: text, result: Enum.reverse(results)}
        %Paco.Failure{} = failure ->
          notify(collector, {:failed, from})
          %Paco.Failure{at: from, tail: text, what: Paco.describe(this), because: failure}
      end
    end
  end

  parser_ one_of([parser]), do: parser
  parser_ one_of([]) do
    raise ArgumentError, message: "Must give at least one parser to one_of combinator"
  end
  parser_ one_of(parsers) do
    fn %Paco.State{at: from, text: text, collector: collector} = state, this ->
      notify(collector, {:started, Paco.describe(this)})
      result = Enum.reduce(parsers, [],
                           fn
                             (_, %Paco.Success{} = success) ->
                               success
                             (%Paco.Parser{} = parser, failures) ->
                               case parser.parse.(state, parser) do
                                 %Paco.Success{} = success ->
                                   success
                                 %Paco.Failure{} = failure ->
                                   [failure|failures]
                               end
                           end)

      case result do
        %Paco.Success{from: from, to: to, at: at} = success ->
          notify(collector, {:matched, from, to, at})
          success
        _ ->
          notify(collector, {:failed, from})
          %Paco.Failure{at: from, tail: text, what: Paco.describe(this)}
      end
    end
  end

  parser_ re(r) do
    fn %Paco.State{at: from, text: text, collector: collector, stream: stream} = state, this ->
      description = Paco.describe(this)
      case Regex.run(anchor(r), text, return: :index) do
        [{_, len}] ->
          case Paco.String.seek(text, from, len) do
            {_, "", _, _} when is_pid(stream) ->
              wait_for_more_and_continue(state, this)
            {s, tail, to, at} ->
              notify(collector, {:started, description})
              notify(collector, {:matched, from, to, at})
              %Paco.Success{from: from, to: to, at: at, tail: tail, result: s}
          end
        [{_, len}|captures] ->
          case Paco.String.seek(text, from, len) do
            {_, "", _, _} when is_pid(stream) ->
              wait_for_more_and_continue(state, this)
            {s, tail, to, at} ->
              captures = case Regex.names(r) do
                [] -> captures |> Enum.map(fn({from, len}) -> String.slice(text, from, len) end)
                _ -> [Regex.named_captures(r, text)]
              end
              notify(collector, {:started, description})
              notify(collector, {:matched, from, to, at})
              %Paco.Success{from: from, to: to, at: at, tail: tail, result: [s|captures]}
          end
        nil when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        nil ->
          notify(collector, {:started, description})
          notify(collector, {:failed, from})
          %Paco.Failure{at: from, tail: text, what: description}
      end
    end
  end

  parser_ lit(s) do
    fn %Paco.State{at: from, text: text, collector: collector, stream: stream} = state, this ->
      description = Paco.describe(this)
      case Paco.String.consume(text, s, from) do
        {tail, to, at} ->
          notify(collector, {:started, description})
          notify(collector, {:matched, from, to, at})
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: s}
        :end_of_input when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        _ ->
          notify(collector, {:started, description})
          notify(collector, {:failed, from})
          %Paco.Failure{at: from, tail: text, what: description}
      end
    end
  end

  parser_ any(n \\ 1) do
    fn %Paco.State{at: from, text: text, collector: collector, stream: stream} = state, this ->
      description = Paco.describe(this)
      case Paco.String.consume_any(text, n, from) do
        {consumed, tail, to, at} ->
          notify(collector, {:started, description})
          notify(collector, {:matched, from, to, at})
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: consumed}
        :end_of_input when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        :end_of_input ->
          notify(collector, {:started, description})
          notify(collector, {:failed, from})
          %Paco.Failure{at: from, tail: text, what: description,
                        because: "reached the end of input"}
      end
    end
  end

  parser_ until(p, opts \\ []) do
    fn %Paco.State{at: from, text: text, collector: collector, stream: stream} = state, this ->
      description = Paco.describe(this)
      case Paco.String.consume_until(text, p, from) do
        {_, "", _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {consumed, tail, to, at} ->
          notify(collector, {:started, description})
          notify(collector, {:matched, from, to, at})
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: consumed}
        _ ->
          notify(collector, {:started, description})
          notify(collector, {:failed, from})
          %Paco.Failure{at: from, tail: text, what: description}
      end
    end
  end

  parser_ while(p), do: while(p, {0, :infinity})
  parser_ while(p, n) when is_integer(n), do: while(p, {n, n})
  parser_ while(p, {:gte, n}) when is_integer(n), do: while(p, {n, :infinity})
  parser_ while(p, {:gt, n}) when is_integer(n), do: while(p, {n + 1, :infinity})
  parser_ while(p, {:lte, m}) when is_integer(m), do: while(p, {0, m})
  parser_ while(p, {:lt, m}) when is_integer(m), do: while(p, {0, m - 1})
  parser_ while(p, {n, m}) do
    fn %Paco.State{at: from, text: text, collector: collector, stream: stream} = state, this ->
      description = Paco.describe(this)
      case Paco.String.consume_while(text, p, {n, m}, from) do
        {_, "", _, _} when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        {consumed, tail, to, at} ->
          notify(collector, {:started, description})
          notify(collector, {:matched, from, to, at})
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: consumed}
        :end_of_input when is_pid(stream) ->
          wait_for_more_and_continue(state, this)
        _ ->
          notify(collector, {:started, description})
          notify(collector, {:failed, from})
          %Paco.Failure{at: from, tail: text, what: description}
      end
    end
  end

  defp wait_for_more_and_continue(state, this) do
    %Paco.State{text: text, collector: collector, stream: stream} = state
    send(stream, {self, :more})
    receive do
      {:load, more_text} ->
        notify(collector, {:loaded, more_text})
        this.parse.(%Paco.State{state|text: text <> more_text}, this)
      :halted ->
        # The stream is over, switching to a non stream mode is equal to
        # tell the parser to behave knowing that more input will never come
        this.parse.(%Paco.State{state|stream: nil}, this)
    end
  end

  defp anchor(r) do
    source = Regex.source(r)
    if String.starts_with?(source, "\\A") do
      r
    else
      {:ok, r} = Regex.compile("\\A#{source}")
      r
    end
  end
end

defimpl Inspect, for: Paco.Parser do
  import Inspect.Algebra
  alias Inspect.Opts

  def inspect(%Paco.Parser{id: nil, name: name, combine: []}, _opts), do: "#{name}"
  def inspect(%Paco.Parser{id: nil, name: name, combine: nil}, _opts), do: "#{name}"
  def inspect(%Paco.Parser{id: nil, name: name}, %Opts{width: 0}), do: "#{name}"
  def inspect(%Paco.Parser{id: nil, name: name, combine: args}, opts) do
    concat ["#{name}", surround_many("(", args, ")", %Opts{opts|width: 0}, &to_doc/2)]
  end
  def inspect(%Paco.Parser{id: id, name: name, combine: []}, _opts), do: "#{name}##{id}"
  def inspect(%Paco.Parser{id: id, name: name, combine: nil}, _opts), do: "#{name}##{id}"
  def inspect(%Paco.Parser{id: id, name: name}, %Opts{width: 0}), do: "#{name}##{id}"
  def inspect(%Paco.Parser{id: id, name: name, combine: args}, opts) do
    concat ["#{name}##{id}", surround_many("(", args, ")", %Opts{opts|width: 0}, &to_doc/2)]
  end
end
