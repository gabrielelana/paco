ExUnit.start()

defmodule Paco.Test.Helper do
  def stream_of(string) do
    Stream.unfold(string, fn <<h::utf8, t::binary>> -> {<<h>>, t}; <<>> -> nil end)
  end

  def count(key), do: count(key, nil)
  def count(key, _) do
    Process.put(key, Process.get(key, 0) + 1)
  end

  def counted(key), do: Process.get(key, 0)

  def events_notified_by(parser, text) do
    alias Paco.Test.EventRecorder
    {:ok, collector} = EventRecorder.start_link
    try do
      Paco.parse(parser, text, collector: collector)
      EventRecorder.events_recorded(collector)
    after
      EventRecorder.stop(collector)
    end
  end
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
