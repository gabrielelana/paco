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


parse(number, "one") |> IO.inspect
# >> {:ok, 1}
parse(number, "twenty") |> IO.inspect
# >> {:ok, 20}
parse(number, "twenty-two") |> IO.inspect
# >> {:ok, 22}
parse(number, "seventy-seven") |> IO.inspect
# >> {:ok, 77}
parse(number, "one hundred") |> IO.inspect
# >> {:ok, 100}
parse(number, "one hundred twenty") |> IO.inspect
# >> {:ok, 120}
parse(number, "one hundred and twenty") |> IO.inspect
# >> {:ok, 120}
parse(number, "one hundred and twenty-two") |> IO.inspect
# >> {:ok, 122}
parse(number, "one hundred and twenty three") |> IO.inspect
# >> {:ok, 123}
parse(number, "twelve hundred and twenty-two") |> IO.inspect
# >> {:ok, 1222}
parse(number, "one thousand") |> IO.inspect
# >> {:ok, 1000}
parse(number, "twenty thousand") |> IO.inspect
# >> {:ok, 20000}
parse(number, "twenty-two thousand") |> IO.inspect
# >> {:ok, 20000}
parse(number, "one hundred thousand") |> IO.inspect
# >> {:ok, 100000}
parse(number, "twelve hundred and twenty-two thousand") |> IO.inspect
# >> {:ok, 1222000}
parse(number, "one hundred and twenty three million") |> IO.inspect
# >> {:ok, 123000000}
parse(number, "one hundred and twenty three million and three") |> IO.inspect
# >> {:ok, 123000003}
parse(number, "seventy-seven thousand eight hundred and nineteen") |> IO.inspect
# >> {:ok, 77819}
parse(number, "seven hundred seventy-seven thousand seven hundred and seventy-seven") |> IO.inspect
# >> {:ok, 77777}
