import Paco
import Paco.Parser

# Simple algebraic expression parser that performs the four basic arithmetic
# operations: `+`, `-`, `*` and `/`. The `*` and `/` have precedence over `+`
# and `-`

# We will implement this in the most straightforward way, we will learn that
# Paco offers better ways to do the same thing

# First of all we need numbers, numbers representation could be much more
# complex than that but for now we don't care and we will keep it simple
number = while("0123456789", at_least: 1)

parse(number, "1") |> IO.inspect
# >> {:ok, "1"}
parse(number, "42") |> IO.inspect
# >> {:ok, "42"}
parse(number, "1024") |> IO.inspect
# >> {:ok, "1024"}

# Ok, but we need numbers not strings, we need to be able to take the result of
# the `number` parser and convert it to an integer. Luckily we have the `bind`
# combinator
number = while("0123456789", at_least: 1)
         |> bind(&String.to_integer/1)

parse(number, "42") |> IO.inspect
# >> {:ok, 42}

# We also need to ignore whitespaces around a number, to do that we will use
# the `surrounded_by` combinator, since the whitespaces are optionals we also
# use the `maybe` combinator
number = while("0123456789", at_least: 1)
         |> surrounded_by(maybe(whitespaces))
         |> bind(&String.to_integer/1)

parse(number, " 42 ") |> IO.inspect
# >> {:ok, 42}

# An expression is a number, an operation between expressions and an expression
# between parentheses. An expression is defined in terms of itself so it's a
# recursive definition. For a recursive definition we need a recursive parser

# We need to be able to talk about a parser before having completed its
# definition, for this we use the `recursive` combinator
expression =
  recursive(
    fn(e) ->
      one_of([number, e |> surrounded_by(lex("("), lex(")"))])
    end)

# The `recursive` combinator takes a function that is called with the
# parser itself as the first parameter. Here `expression` and `e` are the same
# parser

parse(expression, "42") |> IO.inspect
# >> {:ok, 42}
parse(expression, "(42)") |> IO.inspect
# >> {:ok, 42}

# Note that surrounded_by takes two lexemes that are going to consume useless
# whitespaces. In fact, by default strings in surrounded_by are converted in
# lexemes so we can leave out the `lex` combinator
expression =
  recursive(
    fn(e) ->
      one_of([number, e |> surrounded_by("(", ")")])
    end)

parse(expression, "( 42 )") |> IO.inspect
# >> {:ok, 42}

# Now we are going to add the `*` and `/` operator, what is going to be
# multiplied or divided? A number or an expression surrounded by parentheses.
# For now let's focus on recognizing the structure
expression =
  recursive(
    fn(e) ->
      multipliables = one_of([number, e |> surrounded_by("(", ")")])
      one_of([
        multipliables |> separated_by("*", at_least: 1),
        multipliables |> separated_by("/", at_least: 1)
      ])
    end)

# We need to force the `separated_by` combinator to match at least 1 separator
# otherwise it would be happy to match a single number as multiplication and so
# to never parse divisions

parse(expression, "42 * 2") |> IO.inspect
# >> {:ok, [42, 2]}
parse(expression, "42 * 2 * 2") |> IO.inspect
# >> {:ok, [42, 2, 2]}
parse(expression, "42 / 2") |> IO.inspect
# >> {:ok, [42, 2]}

# We have a problem

parse(expression, "42") |> IO.inspect
# >> {:error, "expected one of [\"*\", \"/\"] at 1:3 but got the end of input"}

# We have lost the power to match single numbers because the only parser we
# have requires at least one operator, we need to provide a parser for plain
# numbers

expression =
  recursive(
    fn(e) ->
      multipliables = one_of([number, e |> surrounded_by("(", ")")])
      one_of([
        multipliables |> separated_by("*", at_least: 1),
        multipliables |> separated_by("/", at_least: 1),
        multipliables
      ])
    end)

parse(expression, "42 * 2") |> IO.inspect
# >> {:ok, [42, 2]}
parse(expression, "42 / 2") |> IO.inspect
# >> {:ok, [42, 2]}
parse(expression, "42") |> IO.inspect
# >> {:ok, 42}

# Unfortunately we have another problem

parse(expression, "42 * 2 / 2") |> IO.inspect
# >> {:ok, [42, 2]}

# The last expression should have been `{:ok, [42, 2, 2]}` why we didn't get a
# parser error? Parsing a part of the whole input is perfectly fine, if you
# want to make sure that your parser match the whole input we need to make sure
# that what follows is the end of input
expression =
  recursive(
    fn(e) ->
      multipliables = one_of([number, e |> surrounded_by("(", ")")])
      one_of([
        multipliables |> separated_by("*", at_least: 1),
        multipliables |> separated_by("/", at_least: 1),
        multipliables
      ])
    end)
  |> followed_by(eof)

parse(expression, "42 * 2 / 2") |> IO.inspect
# >> {:error, "expected the end of input at 1:8"}

# Now it's clear, the `/` is not recognized... the problem is that once the
# multiplication alternative matched thanks to the first `*` what follows could
# only be: a continuation of the same multiplication, a number or an expression
# surrounded by parentheses, but not a division. In fact puting parentheses
# around the division solves the problem

parse(expression, "42 * (2 * 2)") |> IO.inspect
# >> {:ok, [42, [2, 2]]}

