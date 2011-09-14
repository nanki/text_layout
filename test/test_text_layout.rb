require "test/unit"
require "text_layout"

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
    table = [
      [1, 2],
      [3, 4]
    ]
    assert_equal <<-RESULT, TextLayout::Table.new(table).layout
| 1 | 2 |
| 3 | 4 |
RESULT
  end

  def test_table_multipleline
    table = [
      ["1\n2", 2],
      [3, 4]
    ]
    assert_equal <<-RESULT, TextLayout::Table.new(table).layout
| 1 | 2 |
| 2 |   |
| 3 | 4 |
RESULT
  end

  def test_table_span
    table = [
      [{:value => 1, :rowspan => 2}, 2, 3],
      [{:value => 4, :colspan => 2}]
    ]
    assert_equal <<-RESULT, TextLayout::Table.new(table).layout
| 1 | 2 | 3 |
|   |     4 |
RESULT
  end
end
