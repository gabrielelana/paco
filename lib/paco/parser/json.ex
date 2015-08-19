defmodule Paco.Parser.JSON do
  alias Paco.ASCII
  use Paco

  root parser all, do: one_of([object, array])

  parser object do
    pair(string, value, separated_by: colon)
    |> separated_by(comma)
    |> surrounded_by(open_curly_bracket, close_curly_bracket)
    |> bind(&to_map/1)
  end

  parser array do
    value
    |> separated_by(comma)
    |> surrounded_by(open_square_bracket, close_square_bracket)
  end

  parser value do
    one_of([
      string,
      number,
      object,
      array,
      literal_true,
      literal_false,
      literal_null])
  end

  parser string do
    between(ASCII.double_quotes, escaped_with: "\\", strip: false)
    |> bind(&replace_escapes_in_string/1)
  end

  parser number do
    [ number_sign,
      number_integer_part,
      number_fractional_part,
      number_exponential_part]
    |> bind(&to_number/1)
  end

  parser number_sign, do: "-" |> replace_with(-1) |> maybe(default: 1)
  parser number_integer_part, do: one_of([number_zero, number_non_zero])
  parser number_zero, do: "0" |> replace_with(0)
  parser number_non_zero, do: [ while("123456789", exactly: 1),
                                while("0123456789")]
                              |> join
                              |> bind(&String.to_integer/1)
  parser number_fractional_part, do: while("0123456789", at_least: 1)
                                     |> preceded_by(".")
                                     |> maybe(default: "0")
                                     |> bind(&String.to_integer/1)
  parser number_exponential_part, do: [ skip(while("eE", exactly: 1)),
                                        maybe(while("+-", exactly: 1), default: "+"),
                                        while("0123456789", at_least: 1)]
                                      |> join
                                      |> maybe(default: "0")
                                      |> bind(&String.to_integer/1)

  parser literal_true, do: lit("true") |> replace_with(true)
  parser literal_false, do: lit("false") |> replace_with(false)
  parser literal_null, do: lit("null") |> replace_with(nil)

  parser comma, do: "," |> surrounded_by(wss?)
  parser colon, do: ":" |> surrounded_by(wss?)
  parser open_curly_bracket, do: "{" |> surrounded_by(wss?)
  parser close_curly_bracket, do: "}" |> surrounded_by(wss?)
  parser open_square_bracket, do: "[" |> surrounded_by(wss?)
  parser close_square_bracket, do: "]" |> surrounded_by(wss?)


  defp to_map(kvs) do
    for {k, v} <- kvs, into: %{}, do: {k, v}
  end

  defp replace_escapes_in_string(s) do
    Regex.replace(~r/(?:\\u([0-9a-fA-F]{4})|\\([\\\/bfnrt]))/, s,
      fn(_, u, "") -> <<String.to_integer(u, 16)::utf8>>
        (_, _, "\\") -> "\\"
        (_, _, "/") -> "/"
        (_, _, "b") -> "\b"
        (_, _, "f") -> "\f"
        (_, _, "n") -> "\n"
        (_, _, "r") -> "\r"
        (_, _, "t") -> "\t"
      end)
  end

  defp to_number([sign, integer, 0, exponent]) do
    exponent = :math.pow(10, exponent)
    (integer + 0) * sign * exponent
  end
  defp to_number([sign, integer, fraction, exponent]) do
    digits = Float.floor(:math.log10(fraction)) + 1
    fraction = fraction / :math.pow(10, digits)
    exponent = :math.pow(10, exponent)
    (integer + fraction) * sign * exponent
  end
end
