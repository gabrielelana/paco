defmodule Paco.ASCII do

  @newline ["\x{000A}",         # LINE FEED
            "\x{000B}",         # LINE TABULATION
            "\x{000C}",         # FORM FEED
            "\x{000D}\x{000A}", # CARRIAGE RETURN + LINE FEED
            "\x{000D}"]         # CARRIAGE RETURN

  @space ["\x{0009}",         # CHARACTER TABULATION
          "\x{000A}",         # LINE FEED
          "\x{000B}",         # LINE TABULATION
          "\x{000C}",         # FORM FEED
          "\x{000D}\x{000A}", # CARRIAGE RETURN + LINE FEED
          "\x{000D}",         # CARRIAGE RETURN
          "\x{0020}"]         # SPACE

  @upper ["A","B","C","D","E","F",
          "G","H","I","J","K","L",
          "M","N","O","P","Q","R",
          "S","T","U","V","W","X",
          "Y","Z"]

  @lower ["a","b","c","d","e","f",
          "g","h","i","j","k","l",
          "m","n","o","p","q","r",
          "s","t","u","v","w","x",
          "y","z"]

  @digit ["0","1","2","3","4","5","6","7","8","9"]

  @alpha Enum.concat(@upper, @lower)

  @alnum Enum.concat(@alpha, @digit)

  @blank [" ", "\t"]

  @cntrl 0x00..0x1F
         |> Enum.to_list
         |> Enum.concat([0x7F])
         |> Enum.map(fn(cp) -> <<cp::utf8>> end)

  @graph 0x21..0x7E
         |> Enum.to_list
         |> Enum.map(fn(cp) -> <<cp::utf8>> end)

  @print 0x20..0x7E
         |> Enum.to_list
         |> Enum.map(fn(cp) -> <<cp::utf8>> end)

  @punct ["!", "\"", "#", "$", "%", "&", "'", "(",
          ")", "*", "+", ",", "\\", "-", ".", "/",
          ":", ";", "<", "=", ">", "?", "@", "[",
          "]", "^", "_", "`", "{", "|", "}", "~"]

  @word Enum.concat(@alnum, ["_"])

  @xdigit Enum.concat(@digit, ["a", "b", "c", "d", "e", "f",
                               "A", "B", "C", "D", "E", "F"])

  @classes [{:newline,    :newline?,    @newline},
            {:space,      :space?,      @space},
            {:upper,      :upper?,      @upper},
            {:lower,      :lower?,      @lower},
            {:digit,      :digit?,      @digit},
            {:alpha,      :alpha?,      @alpha},
            {:alnum,      :alnum?,      @alnum},
            {:blank,      :blank?,      @blank},
            {:cntrl,      :cntrl?,      @cntrl},
            {:graph,      :graph?,      @graph},
            {:print,      :print?,      @print},
            {:punct,      :punct?,      @punct},
            {:word,       :word?,       @word},
            {:xdigit,     :xdigit?,     @xdigit},
            # aliases
            {:nl,         :nl?,         @newline},
            {:ws,         :ws?,         @space},
            {:hex,        :hex?,        @xdigit},
            {:letter,     :letter?,     @alpha},
            {:whitespace, :whitespace?, @space},
            {:uppercase,  :uppercase?,  @upper},
            {:upcase,     :upcase?,     @upper},
            {:lowercase,  :lowercase?,  @lower},
            {:downcase,   :downcase?,   @lower},
            {:printable,  :printable?,  @print},
            {:visible,    :visible?,    @graph},
            {:punctuation,:punctuation?,@punct},
            {:control,    :control?,    @cntrl},
          ]

  for {class, is_class, elements} <- @classes do
    def unquote(class)(), do: unquote(elements)
    for element <- elements do
      def unquote(is_class)(<<unquote(element)>>), do: true
    end
    def unquote(is_class)(_), do: false
  end

  def rb, do: {"(", ")"}
  def round_brackets, do: {"(", ")"}

  def sb, do: {"[", "]"}
  def square_brackets, do: {"[", "]"}

  def cb, do: {"{", "}"}
  def curly_brackets, do: {"{", "}"}

  def ab, do: {"<", ">"}
  def angle_brackets, do: {"<", ">"}

  def sq, do: ~s|'|
  def single_quote, do: ~s|'|

  def dq, do: ~s|"|
  def double_quote, do: ~s|"|

  def quotes, do: [sq, dq]
end
