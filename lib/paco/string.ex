defmodule Paco.String do
  import String
  alias Paco.State

  @nl ["\x{000A}",         # LINE FEED
       "\x{000B}",         # LINE TABULATION
       "\x{000C}",         # FORM FEED
       "\x{000D}",         # CARRIAGE RETURN
       "\x{000D}\x{000A}", # CARRIAGE RETURN + LINE FEED
       "\x{0085}",         # NEXT LINE
       "\x{2028}",         # LINE SEPARATOR
       "\x{2029}"]         # PARAGRAPH SEPARATOR

  for nl <- @nl do
    def newline?(<<unquote(nl)>>), do: true
  end
  def newline?(_), do: false


  @ws ["\x{0009}",         # CHARACTER TABULATION
       "\x{000A}",         # LINE FEED
       "\x{000B}",         # LINE TABULATION
       "\x{000C}",         # FORM FEED
       "\x{000D}",         # CARRIAGE RETURN
       "\x{000D}\x{000A}", # CARRIAGE RETURN + LINE FEED
       "\x{0020}",         # SPACE
       "\x{0085}",         # NEXT LINE
       "\x{00A0}",         # NO-BREAK SPACE
       "\x{1680}",         # OGHAM SPACE MARK
       "\x{2000}",         # EN QUAD
       "\x{2001}",         # EM QUAD
       "\x{2002}",         # EN SPACE
       "\x{2003}",         # EM SPACE
       "\x{2004}",         # THREE-PER-EM SPACE
       "\x{2005}",         # FOUR-PER-EM SPACE
       "\x{2006}",         # SIX-PER-EM SPACE
       "\x{2007}",         # FIGURE SPACE
       "\x{2008}",         # PUNCTUATION SPACE
       "\x{2009}",         # THIN SPACE
       "\x{200A}",         # HAIR SPACE
       "\x{2028}",         # LINE SEPARATOR
       "\x{2029}",         # PARAGRAPH SEPARATOR
       "\x{202F}",         # NARROW NO-BREAK SPACE
       "\x{205F}",         # MEDIUM MATHEMATICAL SPACE
       "\x{3000}",         # IDEOGRAPHIC SPACE
       "\x{180E}",         # MONGOLIAN VOWEL SEPARATOR
       "\x{200B}",         # ZERO WIDTH SPACE
       "\x{200C}",         # ZERO WIDTH NON-JOINER
       "\x{200D}",         # ZERO WIDTH JOINER
       "\x{2060}",         # WORD JOINER
       "\x{FEFF}"]         # ZERO WIDTH NON-BREAKING SPACE

  for ws <- @ws do
    def whitespace?(<<unquote(ws)>>), do: true
  end
  def whitespace?(_), do: false


  @letters ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","W","X","Y","Z",
            "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","w","x","y","z"]
  for letter <- @letters do
    def letter?(<<unquote(letter)>>), do: true
  end
  def letter?(_), do: false


  def consume(text, expected, at), do: consume(text, expected, at, at)

  defp consume(text, "", to, at), do: {text, to, at}
  defp consume("", _, _, _), do: :end_of_input
  defp consume(text, expected, _to, at) do
    {h1, t1} = next_grapheme(text)
    {h2, t2} = next_grapheme(expected)
    case {h1, h2} do
      {h, h} -> consume(t1, t2, at, position_after(at, h))
      _ -> :error
    end
  end


  def consume_any(text, what, at), do: consume_any(text, "", what, at, at)

  defp consume_any(text, consumed, 0, to, at), do: {consumed, text, to, at}
  defp consume_any(text, consumed, n, _to, at) when is_number(n) and n > 0 do
    case next_grapheme(text) do
      {h, tail} ->
        consume_any(tail, consumed <> h, n - 1, at, position_after(at, h))
      nil ->
        :end_of_input
    end
  end

  @typep limit :: exactly::non_neg_integer | {at_least::non_neg_integer, at_most::non_neg_integer}

  @spec consume_while(String.t, what, limits::limit, State.position)
    :: {consumed::String.t, tail::String.t, to::State.position, at::State.position}
     | {:not_expected, consumed::String.t, tail::String.t, to::State.position, at::State.position}
     | {:not_enough, consumed::String.t, tail::String.t, to::State.position, at::State.position}
    when what: String.t | (String.t -> boolean)

  def consume_while(text, what, {at_least, at_most}, at),
      do: consume_while(text, "", what, {at_least, at_most, 0}, at, at)
  def consume_while(text, what, n, at),
      do: consume_while(text, "", what, {n, n, 0}, at, at)

  def consume_while(text, what, at),
      do: consume_while(text, "", what, {0, :infinity, 0}, at, at)

  defp consume_while(text, consumed, what, limits, at, at) when is_binary(what) do
    expected = Stream.unfold(what, &next_grapheme/1) |> Enum.to_list
    f = fn(h) -> Enum.any?(expected, &(&1 == h)) end
    consume_while(text, consumed, f, limits, at, at)
  end

  defp consume_while(text, consumed, f, {at_least, at_most, n}, to, at) when is_function(f) do
    case next_grapheme(text) do
      {h, tail} ->
        case f.(h) do
          true when n+1 == at_most ->
            {consumed <> h, tail, at, position_after(at, h)}
          true ->
            consume_while(tail, consumed <> h, f, {at_least, at_most, n+1}, at, position_after(at, h))
          false when n < at_least ->
            {:not_enough, consumed, text, to, at}
          false ->
            {consumed, text, to, at}
        end
      nil when n < at_least ->
        {:not_enough, consumed, text, to, at}
      nil ->
        {consumed, text, to, at}
    end
  end






  def consume_until(text, what, at), do: consume_until(text, "", what, at, at)

  defp consume_until(text, consumed, f, to, at) when is_function(f) do
    case next_grapheme(text) do
      {h, tail} ->
        if (f.(h)) do
          {consumed, text, to, at}
        else
          consume_until(tail, consumed <> h, f, at, position_after(at, h))
        end
      nil ->
        {consumed, text, to, at}
    end
  end
  defp consume_until(text, consumed, {boundary, escape}, to, at) do
    next = &consume_until_boundary_with_escape(&1, &2, boundary, escape, &3, &4, &5)
    consume_until_boundary_with_escape(text, consumed, boundary, escape, to, at, next)
  end
  defp consume_until(text, consumed, boundary, to, at) do
    next = &consume_until_boundary(&1, &2, boundary, &3, &4, &5)
    consume_until_boundary(text, consumed, boundary, to, at, next)
  end

  defp consume_until_boundary(text, consumed, boundary, to, at, next) do
    case consume(text, boundary, to, at) do
      {_, _, _} ->
        {consumed, text, to, at}
      :error ->
        {h, tail} = next_grapheme(text)
        next.(tail, consumed <> h, at, position_after(at, h), next)
      :end_of_input ->
        {consumed, text, to, at}
    end
  end

  defp consume_until_boundary_with_escape(text, consumed, boundary, escape, to, at, next) do
    case consume(text, escape <> boundary, to, at) do
      {tail, to, at} ->
        consume_until_boundary_with_escape(tail, consumed <> escape <> boundary, boundary, escape, to, at, next)
      _ ->
        consume_until_boundary(text, consumed, boundary, to, at, next)
    end
  end


  def seek(text, at, len), do: seek(text, "", at, at, len)

  defp seek(text, seeked, to, at, 0), do: {seeked, text, to, at}
  defp seek("", seeked, to, at, _), do: {seeked, "", to, at}
  defp seek(text, seeked, _, at, len) do
    {h, tail} = next_grapheme(text)
    seek(tail, seeked <> h, at, position_after(at, h), len-1)
  end

  def line_at(text, at) do
    case String.at(text, at) do
      nil ->
        case String.length(text) do
          0 -> ""
          n -> line_at(text, n - 1)
        end
      grapheme ->
        if (newline?(grapheme)) do
          collect_line_at(text, at - 1, &(&1 - 1))
          |> Enum.reverse
          |> Enum.join
        else
          collect_line_at(text, at - 1, &(&1 - 1))
          |> Enum.reverse
          |> Enum.concat([grapheme])
          |> Enum.concat(collect_line_at(text, at + 1, &(&1 + 1)))
          |> Enum.join
        end
    end
  end

  defp collect_line_at(text, at, next) do
    Stream.unfold(at, &collect_line_at_(text, &1, next)) |> Enum.to_list
  end

  defp collect_line_at_(_text, at, _next) when at < 0, do: nil
  defp collect_line_at_(text, at, next) do
    case String.at(text, at) do
      nil ->
        nil
      in_line ->
        if newline?(in_line) do
          nil
        else
          {in_line, next.(at)}
        end
    end
  end

  defp position_after({n, l, c}, grapheme) do
    if newline?(grapheme) do
      {n + 1, l + 1, 1}
    else
      {n + 1, l, c + 1}
    end
  end
end
