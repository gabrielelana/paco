import Paco
import Paco.Parser

unit_values = [
  {"zero",       0},
  {"one",        1},
  {"two",        2},
  {"three",      3},
  {"four",       4},
  {"five",       5},
  {"six",        6},
  {"seven",      7},
  {"eight",      8},
  {"nine",       9},
  {"ten",       10},
  {"eleven",    11},
  {"twelve",    12},
  {"thirteen",  13},
  {"fourteen",  14},
  {"fifteen",   15},
  {"sixteen",   16},
  {"seventeen", 17},
  {"eighteen",  18},
  {"nineteen",  19},
] |> Enum.reverse

tens_values = [
  {"twenty",  20},
  {"thirty",  30},
  {"forty",   40},
  {"fifty",   50},
  {"sixty",   60},
  {"seventy", 70},
  {"eighty",  80},
  {"ninety",  90},
]

scale_values = [
  {"thousand",    1_000},
  {"million",     1_000_000},
  {"billion",     1_000_000_000},
  {"trillion",    1_000_000_000_000},
]


mul = fn ns -> Enum.reduce(ns, 1, &Kernel.*/2) end
sum = fn ns -> Enum.reduce(ns, 0, &Kernel.+/2) end

units = one_of(for {word, value} <- unit_values, do: lex(word) |> replace_with(value))

tens = one_of(for {word, value} <- tens_values, do: lex(word) |> replace_with(value))
tens = [tens, skip(maybe(lex("-"))), maybe(units, default: 0)] |> bind(sum)
tens = [tens, units] |> one_of

hundreds = lex("hundred") |> replace_with(100)
hundreds = [tens, maybe(hundreds, default: 1)] |> bind(mul)
hundreds = [hundreds, skip(maybe(lex("and"))), maybe(tens, default: 0)] |> bind(sum)

scales = one_of(for {word, value} <- scale_values, do: lex(word) |> replace_with(value))

number = [one_of([hundreds, tens]), maybe(scales, default: 1)] |> bind(mul)
number = number |> separated_by(maybe(lex("and"))) |> bind(sum)


parse("one", number) |> IO.inspect
# >> {:ok, 1}
parse("twenty", number) |> IO.inspect
# >> {:ok, 20}
parse("twenty-two", number) |> IO.inspect
# >> {:ok, 22}
parse("seventy-seven", number) |> IO.inspect
# >> {:ok, 77}
parse("one hundred", number) |> IO.inspect
# >> {:ok, 100}
parse("one hundred twenty", number) |> IO.inspect
# >> {:ok, 120}
parse("one hundred and twenty", number) |> IO.inspect
# >> {:ok, 120}
parse("one hundred and twenty-two", number) |> IO.inspect
# >> {:ok, 122}
parse("one hundred and twenty three", number) |> IO.inspect
# >> {:ok, 123}
parse("twelve hundred and twenty-two", number) |> IO.inspect
# >> {:ok, 1222}
parse("one thousand", number) |> IO.inspect
# >> {:ok, 1000}
parse("twenty thousand", number) |> IO.inspect
# >> {:ok, 20000}
parse("twenty-two thousand", number) |> IO.inspect
# >> {:ok, 22000}
parse("one hundred thousand", number) |> IO.inspect
# >> {:ok, 100000}
parse("twelve hundred and twenty-two thousand", number) |> IO.inspect
# >> {:ok, 1222000}
parse("one hundred and twenty three million", number) |> IO.inspect
# >> {:ok, 123000000}
parse("one hundred and twenty three million and three", number) |> IO.inspect
# >> {:ok, 123000003}
parse("seventy-seven thousand eight hundred and nineteen", number) |> IO.inspect
# >> {:ok, 77819}
parse("seven hundred seventy-seven thousand seven hundred and seventy-seven", number) |> IO.inspect
# >> {:ok, 777777}
