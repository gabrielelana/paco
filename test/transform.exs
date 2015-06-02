defmodule Paco.TransformTest do
  use ExUnit.Case, async: true

  import Paco.Transform

  test :flatten_first do
    assert flatten_first([1]) == [1]
    assert flatten_first([1, 2]) == [1, 2]
    assert flatten_first([[1], 2]) == [1, 2]
    assert flatten_first([1, [2]]) == [1, 2]
    assert flatten_first([[1], [2]]) == [1, 2]
    assert flatten_first([[1], 2, 3]) == [1, 2, 3]
    assert flatten_first([1, [2], 3]) == [1, 2, 3]
    assert flatten_first([1, 2, [3]]) == [1, 2, 3]
    assert flatten_first([[1, 2], 3]) == [1, 2, 3]
    assert flatten_first([1, [2, 3]]) == [1, 2, 3]
    assert flatten_first([[1], 2, [3]]) == [1, 2, 3]
    assert flatten_first([[1], [2], 3]) == [1, 2, 3]
    assert flatten_first([1, [2], [3]]) == [1, 2, 3]
    assert flatten_first([[1], [2], [3]]) == [1, 2, 3]
    assert flatten_first([[1, 2, 3]]) == [1, 2, 3]
    assert flatten_first([[1, [2], 3]]) == [1, [2], 3]
    assert flatten_first([[1], [[2]], [3]]) == [1, [2], 3]
    assert flatten_first([[1], [[[2, 3]]], [4]]) == [1, [[2, 3]], 4]
  end
end
