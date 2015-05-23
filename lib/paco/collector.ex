defmodule Paco.Collector do

  @env String.to_atom(System.get_env("MIX_ENV") || "dev")

  defmacro notify_loaded(text, state), do: call(@env, :notify_loaded_, [text, state])
  defmacro notify_started(parser, state), do: call(@env, :notify_started_, [parser, state])
  defmacro notify_ended(result, state), do: call(@env, :notify_ended_, [result, state])

  defp call(:prod, _, _), do: :ok
  defp call(_, name, args) do
    quote do
      unquote(name)(unquote_splicing(args))
    end
  end

  def notify_loaded_(_text, %Paco.State{collector: nil}), do: nil
  def notify_loaded_(_text, %Paco.State{silent: true}), do: nil
  def notify_loaded_(text, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:loaded, text})
  end

  def notify_started_(_parser, %Paco.State{collector: nil}), do: nil
  def notify_started_(_parser, %Paco.State{silent: true}), do: nil
  def notify_started_(parser, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:started, Paco.describe(parser)})
  end

  def notify_ended_(result, %Paco.State{collector: nil}), do: result
  def notify_ended_(result, %Paco.State{silent: true}), do: result
  def notify_ended_(%Paco.Success{} = success, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:matched, success.from, success.to, success.at})
    success
  end
  def notify_ended_(%Paco.Failure{} = failure, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:failed, failure.at})
    failure
  end
end
