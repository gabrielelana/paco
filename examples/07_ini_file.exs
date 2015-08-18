# INI files are not hard... for a human, it's one of those grammars conceived
# to please humans but to confuse machines and in this case parsers :-)

# The grammar is not well specified, there are as many INI grammars as parsers,
# sometimes comments are allowed after sections or properties and sometimes
# they are not, sometimes property values could span more than one line and
# sometimes they could not, you got it...

# Here we are going to pick one of those grammar and parse it with Paco

# This kind of grammars are particularly bad for scanner-less parsers (like
# Paco) because whitespaces and comments can be placed freely and so the risks
# is to pollute the parser with rules to skip comments and whitespaces all over
# the place

# Let's start with a grammar without comments

defmodule INI1 do
  alias Paco.ASCII
  use Paco

  parser section_header do
    until("]", escaped_with: "\\")
    |> surrounded_by(ASCII.square_brackets)
    |> line(skip_empty: true)
  end

  parser property_name do
    while(ASCII.alnum, at_least: 1)
    |> surrounded_by(bls?)
  end

  parser property_value do
    until("\n", escaped_with: "\\")
    |> line(skip_empty: true)
  end

  parser property do
    pair(property_name, property_value, separated_by: "=")
  end

  parser section, do: [section_header, many(property)]

  parser sections, do: one_or_more(section)
end

# One section
"""
[section1]
key1=value1
key2=value2
"""
|> INI1.parse |> IO.inspect
# >> {:ok, [["section1", [{"key1", "value1"}, {"key2", "value2"}]]]}

# Few sections
"""
[section1]
key1=value1
key2=value2
[section2]
key1=value1
[section3]
key1=value1
"""
|> INI1.parse |> IO.inspect
# >> {:ok,
# >>  [["section1", [{"key1", "value1"}, {"key2", "value2"}]],
# >>   ["section2", [{"key1", "value1"}]], ["section3", [{"key1", "value1"}]]]}

# Empty sections: we have `many(property)` so is fine to have empty sections
"""
[section1]
[section2]
"""
|> INI1.parse |> IO.inspect
# >> {:ok, [["section1", []], ["section2", []]]}

# Whitespaces before sections: the section header is `surrounded_by("[", "]")`,
# both delimiters are boxed with `lex` combinators and so they are going to
# consume white spaces before and after section headers
"""
     [section1]
key1=value1
 [section2]
key1=value1
"""
|> INI1.parse |> IO.inspect
# >> {:ok, [["section1", [{"key1", "value1"}]], ["section2", [{"key1", "value1"}]]]}

# Whitespaces before properties: in property rule we have explicitly surrounded
# properties in optional white spaces and so they are consumed and discarded
# (surrounded_by by default skips delimiters in this case white spaces)
"""
[section1]
  key1=value1
[section2]
    key1=value1
"""
|> INI1.parse |> IO.inspect
# >> {:ok, [["section1", [{"key1", "value1"}]], ["section2", [{"key1", "value1"}]]]}

# Empty lines: empty lines are also consumed by `surrounded_by("[", "]")`
"""

[section1]

key1=value1

"""
|> INI1.parse |> IO.inspect
# >> {:ok, [["section1", [{"key1", "value1"}]]]}

# Property values can continue on the next line if escaped: using `until("\n",
# escaped_with: "\\")` we are saying that the property values ends at the end
# of line but the end of line could be escaped with a backslash
"""
[section1]
key1=value1 on the first line\\
value1 on the second line
key2=value2
"""
|> INI1.parse |> IO.inspect
# >> {:ok,
# >>  [["section1",
# >>    [{"key1", "value1 on the first line\nvalue1 on the second line"},
# >>     {"key2", "value2"}]]]}


# Let's start to consider something that will be required by any decent hand
# made parser: error conditions

# Incomplete section: missing square bracket terminator
"""
[section1
key1=value1
"""
|> INI1.parse |> IO.inspect
# >> {:error,
# >>  "expected something ended by \"]\" (section_header < section < sections) at 1:2 but got \"section1\""}

