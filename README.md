# Paco
[![Build Status](https://travis-ci.org/gabrielelana/paco.svg?branch=master)](https://travis-ci.org/gabrielelana/paco)

#### Parse everything with Elixir

Paco is a monadic parser combinator library written in Elixir. Goals:

* Be **easy to learn** and **easy to use**
* Allows to create **powerful**, **understandable** and **maintainable** parsers
* Allows to quickly create complex parsers starting from **tons of reusable parsers**
* Have the **best error reporting** ever seen
* Be **testable** and **introspectable**
* **Easy things** should be **trivial**, **hard things** should be **possible**
* **Correctness** over usability (no corners cut, no special cases)
* **Usability** over features (no black magic)
* **Features** over performance (developers time is more important)
* Be as **fast** as possible

> **WARNING:** This is a work in progress, is not ready for use, so don't use it yet.

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
