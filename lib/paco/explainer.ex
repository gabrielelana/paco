defmodule Paco.Explainer do
  use GenEvent

  defstruct events: [], level: 0

  def init(_args) do
    {:ok, %Paco.Explainer{}}
  end

  def handle_event({:loaded, _text} = event, state) do
    # IO.inspect(event)
    {:ok, %Paco.Explainer{state|events: [event|state.events]}}
  end

  def handle_event({:started, _what} = event, state) do
    # IO.puts("event #{inspect(event)} at level #{state.level}")
    {:ok, %Paco.Explainer{state|events: [event|state.events], level: state.level + 1}}
  end

  def handle_event({:matched, _from, _to, _at} = event, state) do
    # IO.puts("event #{inspect(event)} at level #{state.level}")
    # :timer.sleep(1000)
    {:ok, %Paco.Explainer{state|events: [event|state.events], level: state.level - 1}}
  end

  def handle_event({:failed, _at} = event, state) do
    # IO.puts("event #{inspect(event)} at level #{state.level}")
    # :timer.sleep(1000)
    {:ok, %Paco.Explainer{state|events: [event|state.events], level: state.level - 1}}
  end

  def handle_call(:report, %Paco.Explainer{level: level} = state) when level > 0 do
    {:ok, {:error, :not_ready}, state}
  end
  def handle_call(:report, state) do
    {:ok, {:ok, report(state.events |> Enum.reverse)}, state}
  end

  def report(events) do
    process(events, _report = %{}, _text = "", _started = [])
  end

  defp process([], report, _text, []), do: Dict.get(report, 0, "")
  defp process([{:loaded, loaded}|events], report, so_far, started) do
    process(events, report, so_far <> loaded, started)
  end
  defp process([{:started, what}|events], report, text, started) do
    process(events, report, text, [what|started])
  end
  defp process([{:matched, from, to, at}|events], report, text, [what|started]) do
    {{fp, fl, fc}, {tp, tl, tc}, {_, _, ac}} = {from, to, at}
    level = Enum.count(started)
    report =
      indent(
        if fl == tl do
          line_pointer_from = "#{fl}:"
          line_pointer_spacer_from = String.duplicate(" ", String.length(line_pointer_from))
          """
          Matched #{what} from #{fl}:#{fc} to #{tl}:#{tc}
          #{line_pointer_from} #{Paco.String.line_at(text, fp)}
          #{line_pointer_spacer_from} #{pointers(fc, tc, ac)}
          """
        else
          line_pointer_from = "#{fl}:"
          line_pointer_spacer_from = String.duplicate(" ", String.length(line_pointer_from))
          line_pointer_to = "#{tl}:"
          line_pointer_spacer_to = String.duplicate(" ", String.length(line_pointer_to))
          """
          Matched #{what} from #{fl}:#{fc} to #{tl}:#{tc}
          #{line_pointer_from} #{Paco.String.line_at(text, fp)}
          #{line_pointer_spacer_from} #{pointers(fc, fc, ac)}
          #{line_pointer_to} #{Paco.String.line_at(text, tp)}
          #{line_pointer_spacer_to} #{pointers(tc, tc, ac)}
          """
        end,
        level)
      |> add_to_report_at(report, level)
    process(events, report, text, started)
  end
  defp process([{:failed, {p, l, c}}|events], report, text, [failed|started]) do
    level = Enum.count(started)
    line_pointer = "#{l}:"
    line_pointer_spacer = String.duplicate(" ", String.length(line_pointer))
    report =
      indent(
        """
        Failed to match #{failed} at #{l}:#{c}
        #{line_pointer} #{Paco.String.line_at(text, p)}
        #{line_pointer_spacer} #{pointers(c, c, nil)}
        """,
        level
      )
      |> add_to_report_at(report, level)
    process(events, report, text, started)
  end

  defp add_to_report_at(report_section, report, level) do
    {report_section, report} = merge_with_children_report_at(report_section, report, level)
    merge_with_brothers_report_at(report_section, report, level)
  end

  defp merge_with_children_report_at(report_section, report, level) do
    case Dict.get(report, level + 1, :no_children) do
      :no_children ->
        {report_section, report}
      children_report ->
        {report_section <> children_report, Dict.delete(report, level + 1)}
    end
  end

  defp merge_with_brothers_report_at(report_section, report, level) do
    case Dict.get(report, level, :no_brothers) do
      :no_brothers ->
        Dict.put(report, level, report_section)
      brothers_report ->
        Dict.put(report, level, brothers_report <> report_section)
    end
  end

  defp indent(text, level) do
    text
    |> indent_with_spaces(level)
    |> mark_relation_with_parent
    |> trim_leading_spaces
  end

  defp pointers(at_column, at_column, at_column) do
    String.duplicate(" ", at_column - 1) <>
    "~"
  end
  defp pointers(at_column, at_column, _) do
    String.duplicate(" ", at_column - 1) <>
    "^"
  end
  defp pointers(from_column, to_column, to_column) do
    String.duplicate(" ", from_column - 1) <>
    "^" <>
    String.duplicate(" ", to_column - from_column - 1) <>
    "~"
  end
  defp pointers(from_column, to_column, _) do
    String.duplicate(" ", from_column - 1) <>
    "^" <>
    String.duplicate(" ", to_column - from_column - 1) <>
    "^"
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
