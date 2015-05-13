defmodule Paco.ExplainTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser
  import Paco.Explainer

  test "report single parser matched on a single line" do
    events = [
      {:loaded, "aaabbb"},
      {:started, "p1"},
      {:matched, {0, 1, 1}, {5, 1, 6}, {6, 1, 7}}
    ]
    assert report(events) ==
      """
      Matched p1 from 1:1 to 1:6
      1> aaabbb
         ^    ^
      """
  end

  test "report single parser matched on multiple lines" do
    events = [
      {:loaded, "aaa\nbbb"},
      {:started, "p1"},
      {:matched, {0, 1, 1}, {6, 2, 3}, {7, 2, 4}}
    ]
    assert report(events) ==
      """
      Matched p1 from 1:1 to 2:3
      1> aaa
         ^
      2> bbb
           ^
      """
  end

  test "report single parser failed" do
    events = [
      {:loaded, "aaabbb"},
      {:started, "p1"},
      {:failed, {0, 1, 1}}
    ]
    assert report(events) ==
      """
      Failed to match p1 at 1:1
      1> aaabbb
         ^
      """
  end

  test "report matched one character outside of the visible line" do
    events = [
      {:loaded, "\n"},
      {:started, "nl"},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 2, 2}}
    ]
    assert report(events) ==
      """
      Matched nl from 1:1 to 1:1
      1>
         ^
      """
  end

  test "report matched without consuming any input (empty match)" do
    events = [
      {:loaded, ""},
      {:started, "string()"},
      {:matched, {0, 1, 1}, {0, 1, 1}, {0, 1, 1}}
    ]
    assert report(events) ==
      """
      Matched string() from 1:1 to 1:1
      1>
         ~
      """
  end

  test "report multiple parsers match on multiple lines" do
    events = [
      {:loaded, "aaa\nbbb"},
      {:started, "aaabbb"},
      {:started, "aaa"},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
      {:started, "nl"},
      {:matched, {3, 1, 4}, {3, 1, 4}, {4, 2, 1}},
      {:started, "bbb"},
      {:matched, {4, 2, 1}, {6, 2, 3}, {7, 3, 4}},
      {:matched, {0, 1, 1}, {6, 2, 3}, {7, 3, 4}},
    ]
    assert report(events) ==
      """
      Matched aaabbb from 1:1 to 2:3
      1> aaa
         ^
      2> bbb
           ^
      └─ Matched aaa from 1:1 to 1:3
         1> aaa
            ^ ^
      └─ Matched nl from 1:4 to 1:4
         1> aaa
               ^
      └─ Matched bbb from 2:1 to 2:3
         2> bbb
            ^ ^
      """
  end

  test "report deeply nested" do
    events = [
      {:loaded, "abcd"},
      {:started, "abcd"},
      {:started, "bcd"},
      {:started, "cd"},
      {:started, "d"},
      {:matched, {3, 1, 4}, {3, 1, 4}, {4, 1, 5}},
      {:matched, {2, 1, 3}, {3, 1, 4}, {4, 1, 5}},
      {:matched, {1, 1, 2}, {3, 1, 4}, {4, 1, 5}},
      {:matched, {0, 1, 1}, {3, 1, 4}, {4, 1, 5}},
    ]
    assert report(events) ==
      """
      Matched abcd from 1:1 to 1:4
      1> abcd
         ^  ^
      └─ Matched bcd from 1:2 to 1:4
         1> abcd
             ^ ^
         └─ Matched cd from 1:3 to 1:4
            1> abcd
                 ^^
            └─ Matched d from 1:4 to 1:4
               1> abcd
                     ^
      """
  end

  test "explain success" do
    assert explain(seq([string("aaa"), string("bbb")]), "aaabbb") == {:ok,
      """
      Matched seq([string(aaa), string(bbb)]) from 1:1 to 1:6
      1> aaabbb
         ^    ^
      └─ Matched string(aaa) from 1:1 to 1:3
         1> aaabbb
            ^ ^
      └─ Matched string(bbb) from 1:4 to 1:6
         1> aaabbb
               ^ ^
      """}
  end

  test "explain success that didn't consume any text" do
    assert explain(string(""), "aaabbb") == {:ok,
      """
      Matched string() from 1:1 to 1:1
      1> aaabbb
         ~
      """}
    assert explain(seq([string("")]), "aaabbb") == {:ok,
      """
      Matched seq([string()]) from 1:1 to 1:1
      1> aaabbb
         ~
      └─ Matched string() from 1:1 to 1:1
         1> aaabbb
            ~
      """}
    assert explain(seq([string("a")]), "aaabbb") == {:ok,
      """
      Matched seq([string(a)]) from 1:1 to 1:1
      1> aaabbb
         ^
      └─ Matched string(a) from 1:1 to 1:1
         1> aaabbb
            ^
      """}
    assert explain(seq([string("a"), string("")]), "aaabbb") == {:ok,
      """
      Matched seq([string(a), string()]) from 1:1 to 1:2
      1> aaabbb
         ^~
      └─ Matched string(a) from 1:1 to 1:1
         1> aaabbb
            ^
      └─ Matched string() from 1:2 to 1:2
         1> aaabbb
             ~
      """}
  end

  test "explain success on multiple lines" do
    assert explain(seq([string("aaa"), string("\n"), string("bbb")]), "aaa\nbbb") == {:ok,
      """
      Matched seq([string(aaa), string(\\n), string(bbb)]) from 1:1 to 2:3
      1> aaa
         ^
      2> bbb
           ^
      └─ Matched string(aaa) from 1:1 to 1:3
         1> aaa
            ^ ^
      └─ Matched string(\\n) from 1:4 to 1:4
         1> aaa
               ^
      └─ Matched string(bbb) from 2:1 to 2:3
         2> bbb
            ^ ^
      """}
  end

  test "explain failure" do
    assert explain(seq([string("aaa"), string("bbb")]), "aaaccc") == {:ok,
      """
      Failed to match seq([string(aaa), string(bbb)]) at 1:1
      1> aaaccc
         ^
      └─ Matched string(aaa) from 1:1 to 1:3
         1> aaaccc
            ^ ^
      └─ Failed to match string(bbb) at 1:4
         1> aaaccc
               ^
      """}
  end

  test "explain failure on empty string" do
    assert explain(string("aaa"), "") == {:ok,
      """
      Failed to match string(aaa) at 1:1
      1>
         ^
      """}
  end
end

