# Until now we defined parsers as functions but you can define parsers in a
# module with the macros that are imported with `use Paco`

defmodule HelloSentence do
  use Paco

  # It's convinient to be able to define constants with module attributes
  @letters "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  # The `parser` macro will define a function `separator` that will return a
  # parser called `separator` defined by the `do` block passed to the macro

  parser separator, do: lex(",") |> skip

  # We modified a little bit the example making the terminator optional (with
  # `zero_or_more`) and requiring the greeting to be "Hello"

  parser terminator, do: lex("!") |> zero_or_more |> skip

  parser greeting, do: lit("Hello")
  parser subject, do: while(@letters, at_least: 1)

  # The last parser of the module it's the root parser
  parser sentence, do: [greeting, separator, subject, terminator]

  # When all the parser has been defined Paco will generate a function `parse`
  # that will invoke the root parser on the given argument
end

HelloSentence.parse("Hello, World!") |> IO.inspect
# >> {:ok, ["Hello", "World"]}
HelloSentence.parse("Hello, Paco!") |> IO.inspect
# >> {:ok, ["Hello", "Paco"]}
HelloSentence.parse("Hello, Gabriele") |> IO.inspect
# >> {:ok, ["Hello", "Gabriele"]}

# Nothing shocking, it's worth mention though that every module parser has a
# description so that the possible failures will contain the reference of those
# parsers making failure more readable and intellegible

HelloSentence.parse("Hello") |> IO.inspect(width: 100)
# >> {:error, "expected \",\" (separator < sentence) at 1:6 but got the end of input"}

# This error is saying that "," was expected by the `separator` parser which is
# part of the `sentence` parser. In this simple example doesn't seem much but
# in more complex situations could be handy
