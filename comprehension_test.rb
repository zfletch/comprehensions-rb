#!/usr/bin/env ruby

require "test/unit"
require_relative "comprehension"

class TestPythonExamples < Test::Unit::TestCase
  include ListComprehension

  # squares = [x**2 for x in range(10)]
  def test_squares
    assert_equal(
      [0, 1, 4, 9, 16, 25, 36, 49, 64, 81],
      c{ x ** 2 }.for{ x }.in(0...10)
    )
  end

  # [(x, y) for x in [1,2,3] for y in [3,1,4] if x != y]
  def test_pairs
    assert_equal(
      [[1, 3], [1, 4], [2, 3], [2, 1], [2, 4], [3, 1], [3, 4]],
      c{ [x, y] }.for{ x }.in{ [1,2,3] }.for{ y }.in{ [3,1,4] }.if{ x != y }
    )
  end

  # [str(round(pi, i)) for i in range(1, 6)]
  def test_pi
    assert_equal(
      ['3.1', '3.14', '3.142', '3.1416', '3.14159'],
      c{ Math::PI.round(i).to_s }.for{ i }.in{ 1...6 }
    )
  end

  def test_scoping_issue
    assert_raise TypeError do
      x = 10
      c{ x }.for{ x }.in{ 1..3 }.to_a
    end
  end
end
