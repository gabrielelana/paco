defmodule Paco.Collector do

  def notify_loaded(_text, %Paco.State{collector: nil}), do: nil
  def notify_loaded(_text, %Paco.State{silent: true}), do: nil
  def notify_loaded(text, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:loaded, text})
  end

  def notify_started(_parser, %Paco.State{collector: nil}), do: nil
  def notify_started(_parser, %Paco.State{silent: true}), do: nil
  def notify_started(parser, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:started, Paco.describe(parser)})
  end

  def notify_ended(result, %Paco.State{collector: nil}), do: result
  def notify_ended(result, %Paco.State{silent: true}), do: result
  def notify_ended(%Paco.Success{} = success, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:matched, success.from, success.to, success.at})
    success
  end
  def notify_ended(%Paco.Failure{} = failure, %Paco.State{collector: collector}) do
    GenEvent.notify(collector, {:failed, failure.at})
    failure
  end
end
