import Paco
import Paco.Parser

word = while("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
separator = lex(",") |> skip
terminator = lex("!") |> one_or_more |> skip
greetings = sequence_of([word, separator, word, terminator])

parse(greetings, "Hello,World!") |> IO.inspect
# >> {:ok, ["Hello", "World"]}

parse(greetings, "Hello, World!") |> IO.inspect
# >> {:ok, ["Hello", "World"]}

parse(greetings, "Hello, World!!!") |> IO.inspect
# >> {:ok, ["Hello", "World"]}