# Incomplete section: missing square bracket at the beginning
"""
section1]
key1=value1
"""
|> INI1.parse |> IO.inspect
# >> {:error,
# >>  "expected \"[\" (section_header < section < sections) at 1:1 but got \"s\""}

# Incomplete property: this will not report an error because we said that a
# section could be empty and what follows is not another section nor a property
# so the parser will happily stop at the end of the section leaving `value1` as a
# trail. We could require to have the end of input after the parsed sections
# but the error message would not improve much, we need to use the `cut`
# combinator
"""
[section1]
value1
"""
|> INI1.parse |> IO.inspect
# >> {:ok, [["section1", []]]}


# `cut` is a combinator that is used to avoid backtracking when we know that
# trying another alternative would be useless. This not only will imporove
# performances but also will improve the error message

# In this case we are going to use the cut after the property name, when a
# property name is successfully parsed then we expect to find an `=` next and
# nothing else.

defmodule INI2 do
  alias Paco.ASCII
  use Paco

  parser section_header do
    until("]", escaped_with: "\\")
    |> surrounded_by(ASCII.square_brackets)
    |> line(skip_empty: true)
  end

  parser property_name do
    while(ASCII.alnum, at_least: 1)
    |> surrounded_by(bls?)
  end

  parser property_value do
    until("\n", escaped_with: "\\")
    |> line(skip_empty: true)
  end

  parser property do
    pair(cut(property_name), property_value, separated_by: "=")
  end

  parser section, do: [section_header, many(property)]

  parser sections, do: one_or_more(section)
end

# Incomplete property
"""
[section1]
value1
"""
|> INI2.parse |> IO.inspect
# >> {:error, "expected \"=\" (property < section < sections) at 2:7 but got \"\n\""}


defmodule INI3 do
  alias Paco.ASCII
  use Paco

  parser comment do
    [one_of(["#", ";"]), rol]
  end

  parser section_header do
    until("]", escaped_with: "\\")
    |> surrounded_by(ASCII.square_brackets)
    |> followed_by(maybe(comment))
    |> line(skip_empty: true)
  end

  parser property_name do
    while(ASCII.alnum, at_least: 1)
    |> surrounded_by(bls?)
  end

  parser property_value do
    until(["\n", "#", ";"], escaped_with: "\\")
    |> followed_by(maybe(comment))
    |> line(skip_empty: true)
  end

  parser property do
    pair(cut(property_name), property_value, separated_by: "=")
  end

  parser section, do: [section_header, many(property)]

  parser sections, do: one_or_more(section)
end


"""
[section1] # comment
key1 = value1 # comment
key2 = value2 # comment
"""
|> INI3.parse |> IO.inspect
# >> {:ok, [["section1", [{"key1", "value1 "}, {"key2", "value2 "}]]]}


# What about comments on a whole line

defmodule INI4 do
  alias Paco.ASCII
  use Paco

  parser comment do
    [one_of(["#", ";"]), rol]
  end

  parser comment_line do
    line(comment)
  end

  parser section_header do
    until("]", escaped_with: "\\")
    |> surrounded_by(ASCII.square_brackets)
    |> followed_by(maybe(comment))
    |> line(skip_empty: true)
  end

  parser property_name do
    while(ASCII.alnum, at_least: 1)
    |> surrounded_by(bls?)
  end

  parser property_value do
    until(["\n", "#", ";"], escaped_with: "\\")
    |> followed_by(maybe(comment))
    |> line(skip_empty: true)
  end

  parser property do
    pair(cut(property_name), property_value, separated_by: "=")
  end

  parser section, do: [section_header, many(one_of([property, skip(comment_line)]))]

  parser sections, do: one_or_more(one_of([section, skip(comment_line)]))

end

"""
# comment
[section1]
# comment
key1=value1
# comment
key2=value2
# comment
"""
|> INI4.parse |> IO.inspect
# >> {:ok, [["section1", [{"key1", "value1"}, {"key2", "value2"}]]]}
