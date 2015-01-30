# Paco
A parser combinator library for Elixir

## Example
```elixir
parser(expression) do
  one_of([number, expression]) |> separated_by(",") |> surrounded_by("(", ")")
end

expression |> parse("(7, (4, 5), (1, 2, 3), 6)") # => [7, [4, 5], [1, 2, 3], 6]
```
