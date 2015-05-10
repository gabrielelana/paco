defmodule Paco.Input do
  @type position :: {non_neg_integer, non_neg_integer, non_neg_integer}
  @type t :: %__MODULE__{at: non_neg_integer,
                         text: String.t,
                         collector: pid | nil,
                         stream: pid | nil}

  defstruct at: {0, 1, 1}, text: "", collector: nil, stream: nil

  def from(text, opts \\ []) when is_binary(text) do
    %__MODULE__{at: {0, 1, 1},
                text: text,
                collector: Keyword.get(opts, :collector, nil)
                           |> notify_loaded(text),
                stream: Keyword.get(opts, :stream, nil)}
  end

  defp notify_loaded(collector, _) when not is_pid(collector), do: nil
  defp notify_loaded(collector, text) do
    GenEvent.notify(collector, {:loaded, text})
    collector
  end
end
