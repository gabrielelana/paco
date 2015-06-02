import Paco
import Paco.Parser

letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
word = while(letters) |> one_or_more
separator = lex(",") |> skip
terminator = lex("!") |> one_or_more |> skip
greetings = sequence_of([word, separator, word, terminator])

parse(greetings, "Hello,World!") |> IO.inspect
# >> {:ok, ["Hello", "World"]}

parse(greetings, "Hello, World!") |> IO.inspect
# >> {:ok, ["Hello", "World"]}

parse(greetings, "Hello, World!!!") |> IO.inspect
# >> {:ok, ["Hello", "World"]}
