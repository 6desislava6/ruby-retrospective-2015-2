class TurtleGraphics
  class Position
    DIRECTIONS = [:up, :right, :down, :left]

    MOVEMENT = {left: [0, -1], right: [0, 1], up: [-1, 0], down: [1, 0]}

    attr_accessor :current_position, :orientation

    def initialize
      @orientation = :right
    end

    def change_orientation(turn)
      @orientation = DIRECTIONS[(DIRECTIONS.index(@orientation) + turn) % 4]
    end

    def move(dimensions)
      way = MOVEMENT[@orientation]
      @current_position = [(@current_position.first + way.first) % dimensions.first,
                           (@current_position.last + way.last)  % dimensions.last]
    end
  end


  class Canvas
    attr_reader :width, :height, :matrix
    def initialize(width, height)
      @width = width
      @height = height
      @matrix = Array.new(height) { Array.new(width, 0) }
    end

    def change_density(new_position)
      @matrix[new_position.first][new_position.last] += 1
      @matrix
    end


    class ASCII
      def initialize(symbols)
        @symbols = symbols
      end

      def draw(density_matrix)
        from_table_string(density_matrix)
      end

      private

      def from_table_string(density_matrix)
        from_table_symbols(density_matrix).map { |line| line.join }. join("\n")
      end

      def from_table_symbols(density_matrix)
        range_length = 1.0 / (@symbols.size - 1)
        max = find_max(density_matrix)
        density_matrix.map do |line|
          line.map do |value|
            @symbols[(value.to_f / max / range_length).ceil]
          end
        end
      end

      def find_max(density_matrix)
        density_matrix.map { |x| x.max }.max
      end
    end


    class HTML
      def initialize(size)
        @size = size
      end

      def draw(density_matrix)
        make_whole_html(density_matrix)
      end

      private

      def make_whole_html(density_matrix)
        "<!DOCTYPE html>
    <html>#{make_head}#{make_body(density_matrix)}</html>"
      end

      def make_opacity_table(density_matrix)
        max = find_max(density_matrix)
        density_matrix.map do |line|
          line.map do |value|
             format('%.2f', value.to_f / max)
          end
        end
      end

      def make_html_table(density_matrix)
        opacity_table = make_opacity_table(density_matrix)
        string_html = opacity_table.map do |row|
          table_row = row.map do |opacity|
            '<td style="opacity: ' + opacity.to_s +  '"></td>'
          end.join
          "<tr>#{table_row}</tr>"
        end
        .join
        "<table>#{string_html}</table>"
      end

      def make_head
        "<head>
      <title>Turtle graphics</title>

      <style>
        table {
          border-spacing: 0;
        }

        tr {
          padding: 0;
        }

        td {
          width: #{@size}px;
          height: #{@size}px;

          background-color: black;
          padding: 0;
        }
      </style>
    </head>"
      end

      def make_body(density_matrix)
        "<body>#{make_html_table(density_matrix)}</body>"
      end

      def find_max(density_matrix)
        density_matrix.map { |x| x.max }.max
      end
    end
  end


  class Turtle
    attr_reader :position

    def initialize(width, height)
      @position = Position.new
      @canvas = Canvas.new(width, height)
    end

    def draw(type = nil, &block)
      instance_eval(&block)
      return @canvas.matrix if type.nil?
      type.draw(@canvas.matrix)
    end

    def move
      spawn_at(0, 0) if @position.current_position.nil?
      dimensions = [@canvas.height, @canvas.width]
      @canvas.change_density(@position.move(dimensions))
    end

    def turn_left
      @position.change_orientation(-1)
    end

    def turn_right
      @position.change_orientation(1)
    end

    def spawn_at(row, column)
      @position.current_position = [row, column]
      @canvas.change_density(@position.current_position)
    end

    def look(orientation)
      @position.orientation = orientation
    end
  end
end
