# -*- coding: UTF-8 -*-;
require "test/unit"
require "text_layout"

$KCODE = 'u'

class TestTextLayout < Test::Unit::TestCase
  def test_wrap_private
    wrap = TextLayout::Wrap.new("")
    assert_equal %w(linew rap), wrap.send(:split_word, "linewrap", 5)
    assert_equal %w(あい うえ), wrap.send(:split_word, "あいうえ", 5)
  end

  def test_wrap
    assert_equal (["+"*20] * 4).join("\n"), TextLayout::Wrap.new("+"*80).layout(20)
    assert_equal "line-\nwrap", TextLayout::Wrap.new("linewrap").layout(5)
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

  def assert_table(array, result)
    assert_equal result, TextLayout::Table.new(array).layout
  end
end
