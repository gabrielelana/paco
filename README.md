# Paco
[![Build Status](https://travis-ci.org/gabrielelana/paco.svg?branch=master)](https://travis-ci.org/gabrielelana/paco)

##### Parse everything with Elixir

Paco is a monadic parser combinator library written in Elixir. Goals:

* Be easy to learn and easy to use
* Quickly create powerful, understandable and maintainable parsers
* Have the best error reporting ever seen
* Be testable and introspectable
* Easy things should be trivial, hard things should be possible
* Correctness over usability (no corners cut, no special cases)
* Usability over features (no black magic)
* Features over performance (developers time is more important)
* Be as fast as possible

##### This is work in progress, this is not 0.0.1 therefore it's not yet usable but it's coming along nicely

## Example

```elixir
defmodule Expression do
  use Paco

  parser expression do
    one_of([number, expression]) |> separated_by(",") |> surrounded_by("(", ")")
  end
end

Expression.parse("(7, (4, 5), (1, 2, 3), 6)") # => [7, [4, 5], [1, 2, 3], 6]
```
