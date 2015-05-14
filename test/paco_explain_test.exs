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
      1: aaabbb
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
      1: aaa
         ^
      2: bbb
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
      1: aaabbb
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
      1:
         ^
      """
  end

  test "report matched without consuming any input (empty match)" do
    events = [
      {:loaded, ""},
      {:started, "literal()"},
      {:matched, {0, 1, 1}, {0, 1, 1}, {0, 1, 1}}
    ]
    assert report(events) ==
      """
      Matched literal() from 1:1 to 1:1
      1:
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
      1: aaa
         ^
      2: bbb
           ^
      └─ Matched aaa from 1:1 to 1:3
         1: aaa
            ^ ^
      └─ Matched nl from 1:4 to 1:4
         1: aaa
               ^
      └─ Matched bbb from 2:1 to 2:3
         2: bbb
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
      1: abcd
         ^  ^
      └─ Matched bcd from 1:2 to 1:4
         1: abcd
             ^ ^
         └─ Matched cd from 1:3 to 1:4
            1: abcd
                 ^^
            └─ Matched d from 1:4 to 1:4
               1: abcd
                     ^
      """
  end

  test "explain success" do
    assert explain(sequence_of([literal("aaa"), literal("bbb")]), "aaabbb") == {:ok,
      """
      Matched sequence_of([literal(aaa), literal(bbb)]) from 1:1 to 1:6
      1: aaabbb
         ^    ^
      └─ Matched literal(aaa) from 1:1 to 1:3
         1: aaabbb
            ^ ^
      └─ Matched literal(bbb) from 1:4 to 1:6
         1: aaabbb
               ^ ^
      """}
  end

  test "explain success that didn't consume any text" do
    assert explain(literal(""), "aaabbb") == {:ok,
      """
      Matched literal() from 1:1 to 1:1
      1: aaabbb
         ~
      """}
    assert explain(sequence_of([literal("")]), "aaabbb") == {:ok,
      """
      Matched sequence_of([literal()]) from 1:1 to 1:1
      1: aaabbb
         ~
      └─ Matched literal() from 1:1 to 1:1
         1: aaabbb
            ~
      """}
    assert explain(sequence_of([literal("a")]), "aaabbb") == {:ok,
      """
      Matched sequence_of([literal(a)]) from 1:1 to 1:1
      1: aaabbb
         ^
      └─ Matched literal(a) from 1:1 to 1:1
         1: aaabbb
            ^
      """}
    assert explain(sequence_of([literal("a"), literal("")]), "aaabbb") == {:ok,
      """
      Matched sequence_of([literal(a), literal()]) from 1:1 to 1:2
      1: aaabbb
         ^~
      └─ Matched literal(a) from 1:1 to 1:1
         1: aaabbb
            ^
      └─ Matched literal() from 1:2 to 1:2
         1: aaabbb
             ~
      """}
  end

  test "explain success on multiple lines" do
    assert explain(sequence_of([literal("aaa"), literal("\n"), literal("bbb")]), "aaa\nbbb") == {:ok,
      """
      Matched sequence_of([literal(aaa), literal(\\n), literal(bbb)]) from 1:1 to 2:3
      1: aaa
         ^
      2: bbb
           ^
      └─ Matched literal(aaa) from 1:1 to 1:3
         1: aaa
            ^ ^
      └─ Matched literal(\\n) from 1:4 to 1:4
         1: aaa
               ^
      └─ Matched literal(bbb) from 2:1 to 2:3
         2: bbb
            ^ ^
      """}
  end

  test "explain failure" do
    assert explain(sequence_of([literal("aaa"), literal("bbb")]), "aaaccc") == {:ok,
      """
      Failed to match sequence_of([literal(aaa), literal(bbb)]) at 1:1
      1: aaaccc
         ^
      └─ Matched literal(aaa) from 1:1 to 1:3
         1: aaaccc
            ^ ^
      └─ Failed to match literal(bbb) at 1:4
         1: aaaccc
               ^
      """}
  end

  test "explain failure on empty literal" do
    assert explain(literal("aaa"), "") == {:ok,
      """
      Failed to match literal(aaa) at 1:1
      1:
         ^
      """}
  end
end

