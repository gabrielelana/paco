defmodule Paco.Explainer do
  use GenEvent

  defstruct events: [], level: 0

  def init(_args) do
    {:ok, %Paco.Explainer{}}
  end

  def handle_event({:loaded, _text} = event, state) do
    # IO.inspect(event)
    {:ok, %Paco.Explainer{state| events: [event|state.events]}}
  end

  def handle_event({:started, _what} = event, state) do
    # IO.puts("event #{inspect(event)} at level #{state.level}")
    {:ok, %Paco.Explainer{state| events: [event|state.events], level: state.level + 1}}
  end

  def handle_event({:matched, _from, _to} = event, state) do
    # IO.puts("event #{inspect(event)} at level #{state.level}")
    # :timer.sleep(1000)
    {:ok, %Paco.Explainer{state| events: [event|state.events], level: state.level - 1}}
  end

  def handle_event({:failed, _at} = event, state) do
    # IO.puts("event #{inspect(event)} at level #{state.level}")
    # :timer.sleep(1000)
    {:ok, %Paco.Explainer{state| events: [event|state.events], level: state.level - 1}}
  end

  def handle_call(:report, %Paco.Explainer{level: level} = state) when level > 0 do
    {:ok, {:error, :not_ready}, state}
  end
  def handle_call(:report, state) do
    {:ok, {:ok, report(state.events |> Enum.reverse)}, state}
  end

  def report(events, report \\ "", text \\ "", started \\ []) do
    process(events, report, text, started, false)
  end

  defp process([], report, _text, [], _is_combinator), do: report
  defp process([{:loaded, loaded}|events], report, so_far, started, _is_combinator) do
    process(events, report, so_far <> loaded, started, false)
  end
  defp process([{:started, what}|events], report, text, started, _is_combinator) do
    process(events, report, text, [what|started], false)
  end
  defp process([{:matched, {fp, fl, fc}, {tp, tl, tc}}|events], report, text, [what|started], is_combinator) do
    level = Enum.count(started)
    line_pointer_from = "#{fl}>"
    line_pointer_spacer_from = String.duplicate(" ", String.length(line_pointer_from))
    matched_report =
      if fl == tl do
        indent(
          """
          Matched #{what} from #{fl}:#{fc} to #{tl}:#{tc}
          #{line_pointer_from} #{line(text, fp)}
          #{line_pointer_spacer_from} #{pointers(fc, tc)}
          """,
          level
        )
      else
        line_pointer_to = "#{tl}>"
        line_pointer_spacer_to = String.duplicate(" ", String.length(line_pointer_to))
        indent(
          """
          Matched #{what} from #{fl}:#{fc} to #{tl}:#{tc}
          #{line_pointer_from} #{line(text, fp)}
          #{line_pointer_spacer_from} #{pointers(fc)}
          #{line_pointer_to} #{line(text, tp)}
          #{line_pointer_spacer_to} #{pointers(tc)}
          """,
          level
        )
      end
    report = if is_combinator, do: matched_report <> report, else: report <> matched_report
    process(events, report, text, started, true)
  end
  defp process([{:failed, {p, l, c}}|events], report, text, [failed|started], is_combinator) do
    level = Enum.count(started)
    line_pointer = "#{l}>"
    line_pointer_spacer = String.duplicate(" ", String.length(line_pointer))
    failed_report =
      indent(
        """
        Failed to match #{failed} at #{l}:#{c}
        #{line_pointer} #{line(text, p)}
        #{line_pointer_spacer} #{pointers(c)}
        """,
        level
      )
    report = if is_combinator, do: failed_report <> report, else: report <> failed_report
    process(events, report, text, started, true)
  end

  defp indent(text, level) do
    text
    |> indent_with_spaces(level)
    |> mark_relation_with_parent
    |> trim_leading_spaces
  end

  defp pointers(from_column, from_column), do: pointers(from_column)
  defp pointers(from_column, to_column) do
    String.duplicate(" ", from_column - 1) <>
    "^" <>
    String.duplicate(" ", to_column - from_column - 1) <>
    "^"
  end

  defp pointers(at_column) do
    String.duplicate(" ", at_column - 1) <>
    "^"
  end

  defp line(text, at) do
    case {collect(text, at, &(&1 - 1)), at} do
      {[], 0} ->
        ""
      {[], _} ->
        collect(text, at - 1, &(&1 - 1))
        |> Enum.reverse
        |> Enum.join
      {left, _} ->
        Enum.concat(
          left |> Enum.reverse,
          collect(text, at + 1, &(&1 + 1)))
        |> Enum.join
    end
  end

  defp collect(text, at, next) do
    Stream.unfold(at, fn
                        at when at < 0 ->
                          nil
                        at ->
                          case String.at(text, at) do
                            nil -> nil
                            "\n" -> nil
                            in_line -> {in_line, next.(at)}
                          end
                      end)
    |> Enum.to_list
  end

  defp indent_with_spaces(text, level) do
    Regex.replace(~r/^/m, text, String.duplicate("   ", level))
  end

  defp mark_relation_with_parent(text) do
    Regex.replace(~r/^(\s*)   (Matched|Failed)/m, text, "\\1└─ \\2")
  end

  defp trim_leading_spaces(text) do
    Regex.replace(~r/ +$/m, text, "")
  end
end
