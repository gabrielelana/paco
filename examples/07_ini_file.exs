# INI files are not hard... for an human, it's one of that grammars conceived
# to please humans but to confuse machines and in this case parsers :-)

# The grammar is not well specified, there are as many INI grammars as parsers,
# sometimes comments are allowed after sections or properties and sometimes
# not, sometimes property values could span more than one line and sometimes
# not, you got it...

# Here we are going to pick one of those grammar and parse it with Paco

# This kind of grammars are particularly bad for scanner-less parsers (like
# Paco) because whitespaces and comments can be placed freely and so the risks
# is to pollute the parser with rules to skip comments and whitespaces all over
# the place


# Let's start without comments

defmodule INI1 do
  use Paco

  parser section_header do
    until([{"]", "\\"}, "\n"]) |> surrounded_by("[", "]")
  end

  parser property_name do
    until([{"=", "\\"}, "\n"])
  end

  parser property_value do
    until("\n", escaped_with: "\\") |> followed_by("\n")
  end

  parser property do
    [property_name, skip(lex("=")), property_value]
    |> surrounded_by(maybe(whitespaces))
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
# >> {:ok, [["section1", [["key1", "value1"], ["key2", "value2"]]]]}

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
# >>  [["section1", [["key1", "value1"], ["key2", "value2"]]],
# >>   ["section2", [["key1", "value1"]]], ["section3", [["key1", "value1"]]]]}

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
# >> {:ok, [["section1", [["key1", "value1"]]], ["section2", [["key1", "value1"]]]]}

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
# >> {:ok, [["section1", [["key1", "value1"]]], ["section2", [["key1", "value1"]]]]}

# Empty lines: empty lines are also consumed by `surrounded_by("[", "]")`
"""

[section1]

key1=value1

"""
|> INI1.parse |> IO.inspect
# >> {:ok, [["section1", [["key1", "value1"]]]]}

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
# >>    [["key1", "value1 on the first line\nvalue1 on the second line"],
# >>     ["key2", "value2"]]]]}


# Let's start to consider something that will be required by any decent hand
# made parser: error conditions

# Incomplete section: the `lex` combinator here consumes the end of line of
# line 1 shifting the error reporting to the next line (we will se a solution
# for that in another example), but the error is what you would expect, we were
# expecting the end of the section header
"""
[section1
key1=value1
"""
|> INI1.parse |> IO.inspect
# >> {:error,
# >>  "expected \"]\" (section_header < section < sections) at 2:1 but got \"k\""}

# Incomplete section: nothing to say about that
"""
section1]
"""
|> INI1.parse |> IO.inspect
# >> {:error,
# >>  "expected \"[\" (section_header < section < sections) at 1:1 but got \"s\""}

# Incomplete property: mmm... not good, we successfully parsed someting that is
# wrong, that's because we said that it's fine for a section to be empty, since
# what follows a section is not a valid section content the parser concludes
# that the section ended at line 1. We could use the trick to require the end
# of file at the end (`one_or_more(section) |> followed_by(eof)`) but this
# would not improve much the error message, the parser would say something like
# "expected end of input at 2:1 but got \"v\"", why?
"""
[section1]
value1
"""
|> INI1.parse |> IO.inspect
# >> {:ok, [["section1", []]]}


# TODO: explain cut

defmodule INI2 do
  use Paco

  parser section_header do
    until([{"]", "\\"}, "\n"]) |> surrounded_by("[", "]")
  end

  parser property_name do
    until([{"=", "\\"}, "\n"])
  end

  parser property_value do
    until("\n", escaped_with: "\\") |> followed_by("\n")
  end

  parser property do
    [property_name, cut, skip(lex("=")), property_value]
    |> surrounded_by(maybe(whitespaces))
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
# >> {:error,
# >>  "expected \"=\" (property < section < sections) at 3:1 but got the end of input"}


# TODO: introducing comments

defmodule INI3 do
  use Paco

  parser comment do
    [one_of(["#", ";"]), until("\n")] |> followed_by("\n")
  end

  parser section_header do
    until([{"]", "\\"}, "\n"])
    |> surrounded_by("[", "]")
    |> followed_by(maybe(comment))
  end

  parser property_name do
    until([{"=", "\\"}, "\n"])
  end

  parser property_value do
    until(["\n", "#", ";"], escaped_with: "\\")
    |> followed_by(maybe(comment))
    |> bind(&String.rstrip/1)
  end

  parser property do
    [property_name, cut, skip(lex("=")), property_value]
    |> surrounded_by(maybe(whitespaces))
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
# >> {:ok, [["section1", [["key1 ", "value1"], ["key2 ", "value2"]]]]}


# TODO: What about comments on a whole line

defmodule INI4 do
  use Paco

  parser comment do
    [one_of(["#", ";"]), until("\n")] |> followed_by("\n")
  end

  parser section_header do
    until([{"]", "\\"}, "\n"])
    |> surrounded_by("[", "]")
    |> surrounded_by(maybe(comment))
  end

  parser property_name do
    until([{"=", "\\"}, "\n"])
  end

  parser property_value do
    until(["\n", "#", ";"], escaped_with: "\\")
    |> followed_by(maybe(comment))
    |> bind(&String.rstrip/1)
  end

  parser property do
    [property_name, cut, skip(lex("=")), property_value]
    |> surrounded_by(maybe(whitespaces))
  end

  parser section, do: [section_header, many(one_of([skip(comment), property]))]

  parser sections, do: one_or_more(section)
end


"""
# comment
[section1]
# comment
key1 = value1
# comment
key2 = value2
# comment
"""
|> INI4.parse |> IO.inspect
# >> {:ok, [["section1", [["key1 ", "value1"], ["key2 ", "value2"]]]]}
