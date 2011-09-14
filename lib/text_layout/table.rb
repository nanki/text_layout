class TextLayout::Table
  def initialize(array)
    @array = array
  end

  def normalize(cell)
    unless Hash === cell
      cell = {:value => cell}
    end

    cell[:value] = cell[:value].to_s.lines.map(&:strip)
    cell
  end

  class Cell < Struct.new(:col, :row, :attr)
    def width
      attr[:value].map(&:display_width).max
    end

    def height
      attr[:value].size
    end
  end
  
  class Span < Cell
    def main?(col, row)
      self.col == col && self.row == row
    end
  end

  def layout
    spanss = {:row => Hash.new{[]}, :col => Hash.new{[]}}
    layout = @array.map{[]}

    @array.each_with_index do |cols, row|
      cols.each_with_index do |attr, col|
        attr = normalize(attr)

        if !attr[:rowspan] && !attr[:colspan]
          if i = layout[row].index(nil)
            layout[row][i] = Cell.new(i, row, attr)
          else
            layout[row] << Cell.new(layout[row].size, row, attr)
          end
        else
          span = Span.new(col, row, attr)
          spanss[:row][row...row+attr[:rowspan]] <<= span if attr[:rowspan]
          spanss[:col][col...col+attr[:colspan]] <<= span if attr[:colspan]
          
          (attr[:rowspan] || 1).times do |rr|
            (attr[:colspan] || 1).times do |cc|
              layout[row+rr][col+cc] = span
            end
          end
        end
      end
    end

    max = {:row => [], :col => []}

    layout.each_with_index do |cols, row|
      cols.each_with_index do |cell, col|
        next if Span === cell && !cell.main?(col, row)

        unless cell.attr[:colspan]
          max[:col][col] = [max[:col][col] || 0, cell.width].max
        end
        
        unless cell.attr[:rowspan]
          max[:row][row] = [max[:row][row] || 0, cell.height].max
        end
      end
    end

    [[:col, 3], [:row, 0]].each do |dir, margin|
      spanss[dir].each do |range, spans|
        range_size = range.end - range.begin
        spans.each do |span|
          size = sum(max[dir][range]) + margin * (range_size - 1)
          diff = (dir == :col ? span.width : span.height) - size

          next unless diff > 0
          q, r = diff.divmod range_size 
          range.each_with_index do |i, rr|
            max[dir][i] += q + (rr < r ? 1 : 0)
          end
        end
      end
    end

    result = ""
    sum(max[:row]).times do |layout_row|
      n = layout_row
      row = max[:row].each_with_index do |height, i|
        if n - height >= 0
          n -= height
        else
          break i 
        end
      end

      line = []
      layout[row].each_with_index do |cell, col|
        next unless cell.col == col
        n = layout_row - sum(max[:row][0...cell.row])
        width = 
          if Span === cell && colspan = cell.attr[:colspan]
            sum(max[:col][col...col+colspan]) + 3 * (colspan - 1)
          else
            max[:col][col]
          end

        line << justify(cell.attr[:value][n].to_s, width)
      end

      result += "| " + line.join(" | ") + " |\n"
    end

    result
  end

  def sum(array)
    array.inject(0) {|r, i| r + i }
  end

  def justify(str, width, type=:right)
    pad = width - str.display_width
    pad = 0 if pad < 0 
    case type
    when :right
      " " * pad + str
    when :left
      str + " " * pad
    when :center
      " " * (pad / 2) + str + " " * (pad - pad / 2)
    end
  end
end
