#!ruby -Ku -I../lib -rubygems
# -*- coding: UTF-8 -*-;
require "test/unit"
require "text_layout"

class TestTextLayout < Test::Unit::TestCase
  def test_span_1
    assert_table [
      [{:value => 1, :colspan => 1, :rowspan => 1}],
    ], <<-RESULT
| 1 |
    RESULT
  end

  def test_table_simple
    assert_table [
      [1, 2],
      [3, 4]
    ], <<-RESULT
| 1 | 2 |
| 3 | 4 |
    RESULT
  end

  def test_table_multipleline
    assert_table [
      ["1\n2", 2],
      [3, 4]
    ], <<-RESULT
| 1 | 2 |
| 2 |   |
| 3 | 4 |
    RESULT
  end

  def test_table_span
    assert_table [
      [{:value => 1, :rowspan => 2}, 2, 3],
      [{:value => 4, :colspan => 2}]
    ], <<-RESULT
| 1 | 2 | 3 |
|   |     4 |
    RESULT
  end

  def test_expand_multicolumn
    assert_table [
      [1, 2, 3],
      [4, {:value => "too loooooong", :colspan => 2}]
    ], <<-RESULT
| 1 |     2 |     3 |
| 4 | too loooooong |
    RESULT
  end

  def test_align
    assert_table [
      [{:value => 1, :align => :left}, {:value => 2, :align => :center}, {:value => 3, :align => :right}],
      [ {:value => "oooooooooooooooooooo", :colspan => 3}]
    ], <<-RESULT
| 1     |   2   |    3 |
| oooooooooooooooooooo |
    RESULT
  end

  def test_successive_colspan
    assert_table [[{:colspan => 2, :value => "a"}] * 2], <<-RESULT
| a | a |
    RESULT
  end

  def assert_table(array, result)
    assert_equal result.rstrip, TextLayout::Table.new(array).layout
  end
end
