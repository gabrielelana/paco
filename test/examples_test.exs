defmodule Paco.ExamplesTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @examples Path.join(__DIR__, "../examples/[0-9][0-9]_*.exs") |> Path.wildcard

  for example <- @examples do
    test "example #{Path.basename(example)}" do
      example_path = Path.expand(unquote(example))

      expected = File.stream!(example_path)
                 |> Enum.with_index
                 |> Enum.filter(fn({l, _}) -> Regex.match?(~r/^# >>/, l) end)
                 |> Enum.map(fn({l, ln}) -> {String.replace(l, ~r/^# >>\s*/, ""), ln} end)
                 |> Enum.map(fn({l, ln}) -> {String.strip(l), ln} end)
                 |> Enum.map(fn({l, ln}) -> {l, ln + 1} end)

      output = capture_io(fn -> Code.eval_file(example_path) end)
               |> String.split("\n")

      for {{expected, ln}, output} <- Enum.zip(expected, output) do
        assert output == expected,
               """
               At #{example_path}:#{ln}
               expected: #{expected}
               got:      #{output}
               """
      end
    end
  end
end
