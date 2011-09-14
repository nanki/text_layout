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
end
