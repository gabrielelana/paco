# Paco
A parser combinator library for Elixir

## Example
```elixir
expression =
  recursive(
    fn(p) ->
      one_of([number, p]) |> separated_by(",") |> surrounded_by("(", ")")
    end
  )

expression |> parse("(7, (4, 5), (1, 2, 3), 6)") # => [7, [4, 5], [1, 2, 3], 6]
```
