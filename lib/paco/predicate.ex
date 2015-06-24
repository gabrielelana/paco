defmodule Paco.Predicate do
  alias Paco.Success

  def starts_with?(prefix) do
    fn([{_, text}]) when is_binary(text) -> String.starts_with?(text, prefix)
      ({_, text}) when is_binary(text) -> String.starts_with?(text, prefix)
      (text) when is_binary(text) -> String.starts_with?(text, prefix)
    end
  end

  def consumed_any_input?(message) do
    fn(_, %Success{from: {n, _, _}, at: {m, _, _}}) when m > n
        -> true
      (_, _)
        -> {false, message}
    end
  end
end
