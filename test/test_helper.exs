ExUnit.start()

defmodule Paco.Test.Helper do
  def stream_of(text) do
    Stream.unfold(text, fn <<h::utf8, t::binary>> -> {<<h>>, t}; <<>> -> nil end)
  end

  def count(key), do: count(key, nil)
  def count(key, _) do
    Process.put(key, Process.get(key, 0) + 1)
  end

  def counted(key), do: Process.get(key, 0)

  def assert_events_notified(parser, text, expected) do
    alias Paco.Test.EventRecorder
    {:ok, collector} = EventRecorder.start_link
    try do
      Paco.parse(parser, text, collector: collector)
      notified = EventRecorder.events_recorded(collector)
      do_assert_events_notified(notified, expected)
    after
      EventRecorder.stop(collector)
    end
  end

  defp do_assert_events_notified([], []), do: true
  defp do_assert_events_notified([], [_|_]=r) do
    ExUnit.Assertions.flunk "Some events were not notified:\n#{inspect(r)}"
  end
  defp do_assert_events_notified([hl|tl], [hl|tr]), do: do_assert_events_notified(tl, tr)
  defp do_assert_events_notified([_|tl], r), do: do_assert_events_notified(tl, r)
end

defmodule Paco.Test.EventRecorder do
  use GenEvent

  def start_link do
    {:ok, pid} = GenEvent.start_link()
    GenEvent.add_handler(pid, __MODULE__, [])
    {:ok, pid}
  end

  def events_recorded(pid) do
    GenEvent.call(pid, __MODULE__, :events)
  end

  def stop(pid) do
    GenEvent.stop(pid)
  end

  def handle_event(event, events) do
    {:ok, [event|events]}
  end

  def handle_call(:events, events) do
    {:ok, Enum.reverse(events), events}
  end
end
