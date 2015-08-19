import Paco
import Paco.Parser

# The classical example of context sensitive grammars is: a{n}b{n}c{n}

# "a" repeated n times, followed by "b" repeated n times, followed by "c"
# repeated n times, where n is always the same number. So "abc" it's ok,
# "aaabbbccc" it's ok, "abbc" it's not

# You cannot parse this with classic tools but you can with Paco

# First we try to match the "a" part, we don't know how many so we use an
# unbounded `while` combinator
header = while("a")

parse("a", header) |> IO.inspect
# >> {:ok, "a"}
parse("aaa", header) |> IO.inspect
# >> {:ok, "aaa"}

# Kwnowing how many "a"s there's, suppose 3, we could match the rest with the
# same `while` combinator bounded to match an exact number of characters
tail = [while("b", 3), while("c", 3)]

parse("bbbccc", tail) |> IO.inspect
# >> {:ok, ["bbb", "ccc"]}

# Time to combine all this together. When you have a situation where you know
# what comes next only at runtime you should use the `then` combinator. The
# `then` combinator applies a parser (first argument) and pass the success to a
# function (second argument) that is supposed to return the next parser that is
# going to be applied
root = while("a")
       |> then(fn(a) ->
            len = String.length(a)
            [while("b", len), while("c", len)]
          end)

parse("aaabbbccc", root) |> IO.inspect
# >> {:ok, ["bbb", "ccc"]}
parse("abc", root) |> IO.inspect
# >> {:ok, ["b", "c"]}

# Ok, but what about the "a"s? We have a couple of solutions

# Inject the result with the `always` combinator
root = while("a")
       |> then(fn(a) ->
            len = String.length(a)
            [always(a), while("b", len), while("c", len)]
          end)

parse("aaabbbccc", root) |> IO.inspect
# >> {:ok, ["aaa", "bbb", "ccc"]}
parse("abc", root) |> IO.inspect
# >> {:ok, ["a", "b", "c"]}

# Avoid to consume the input in the first place with the `peek` combinator
root = while("a")
       |> peek
       |> then(fn(a) ->
            len = String.length(a)
            [while("a", len), while("b", len), while("c", len)]
          end)

parse("aaabbbccc", root) |> IO.inspect
# >> {:ok, ["aaa", "bbb", "ccc"]}
parse("abc", root) |> IO.inspect
# >> {:ok, ["a", "b", "c"]}
