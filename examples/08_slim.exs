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

  parser attribute_value, do: quoted_by([ASCII.dq, ASCII.sq])

  parser attribute, do: pair(attribute_key, attribute_value, separated_by: "=")
                        |> surrounded_by(while(ASCII.blank))
                        |> bind(&map_attribute/1)

  parser attributes, do: many(attribute)

  parser text, do: rol |> only_if(Predicate.not_empty?)

  parser tag(gap \\ "") do
    line([while(ASCII.alnum, at_least: 1) |> preceded_by(gap),
          attributes,
          maybe(text)])
    |> bind(&map_tag/1)
    |> with_block(&tags/1)
    |> bind(&map_block/1)
  end

  parser tags(gap \\ ""), do: many(tag(gap))


  defp map_attribute({key, value}),
    do: %Attribute{key: key, value: value}

  defp map_tag([name, attributes]),
    do: %Tag{name: name, attributes: attributes}
  defp map_tag([name, attributes, text]),
    do: %Tag{name: name, attributes: attributes, children: [text]}

  defp map_block(%Tag{} = tag), do: tag
  defp map_block({%Tag{children: children} = tag, tags}),
    do: %Tag{tag|children: children ++ tags}
end



# We don't care about meaningless white spaces
Paco.parse(~s|id="headline"|, Slim.attribute) |> IO.inspect
# >> {:ok, %Slim.Attribute{key: "id", value: "headline"}}
Paco.parse(~s|id = "headline"|, Slim.attribute) |> IO.inspect
# >> {:ok, %Slim.Attribute{key: "id", value: "headline"}}
Paco.parse(~s|  id = "headline"  |, Slim.attribute) |> IO.inspect
# >> {:ok, %Slim.Attribute{key: "id", value: "headline"}}
Paco.parse(~s|id = 'headline'|, Slim.attribute) |> IO.inspect
# >> {:ok, %Slim.Attribute{key: "id", value: "headline"}}

# The cut does its job giving meaningful error messages
Paco.parse(~s|id=|, Slim.attribute) |> IO.inspect
# >> {:error,
# >>  "expected one of [\"\"\", \"'\"] (attribute_value < attribute) at 1:4 but got the end of input"}


Paco.parse(~s|id="headline" class="headline"|, Slim.attributes) |> IO.inspect
# >> {:ok,
# >>  [%Slim.Attribute{key: "id", value: "headline"},
# >>   %Slim.Attribute{key: "class", value: "headline"}]}


Paco.parse(~s|div id="headline" class="headline"|, Slim.tag) |> IO.inspect
# >> {:ok,
# >>  %Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "headline"},
# >>    %Slim.Attribute{key: "class", value: "headline"}], children: [],
# >>   name: "div"}}

Paco.parse(~s|div id="headline" class="headline" Text|, Slim.tag) |> IO.inspect
# >> {:ok,
# >>  %Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "headline"},
# >>    %Slim.Attribute{key: "class", value: "headline"}], children: ["Text"],
# >>   name: "div"}}


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


# `with_block` will combine the result of the parser passed as the first argument
# (tag) with the result of the parser passed as a second argument (tags)


"""
body
  h1 id="1"
  h1 id="2"
    h2 id="3"
"""
|> Slim.parse |> IO.inspect
# >> {:ok,
# >>  [%Slim.Tag{attributes: [],
# >>    children: [%Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "1"}],
# >>      children: [], name: "h1"},
# >>     %Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "2"}],
# >>      children: [%Slim.Tag{attributes: [%Slim.Attribute{key: "id", value: "3"}],
# >>        children: [], name: "h2"}], name: "h1"}], name: "body"}]}
