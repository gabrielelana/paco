defprotocol Paco.Parsable do
  @moduledoc """
  A protocol that converts terms into Paco parsers
  """

  @fallback_to_any true

  @doc """
  Returns a parser that is able to parse `t` and to keep the shape of `t`
  """
  @spec to_parser(t) :: Paco.Parser.t
  def to_parser(t)
end

defimpl Paco.Parsable, for: BitString do
  import Paco.Parser
  def to_parser(s) when is_binary(s) do
    lit(s)
  end
  def to_parser(s) do
    raise Protocol.UndefinedError, protocol: @protocol, value: s
  end
end

defimpl Paco.Parsable, for: Atom do
  import Paco.Parser
  def to_parser(a) do
    lit(Atom.to_string(a))
    |> bind(&String.to_atom/1)
  end
end

defimpl Paco.Parsable, for: Tuple do
  import Paco.Parser
  def to_parser(tuple) do
    sequence_of(Tuple.to_list(tuple))
    |> bind(&List.to_tuple/1)
  end
end

defimpl Paco.Parsable, for: List do
  import Paco.Parser
  def to_parser(list) do
    if Inspect.List.keyword? list do
      to_parser_for_keyword(list)
    else
      to_parser_for_list(list)
    end
  end

  defp to_parser_for_keyword(list) do
    {keys, values} = {Keyword.keys(list), Keyword.values(list)}
    sequence_of(values)
    |> bind(&(Enum.zip(keys, &1) |> Enum.into(Keyword.new)))
  end

  defp to_parser_for_list(list) do
    sequence_of(list)
  end
end

# defimpl Paco.Parsable, for: Map do
#   import Paco.Parser
#   def to_parser(map) do
#     {keys, values} = {Map.keys(map), Map.values(map)}
#     sequence_of(values)
#     |> bind(&(Enum.zip(keys, &1) |> Enum.into(Map.new)))
#   end
# end

# defimpl Paco.Parsable, for: Any do
#   import Paco.Parser
#   def to_parser(%{__struct__: name} = struct) do
#     map = Map.delete(struct, :__struct__)
#     Paco.Parsable.Map.to_parser(map)
#     |> bind(&Map.put(&1, :__struct__, name))
#   end

#   def to_parser(term) do
#     raise Protocol.UndefinedError, protocol: @protocol, value: term
#   end
# end
