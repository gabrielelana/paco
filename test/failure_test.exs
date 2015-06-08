defmodule Paco.FailureTest do
  use ExUnit.Case, async: true

  test "compose expectations" do
    {at, tail, rank} = {{1, 1, 2}, "c", 2}
    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b"}])

    assert composed_failure.at == at
    assert composed_failure.tail == tail
    assert composed_failure.rank == rank
    assert composed_failure.expected == {:composed, ["a", "b"]}
  end

  test "compose can compose composed failures" do
    {at, tail, rank} = {{1, 1, 2}, "z", 2}
    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b"}])

    composed_failure = Paco.Failure.compose([
      composed_failure,
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "c"}])

    assert composed_failure.expected == {:composed, ["a", "b", "c"]}

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "d"},
      composed_failure])

    assert composed_failure.expected == {:composed, ["d", "a", "b", "c"]}
  end

  test "format composed expectations" do
    {at, tail, rank} = {{1, 1, 2}, "c", 2}
    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b"}])

    assert Paco.Failure.format(composed_failure, :flat) ==
           ~s|expected one of ["a", "b"] at 1:2 but got "c"|
  end

  test "compose keep the common stack" do
    {at, tail, rank} = {{1, 1, 2}, "c", 2}
    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a", stack: ["A", "COMMON"]},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b", stack: ["B", "COMMON"]}])
    assert composed_failure.stack == ["COMMON"]

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a", stack: ["COMMON"]},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b", stack: ["B", "COMMON"]}])
    assert composed_failure.stack == ["COMMON"]

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a", stack: ["A", "COMMON"]},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b", stack: ["COMMON"]}])
    assert composed_failure.stack == ["COMMON"]
  end

  # test "format without reason" do
  #   failure = %Paco.Failure{at: {0,1,1}, what: "p"}
  #   assert Paco.Failure.format(failure, :flat) ==
  #     """
  #     Failed to match p at 1:1
  #     """
  # end

  # test "format with another failure as reason" do
  #   reason = %Paco.Failure{at: {0,1,1}, what: "p2"}
  #   failure = %Paco.Failure{at: {0,1,1}, what: "p1", because: reason}
  #   assert Paco.Failure.format(failure, :flat) ==
  #     """
  #     Failed to match p1 at 1:1, because it failed to match p2 at 1:1
  #     """
  # end

  # test "format with a message as reason" do
  #   failure = %Paco.Failure{at: {0,1,1}, what: "p", because: "is a test"}
  #   assert Paco.Failure.format(failure, :flat) ==
  #     """
  #     Failed to match p at 1:1, because it is a test
  #     """
  # end
end
