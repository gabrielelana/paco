# Paco
A parser combinator library for Elixir

## Example
```elixir
expression = lazy(
  seq([
    string("("),
    one_of([
      nothing, digit |> separated_by(string(",")), expression
    ]),
    string(")"),
  ])
)

expression |> parse("(7, (4, 5), (1, 2, 3), 6)") # == [7, [4, 5], [1, 2, 3], 6]
```
