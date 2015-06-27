# Grammars that are sensible to indentation (think yaml, python, ecc...) are
# not easy to parse, so this is an example how to do it with Paco

# As an example we are using a subset of http://slim-lang.com/

# Paco has `with_block`: a built-in combinator to parse this kind of grammars


defmodule Slim do
  use Paco
  alias Paco.ASCII
  alias Paco.Predicate

  defmodule Attribute do
    defstruct key: "", value: ""
  end

  defmodule Tag do
    defstruct name: "", attributes: [], children: []
  end

  parser attribute_key, do: while(ASCII.alnum)

  parser attribute_value do
    # will be better with: quoted_by([ASCII.sq, ASCII.dq])
    one_of([until(~s|"|) |> surrounded_by(~s|"|),
            until(~s|'|) |> surrounded_by(~s|'|)])
  end

  parser attribute do
    # will be better with: pair(attribute_key, attribute_value, separated_by: "=")
    [attribute_key, skip(lex("=")), cut, attribute_value]
    |> surrounded_by(maybe(whitespaces))
    |> bind(&map_attribute/1)
  end

  parser attributes, do: many(attribute)

  parser text do
    until(ASCII.nl, eof: true)
    |> preceded_by(maybe(lex("|")))
    |> only_if(Predicate.not_empty?)
  end

  parser tag do
    [while(ASCII.alnum, at_least: 1), attributes, maybe(text)]
    |> within(line)
    |> bind(&map_tag/1)
    |> with_block(tags)
    |> bind(&map_block/1)
  end

  parser tags, do: one_or_more(one_of([tag, text]))



  defp map_attribute([key, value]),
    do: %Attribute{key: key, value: value}

  defp map_tag([name, attributes]),
    do: %Tag{name: name, attributes: attributes}
  defp map_tag([name, attributes, text]),
    do: %Tag{name: name, attributes: attributes, children: [text]}

  defp map_block(%Tag{} = tag), do: tag
  defp map_block({%Tag{children: children} = tag, text}) when is_binary(text),
    do: %Tag{tag|children: children ++ [text]}
  defp map_block({%Tag{children: children} = tag, tags}),
    do: %Tag{tag|children: children ++ tags}
end


# parser attribute do
#   [attribute_key, skip(lex("=")), cut, attribute_value]
#   |> surrounded_by(maybe(whitespaces))
#   |> bind(&map_attribute/1)
# end

# lex("=") and surrounded_by(maybe(whitespaces)) are there to get rid of
# meaningless white spaces
Paco.parse(Slim.attribute, ~s|id="headline"|) |> IO.inspect
# >> {:ok, %Slim.Attribute{key: "id", value: "headline"}}
Paco.parse(Slim.attribute, ~s|id = "headline"|) |> IO.inspect
# >> {:ok, %Slim.Attribute{key: "id", value: "headline"}}
Paco.parse(Slim.attribute, ~s|  id = "headline"  |) |> IO.inspect
# >> {:ok, %Slim.Attribute{key: "id", value: "headline"}}
Paco.parse(Slim.attribute, ~s|id = 'headline'|) |> IO.inspect
# >> {:ok, %Slim.Attribute{key: "id", value: "headline"}}

# The cut does its job giving meaningful error messages
Paco.parse(Slim.attribute, ~s|id=|) |> IO.inspect
# >> {:error,
# >>  "expected one of [\"\"\", \"'\"] (attribute_value < attribute) at 1:4 but got the end of input"}


# parser attributes, do: many(attribute)

Paco.parse(Slim.attributes, ~s|id="headline" class="headline"|) |> IO.inspect
# >> {:ok,
# >>  [%Slim.Attribute{key: "id", value: "headline"},
# >>   %Slim.Attribute{key: "class", value: "headline"}]}


# parser tag do
#   [while(ASCII.alnum, at_least: 1), attributes, maybe(text)]
#   |> within(line)
#   |> bind(&map_tag/1)
#   ... omitted part not relevant for now
# end

# `within(line)` forces the tag to be a single line, `line` combinator could be
# configured to recognize escape characters to continue the logical line on
# multiple physical lines
Paco.parse(Slim.tag, ~s|div id="headline" class="headline"|) |> IO.inspect
# >> {:ok,
# >>  %Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "headline"},
# >>    %Slim.Attribute{key: "class", value: "headline"}], children: [],
# >>   name: "div"}}

# `maybe(text)` since `text` will fail with an empty string, we could avoid to
# always add an empty text child to every tag
Paco.parse(Slim.tag, ~s|div id="headline" class="headline" Text|) |> IO.inspect
# >> {:ok,
# >>  %Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "headline"},
# >>    %Slim.Attribute{key: "class", value: "headline"}], children: ["Text"],
# >>   name: "div"}}


# parser tags, do: one_or_more(one_of([tag, text]))

"""
h1 id="headline"
h1 id="body"
h1 id="footer"
"""
|> Slim.parse |> IO.inspect
# >> {:ok,
# >>  [%Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "headline"}],
# >>    children: [], name: "h1"},
# >>   %Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "body"}],
# >>    children: [], name: "h1"},
# >>   %Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "footer"}],
# >>    children: [], name: "h1"}]}


# parser tag do
#   [while(ASCII.alnum, at_least: 1), attributes, maybe(text)]
#   |> within(line)
#   |> bind(&map_tag/1)
#   |> with_block(tags)
#   |> bind(&map_block/1)
# end

# Here the magic of `with_block`, until now we had:
# 1 - parse a tag on a single line
# 2 - map the result to a %Slim.Tag structure

# `with_block` will combine the result of the parser passed as the first argument
# (tag) with the result of the parser passed as a second argument (tags). The
# difference is that the second parser is applied only to the following block
# of text which is more indented compared to what was matched by the first
# parser. Moreover, the indentation is removed from the block so for the second
# parser (tags) could be ignorant about the indententation

"""
body
  | This is text in body
  h1 id="1"
    | This is text in h1 1
  h1 id="2"
    h2 id="3" This is text in h2 3
"""
|> Slim.parse |> IO.inspect
# >> {:ok,
# >>  [%Slim.Tag{attributes: [],
# >>   children: ["This is text in body",
# >>    %Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "1"}],
# >>     children: ["This is text in h1 1"], name: "h1"},
# >>    %Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "2"}],
# >>     children: [%Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "3"}],
# >>       children: ["This is text in h2 3"], name: "h2"}], name: "h1"}],
# >>   name: "body"}]}
