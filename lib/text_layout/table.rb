class TextLayout::Table
  def initialize(table, options = {})
    @table = table
    @options = {
      :column_separator => "|",
      :padding => " "
    }.merge(options)
  end

  def column_separator
    @column_separator ||= @options[:padding] + @options[:column_separator] + @options[:padding]
  end

  def line_format
    @line_format ||= @options[:column_separator] + @options[:padding] + "%s" + @options[:padding] + @options[:column_separator]
  end

  class Cell < Struct.new(:col, :row, :attr)
    def width
      attr[:value].map(&:display_width).max || 0
    end

    def height
      [attr[:value].size, 1].max
    end
  end

  class Span < Cell
    def main?(col, row)
      self.col == col && self.row == row
    end
  end

  def layout
    unknot
    calculate_column_size
    expand_column_size
    build_string.map{|line|line_format % line.join(column_separator)}.join("\n")
  end

  private
  def unknot
    @unknotted = @table.map{[]}
    @spanss = {:row => Hash.new{[]}, :col => Hash.new{[]}}
    @border = {:row => [], :col => []}

    @table.each_with_index do |cols, row|
      cols.each_with_index do |attr, col|
        attr = normalize(attr)
        col = @unknotted[row].index(nil) || @unknotted[row].size
        rowspan, colspan = attr[:rowspan], attr[:colspan]

        if !rowspan && !colspan
          @unknotted[row][col] = Cell.new(col, row, attr)
        else
          span = Span.new(col, row, attr)
          @spanss[:row][[row, rowspan]] <<= span if rowspan
          @spanss[:col][[col, colspan]] <<= span if colspan

          (rowspan || 1).times do |rr|
            (colspan || 1).times do |cc|
              @unknotted[row+rr][col+cc] = span
            end
          end
        end

        @border[:row][row - 1] ||= @unknotted[row][col] != @unknotted[row - 1][col] if row > 0
        @border[:col][col - 1] ||= @unknotted[row][col] != @unknotted[row][col - 1] if col > 0
      end
    end
  end

  def calculate_column_size
    @column_size = {:row => [0] * @unknotted.size, :col => [0] * @unknotted.first.size}

    @unknotted.each_with_index do |cols, row|
      cols.each_with_index do |cell, col|
        next if Span === cell && !cell.main?(col, row)

        @column_size[:col][col] = [@column_size[:col][col], cell.width ].max unless cell.attr[:colspan]
        @column_size[:row][row] = [@column_size[:row][row], cell.height].max unless cell.attr[:rowspan]
      end
    end
  end

  def expand_column_size
    [[:col, column_separator.display_width], [:row, 0]].each do |dir, margin|
      @spanss[dir].each do |range, spans|
        rstart, rsize = range
        spans.each do |span|
          border_size = sum(@border[dir][rstart, rsize-1].map{|v|v ? 1 : 0})
          size = sum(@column_size[dir][*range]) + margin * border_size
          diff = (dir == :col ? span.width : span.height) - size

          next unless diff > 0

          q, r = diff.divmod rsize
          (rstart...rstart + rsize).each_with_index do |i, rr|
            @column_size[dir][i] += q + (rr < r ? 1 : 0)
          end
        end
      end
    end
  end

  def build_string
    lines = []
    sum(@column_size[:row]).times do |display_row|
      n = display_row
      row = @column_size[:row].each_with_index do |height, i|
        if n - height >= 0
          n -= height
        else
          break i
        end
      end

      line = []
      @unknotted[row].each_with_index do |cell, col|
        next unless cell.col == col
        width =
          if Span === cell && colspan = cell.attr[:colspan]
            border_size = sum(@border[:col][col, colspan - 1].map{|v|v ? 1 : 0})
            sum(@column_size[:col][col...col+colspan]) + column_separator.display_width * border_size
          else
            @column_size[:col][col]
          end

        n = display_row - sum(@column_size[:row][0...cell.row])
        line << align(cell.attr[:value][n].to_s, width, cell.attr[:align] || :auto)
      end

      lines << line
    end

    lines
  end

  def normalize(cell)
    unless Hash === cell
      cell = {:value => cell}
    end

    cell.delete :colspan if cell[:colspan] == 1
    cell.delete :rowspan if cell[:rowspan] == 1

    cell[:value] = cell[:value].to_s.lines.map(&:strip)
    cell
  end

  def sum(array)
    array.to_a.inject(0) {|r, i| r + i }
  end

  def align(str, width, type=:auto)
    pad = width - str.display_width
    pad = 0 if pad < 0
    case type
    when :auto
      if width * 0.85 < pad
        align(str, width, :center)
      else
        align(str, width, :right)
      end
    when :left
      str + " " * pad
    when :center
      " " * (pad / 2) + str + " " * (pad - pad / 2)
    else # :right
      " " * pad + str
    end
  end
end
