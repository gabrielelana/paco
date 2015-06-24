defmodule Paco.Predicate do
  def starts_with?(prefix) do
    fn([{_, text}]) when is_binary(text) -> String.starts_with?(text, prefix)
      ({_, text}) when is_binary(text) -> String.starts_with?(text, prefix)
      (text) when is_binary(text) -> String.starts_with?(text, prefix)
    end
  end
end
