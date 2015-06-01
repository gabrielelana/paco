import Paco
import Paco.Parser
import Paco.String

word = while(&letter?/1)
separator = lex(",") |> skip
terminator = lex("!") |> one_or_more |> skip
greetings = sequence_of([word, separator, word, terminator])

# iex> parse(greetings, "Hello,World!")
# {:ok, ["Hello", "World"]}
#
# iex> parse(greetings, "Hello, World!")
# {:ok, ["Hello", "World"]}
#
# iex> parse(greetings, "Hello, World!!!")
# {:ok, ["Hello", "World"]}
