defmodule Paco.State do
  @type position :: {non_neg_integer, non_neg_integer, non_neg_integer}
  @type t :: %__MODULE__{text: String.t,
                         at: position,
                         accumulator: term | nil,
                         collector: pid | nil,
                         stream: pid | nil,
                         silent: boolean}

  defstruct at: {0, 1, 1}, text: "", accumulator: nil, collector: nil, stream: nil, silent: false

  def from(text, opts \\ []) when is_binary(text) do
    %__MODULE__{at: Keyword.get(opts, :at, {0, 1, 1}),
                text: text,
                collector: Keyword.get(opts, :collector, nil) |> notify_loaded(text),
                stream: Keyword.get(opts, :stream, nil)}
  end

  defp notify_loaded(collector, _) when not is_pid(collector), do: nil
  defp notify_loaded(collector, text) do
    GenEvent.notify(collector, {:loaded, text})
    collector
  end
end
