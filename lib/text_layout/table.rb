class TextLayout::Table
  def initialize(table, options = {})
    @table = table
    @options = {
      :col_border => "|",
      :row_border => "-",
      :cross => "+",
      :border => false,
      :padding => " "
    }.merge(options)

    if @options[:border] == true
      @options[:border] = [:top, :bottom, :left, :right, :cell].inject({}){|r, i|r[i] = true;r}
    end
  end

  def column_border_width
    @column_border_width ||= (@options[:padding] + @options[:col_border] + @options[:padding]).display_width
  end

  def cell_format
    @cell_format ||= @options[:padding] + "%s" + @options[:padding]
  end

  def line_format
    @line_format ||= @options[:col_border] + "%s" + @options[:col_border]
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
    build_string.join("\n")
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

    [:row, :col].each{|dir| @border[dir].map!{|v| v ? 1 : 0 } }
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
    [[:col, column_border_width], [:row, @options[:border] ? 1 : 0]].each do |dir, margin|
      @spanss[dir].each do |range, spans|
        rstart, rsize = range
        spans.each do |span|
          border_size = sum(@border[dir][rstart, rsize-1])
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

    total_lines = sum(@column_size[:row])
    if @options[:border]
      total_lines += sum(@border[:row])
    end

    lines << row_border(-1, @unknotted.first) if @options[:border] && @options[:border][:top]
    total_lines += 1 if @options[:border] && @options[:border][:bottom]

    total_lines.times do |display_row|
      n = display_row
      row, on_border = @column_size[:row].each_with_index do |height, i|
        n -= height
        break i, false if n < 0

        next unless @options[:border] && @options[:border][:cell]

        n -= @border[:row][i] || 1
        break i, true if n < 0
      end

      line = []

      line << cross(-1, row) if on_border

      @unknotted[row].each_with_index do |cell, col|
        n = display_row - sum(@column_size[:row][0...cell.row])
        n -= sum(@border[:row][0...cell.row]) if @options[:border]
        value = cell.attr[:value][n]

        if on_border
          if border = cell_row_border(col, row, cell)
            line << border
            next line << cross(col, row)
          elsif !value
            cell_width = @column_size[:col][col] + @options[:padding].display_width * 2
            line << " " * cell_width
            next line << cross(col, row)
          end
        end

        next unless cell.col == col

        line << cell_format % align(value.to_s, width_with_colspan(cell), cell.attr[:align] || :auto)
        line << cross(col, row) if on_border
      end

      if on_border
        line = line.join
      else
        line = line_format % line.join(@options[:col_border])
      end

      lines << line
    end

    lines
  end

  def width_with_colspan(cell)
    col = cell.col
    if Span === cell && colspan = cell.attr[:colspan]
      border_size = sum(@border[:col][col, colspan - 1])
      sum(@column_size[:col][col...col+colspan]) + column_border_width * border_size
    else
      @column_size[:col][col]
    end
  end

  def row_border(row, cols)
    line = ""
    line << cross(-1, row)
    cols.each_with_index do |cell, col|
      line << cell_row_border(col, row, cell)
      line << cross(col, row)
    end
    line
  end

  def cell_row_border(col, row, cell)
    if row_border_visible?(col, row)
      cell_width = @column_size[:col][col] + @options[:padding].display_width * 2
      @options[:row_border] * cell_width
    else
      false
    end
  end

  def row_border_visible?(col, row)
    !@unknotted[row + 1] || @unknotted[row][col] != @unknotted[row + 1][col]
  end

  def cross(col, row)
    if @unknotted[row+1]
      sw = @unknotted[row+1][col]
      se = @unknotted[row+1][col+1]
    else
      sw = se = nil
    end

    nw = @unknotted[row][col]
    ne = @unknotted[row][col+1]

    nw = ne = nil if row < 0
    sw = nw = nil if col < 0

    case
    when nw == ne && sw == se
      @options[:row_border]
    when nw == sw && ne == se
      @options[:col_border]
    else
      @options[:cross]
    end
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