# How do we solve this? Moving the `one_of` combinator inside the
# `separated_by` combinator will solve this and other problems we had before

expression =
  recursive(
    fn(e) ->
      multipliables = one_of([number, e |> surrounded_by("(", ")")])
      multipliables |> separated_by(one_of(["*", "/"]))
    end)
  |> followed_by(eof)

parse(expression, "16") |> IO.inspect
# >> {:ok, [16]}
parse(expression, "16 * 2") |> IO.inspect
# >> {:ok, [16, 2]}
parse(expression, "16 / 2") |> IO.inspect
# >> {:ok, [16, 2]}
parse(expression, "16 * 2 / 2") |> IO.inspect
# >> {:ok, [16, 2, 2]}

# The only downside is that we need to keep the separator because now we can't
# discern between multiplication and division, to do this we will use the
# `keep` combinator that cancels the effect of the `skip` combinator used
# inside the `separated_by` combinator.

expression =
  recursive(
    fn(e) ->
      multipliables = one_of([number, e |> surrounded_by("(", ")")])
      multipliables |> separated_by(keep(one_of(["*", "/"])))
    end)
  |> followed_by(eof)

parse(expression, "42 * 2") |> IO.inspect
# >> {:ok, [42, "*", 2]}
parse(expression, "42 / 2") |> IO.inspect
# >> {:ok, [42, "/", 2]}

# Now we can start to reduce the expression with the help of
# `Paco.Transform.separated_by` transformer which is going to make our job
# easier

reduce = &Paco.Transform.separated_by(
           &1,
           fn("*", n, m) -> n * m
             ("/", n, m) -> n / m |> round
           end)

expression =
  recursive(
    fn(e) ->
      multipliables = one_of([number, e |> surrounded_by("(", ")")])
      multipliables |> separated_by(keep(one_of(["*", "/"]))) |> bind(reduce)
    end)
  |> followed_by(eof)

parse(expression, "42 * 2") |> IO.inspect
# >> {:ok, 84}
parse(expression, "42 / 2") |> IO.inspect
# >> {:ok, 21}

# Nice, time to introduce the last two operators following the same pattern

reduce = &Paco.Transform.separated_by(
           &1,
           fn("*", n, m) -> n * m
             ("/", n, m) -> n / m |> round
             ("+", n, m) -> n + m
             ("-", n, m) -> n - m
           end)

expression =
  recursive(
    fn(e) ->
      multipliables = one_of([number, e |> surrounded_by("(", ")")])
      additionables = multipliables
                      |> separated_by(keep(one_of(["*", "/"])))
                      |> bind(reduce)
      additionables
      |> separated_by(keep(one_of(["+", "-"])))
      |> bind(reduce)
    end)
  |> followed_by(eof)


parse(expression, "42 + 2") |> IO.inspect
# >> {:ok, 44}
parse(expression, "42 - 2") |> IO.inspect
# >> {:ok, 40}

# What about the operators precedence?
parse(expression, "42 - 2 * 5") |> IO.inspect
# >> {:ok, 32}
parse(expression, "(42 - 2) * 5") |> IO.inspect
# >> {:ok, 200}

# It works! Let's check if all it's ok

parse(expression, "42") |> IO.inspect
# >> {:ok, 42}
parse(expression, "(42)") |> IO.inspect
# >> {:ok, 42}
parse(expression, "42 + 2") |> IO.inspect
# >> {:ok, 44}
parse(expression, "42 + 2 - 2") |> IO.inspect
# >> {:ok, 42}
parse(expression, "(42) + (2)") |> IO.inspect
# >> {:ok, 44}
parse(expression, "42 * 2 + 1") |> IO.inspect
# >> {:ok, 85}
parse(expression, "42 * (2 + 1)") |> IO.inspect
# >> {:ok, 126}
parse(expression, "(42 + 2) / (3 - 1)") |> IO.inspect
# >> {:ok, 22}
parse(expression, "((42 + 2) / (3 - 1))") |> IO.inspect
# >> {:ok, 22}
parse(expression, "42 + 2 * 3 + 100") |> IO.inspect
# >> {:ok, 148}
parse(expression, "((42+2)/(3-1))") |> IO.inspect
# >> {:ok, 22}
parse(expression, "9 - 12 - 6") |> IO.inspect
# >> {:ok, -9}
parse(expression, "9 - (12 - 6)") |> IO.inspect
# >> {:ok, 3}
parse(expression, "(1+1*2)+(3*4*5)/20") |> IO.inspect
# >> {:ok, 6}
parse(expression, "((1+1*2)+(3*4*5))/3") |> IO.inspect
# >> {:ok, 21}

# After a little simplification here's the final result
reduce = &Paco.Transform.separated_by(
           &1,
           fn("*", n, m) -> n * m
             ("/", n, m) -> n / m |> round
             ("+", n, m) -> n + m
             ("-", n, m) -> n - m
           end)

expression =
  recursive(
    fn(e) ->
      one_of([number, e |> surrounded_by("(", ")")])
      |> separated_by(keep(one_of(["*", "/"])))
      |> bind(reduce)
      |> separated_by(keep(one_of(["+", "-"])))
      |> bind(reduce)
    end)
  |> followed_by(eof)

# That's pretty neat but we can do even better, we will see how...
