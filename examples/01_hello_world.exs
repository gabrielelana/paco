import Paco
import Paco.Parser

letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
word = while(letters) |> one_of_more
separator = lex(",") |> skip
terminator = lex("!") |> one_or_more |> skip
greetings = sequence_of([word, separator, word, terminator])

parse(greetings, "Hello,World!") |> IO.inspect
# >> {:ok, ["Hello", "World"]}

parse(greetings, "Hello, World!") |> IO.inspect
# >> {:ok, ["Hello", "World"]}

parse(greetings, "Hello, World!!!") |> IO.inspect
# >> {:ok, ["Hello", "World"]}

explain(greetings, "Hello, World!") |> elem(1) |> IO.puts
# Matched sequence_of([word, separator, word, terminator]) from 1:1 to 1:13
# 1: Hello, World!
#    ^           ^
# └─ Matched while(letters, {1, :infinity}) from 1:1 to 1:5
#    1: Hello, World!
#       ^   ^
# └─ Matched skip(lex(",")) from 1:6 to 1:7
#    1: Hello, World!
#            ^^
#    └─ Matched lex(",") from 1:6 to 1:7
#       1: Hello, World!
#               ^^
# └─ Matched while(letters, {1, :infinity}) from 1:8 to 1:12
#    1: Hello, World!
#              ^   ^
# └─ Matched skip(repeat(lex("!"), {1, :infinity})) from 1:13 to 1:13
#    1: Hello, World!
#                   ^
#    └─ Matched repeat(lex("!"), {1, :infinity}) from 1:13 to 1:13
#       1: Hello, World!
#                      ^
#       └─ Matched lex("!") from 1:13 to 1:13
#          1: Hello, World!
#                         ^
#       └─ Failed to match lex("!") at 1:14
#          1: Hello, World!
#                          ^
