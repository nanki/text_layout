class TextLayout::Wrap
  def initialize(str)
    @str = str
  end

  def layout(width=80)
    raise "width must be greater than 1" if width < 2
    words = @str.scan(/[[:alnum:]]+|./)

    lines = []
    line = ''
    while word = words.shift
      word.lstrip! if line.empty?
      rest_width = width - line.display_width

      if word.display_width <= rest_width
        line += word
        flush = line.display_width == width
      else
        word, rest = split_word(word, rest_width - 1)
        line += word + "-" unless word.empty?
        words.unshift rest
        flush = true
      end

      if flush
        lines << line
        line = ''
      end
    end

    lines << line

    lines.pop if lines.last.empty?

    lines.join("\n")
  end

  private
  def split_word(word, width)
    if word.display_width < width
      [word, ''] 
    else
      i, dw = 0, 0
      chars = word.chars.to_a
      dw += chars[i += 1].display_width while dw < width
      i -= 1 if dw > width
      [chars[0...i].join, chars[i..-1].join]
    end
  end
end
