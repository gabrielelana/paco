import Paco
import Paco.Parser

letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
word = while(letters, at_least: 1)
separator = lex(",") |> skip
terminator = lex("!") |> one_or_more |> skip
greetings = sequence_of([word, separator, word, terminator])

parse("Hello,World!", greetings) |> IO.inspect
# >> {:ok, ["Hello", "World"]}

parse("Hello, World!", greetings) |> IO.inspect
# >> {:ok, ["Hello", "World"]}

parse("Hello, World!!!", greetings) |> IO.inspect
# >> {:ok, ["Hello", "World"]}
