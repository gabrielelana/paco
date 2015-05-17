defmodule Paco.ExplainTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser
  import Paco.Explainer

  test "report parser matched on a single line" do
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

  test "report parser matched on multiple lines" do
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

  test "report parser failed" do
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

  test "report parser matched one character outside of the visible line" do
    events = [
      {:loaded, "a\n"},
      {:started, "eol"},
      {:matched, {1, 1, 2}, {1, 1, 2}, {2, 1, 3}}
    ]
    assert report(events) ==
      """
      Matched eol from 1:2 to 1:2
      1: a
          ^
      """
  end

  test "report parser matched without consuming any input (empty match)" do
    events = [
      {:loaded, "a"},
      {:started, "empty"},
      {:matched, {0, 1, 1}, {0, 1, 1}, {0, 1, 1}}
    ]
    assert report(events) ==
      """
      Matched empty from 1:1 to 1:1
      1: a
         ~
      """
  end

  test "report parser with few children" do
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

  test "report parsers deeply nested" do
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
    assert explain(sequence_of([lit("aaa"), lit("bbb")]), "aaabbb") == {:ok,
      """
      Matched sequence_of#3([lit#1, lit#2]) from 1:1 to 1:6
      1: aaabbb
         ^    ^
      └─ Matched lit#1("aaa") from 1:1 to 1:3
         1: aaabbb
            ^ ^
      └─ Matched lit#2("bbb") from 1:4 to 1:6
         1: aaabbb
               ^ ^
      """}
  end

  test "explain success that didn't consume any text" do
    assert explain(lit(""), "aaa") == {:ok,
      """
      Matched lit#1("") from 1:1 to 1:1
      1: aaa
         ~
      """}
    assert explain(sequence_of([lit("")]), "aaa") == {:ok,
      """
      Matched sequence_of#3([lit#2]) from 1:1 to 1:1
      1: aaa
         ~
      └─ Matched lit#2("") from 1:1 to 1:1
         1: aaa
            ~
      """}
    assert explain(sequence_of([lit("a")]), "aaa") == {:ok,
      """
      Matched sequence_of#5([lit#4]) from 1:1 to 1:1
      1: aaa
         ^
      └─ Matched lit#4("a") from 1:1 to 1:1
         1: aaa
            ^
      """}
    assert explain(sequence_of([lit("a"), lit("")]), "aaa") == {:ok,
      """
      Matched sequence_of#8([lit#6, lit#7]) from 1:1 to 1:2
      1: aaa
         ^~
      └─ Matched lit#6("a") from 1:1 to 1:1
         1: aaa
            ^
      └─ Matched lit#7("") from 1:2 to 1:2
         1: aaa
             ~
      """}
  end

  test "explain success on multiple lines" do
    assert explain(sequence_of([lit("aaa"), lit("\n"), lit("bbb")]), "aaa\nbbb") == {:ok,
      """
      Matched sequence_of#4([lit#1, lit#2, lit#3]) from 1:1 to 2:3
      1: aaa
         ^
      2: bbb
           ^
      └─ Matched lit#1("aaa") from 1:1 to 1:3
         1: aaa
            ^ ^
      └─ Matched lit#2("\\n") from 1:4 to 1:4
         1: aaa
               ^
      └─ Matched lit#3("bbb") from 2:1 to 2:3
         2: bbb
            ^ ^
      """}
  end

  test "explain failure" do
    assert explain(sequence_of([lit("aaa"), lit("bbb")]), "aaaccc") == {:ok,
      """
      Failed to match sequence_of#3([lit#1, lit#2]) at 1:1
      1: aaaccc
         ^
      └─ Matched lit#1("aaa") from 1:1 to 1:3
         1: aaaccc
            ^ ^
      └─ Failed to match lit#2("bbb") at 1:4
         1: aaaccc
               ^
      """}
  end

  test "explain failure on empty lit" do
    assert explain(lit("aaa"), "") == {:ok,
      """
      Failed to match lit#1("aaa") at 1:1
      1:
         ^
      """}
  end
end
