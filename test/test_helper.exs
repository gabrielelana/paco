ExUnit.start()

defmodule Paco.Test.Helper do
  def stream_of(string) do
    Stream.unfold(string, fn <<h::utf8, t::binary>> -> {<<h>>, t}; <<>> -> nil end)
  end
end
