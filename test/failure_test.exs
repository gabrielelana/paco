defmodule Paco.FailureTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, %{failure: %Paco.Failure{at: {0, 1, 1}, rank: 1}}}
  end

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

  test "format failure on the end of input", %{failure: failure} do
    failure = %Paco.Failure{failure|tail: "", expected: "a"}
    assert Paco.Failure.format(failure, :flat) ==
      ~s|expected "a" at 1:1 but got the end of input|
  end
end
