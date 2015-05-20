defmodule Paco.FailureTest do
  use ExUnit.Case, async: true

  test "format without reason" do
    failure = %Paco.Failure{at: {0,1,1}, what: "p"}
    assert Paco.Failure.format(failure, :flat) ==
      """
      Failed to match p at 1:1
      """
  end

  test "format with another failure as reason" do
    reason = %Paco.Failure{at: {0,1,1}, what: "p2"}
    failure = %Paco.Failure{at: {0,1,1}, what: "p1", because: reason}
    assert Paco.Failure.format(failure, :flat) ==
      """
      Failed to match p1 at 1:1, because it failed to match p2 at 1:1
      """
  end

  test "format with a message as reason" do
    failure = %Paco.Failure{at: {0,1,1}, what: "p", because: "is a test"}
    assert Paco.Failure.format(failure, :flat) ==
      """
      Failed to match p at 1:1, because it is a test
      """
  end
end
