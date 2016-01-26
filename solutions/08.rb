class Spreadsheet
  FORMAT = /[A-Z]+\d+/
  DELIMITER = /(?:\ {2,}|\t)/
  SIZE = 26
  ORD = ("A".."Z").to_a.zip((1..SIZE).to_a).to_h

  class Error < RuntimeError
  end

  attr_reader :sheet
  def initialize(cells = nil)
    @calculator = SpreadsheetDSL.new
    @sheet = []
    return if cells.nil?
    cells.strip.each_line do |row|
      cells = row.strip.split(DELIMITER)
      @sheet << cells if not cells.empty?
    end
  end

  def empty?
    @sheet.empty?
  end

  def cell_at(cell_index)
    indices = CellHandler.make_check_indices(cell_index, @sheet)
    @sheet[indices.first][indices.last]
  end

  def [](cell_index)
    indices = CellHandler.make_check_indices(cell_index, @sheet)
    @calculator.read_cell(@sheet[indices.first][indices.last], self, cell_index)
  end

  def to_s
    sheet = calculate_all
    sheet.map do |row|
      row.join("\t")
    end.join("\n")
  end

private

  def calculate_all()
    sheet = []
    @sheet.each_with_index do |row, i|
      sheet << row.map.with_index do |col, j|
        @calculator.read_cell(@sheet[i][j], self)
      end
    end
    sheet
  end

  class SpreadsheetDSL

    def add(argument_first, argument_second, *args)
      args.reduce(0, :+) + argument_first + argument_second
    end

    def multiply(argument_first, argument_second, *args)
      args.reduce(1, :*) * argument_first * argument_second
    end

    def subtract(argument_first, argument_second)
      argument_first - argument_second
    end

    def divide(argument_first, argument_second)
      argument_first.to_f / argument_second
    end

    def mod(argument_first, argument_second)
      argument_first % argument_second
    end

    def read_cell(cell, spread_sheet, cell_index = nil)
      return cell if cell[0] != '='
      #cell.gsub!(cell_index, "*") if not cell_index.nil?
      calculate(CellHandler.make_formula(cell[1..-1], spread_sheet, cell_index))
    end

    def format_result(result)
      return result.to_i.to_s if result.round == result
      format("%.2f", result)
    end

    def calculate(formula_string)
      begin
        result = instance_eval(formula_string)
      rescue Exception => e
        ErrorHandler.handle_error(e, formula_string)
      else
        format_result(result)
      end
    end
  end

  class CellHandler
    class << self
      def make_formula(formula_string, spread_sheet, cell_index = nil)
        formula = formula_string
        formula_string.gsub!(/^\s*[A-Z]+/) { |match| match.downcase }
        formula.gsub!(/[A-Z]+\d+/) do |match|
          match != cell_index ? spread_sheet[match] : match
        end
        formula
      end

      def make_check_indices(cell_index, sheet)
        check_format(cell_index)
        row = /\d+/.match(cell_index).to_a.first.to_i - 1
        col = calculate_column(/[A-Z]+/.match(cell_index).to_a.first) - 1
        if check_boundaries(row, col, sheet)
          raise Error.new("Cell '#{cell_index}' does not exist")
        end
        [row, col]
      end

      def calculate_column(col_string)
        col_string.reverse.each_char.with_index.reduce(0) do |sum, (ch, index) |
          sum + SIZE ** index * ORD[ch]
        end
      end

      def check_format(cell_index)
        formatted = cell_index.scan(FORMAT)
        if formatted.size != 1
          raise Error.new("Invalid cell index '#{cell_index}'")
        elsif formatted.first != cell_index
          raise Error.new("Invalid cell index '#{cell_index}'")
        end
      end

      def check_boundaries(row, col, sheet)
        row < 0 || row >= sheet.size || col < 0 || col > sheet.first.size
      end
    end
  end

  class ErrorHandler
    class << self
      def handle_error(e, formula_string)
        case e
        when NoMethodError then method_error(formula_string)
        when SyntaxError then syntax_error(formula_string)
        when ArgumentError then argument_error(formula_string, e)
        else syntax_error(formula_string)
        end
      end

      def method_error(formula_string)
        formula_string = formula_string[0...formula_string.index("(")]
        raise Error.new("Unknown function '#{formula_string.upcase}'")
      end

      def syntax_error(formula_string)
        raise Error.new("Invalid expression '#{formula_string.upcase}'")
      end

      def argument_error(formula_string, e)
        at_least = e.message.include?('+') ? ' at least' : ''
        formula_string = formula_string[0...formula_string.index("(")]
        number = e.message.scan(/\d+/)
        raise Error.new("Wrong number of arguments for " \
          "'#{formula_string.upcase}': expected" + at_least + " #{number[1]}," \
          " got #{number[0]}")
      end
    end
  end
end
