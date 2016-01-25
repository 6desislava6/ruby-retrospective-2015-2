class LazyMode

  class Date
    include Comparable
    attr_accessor :year, :month, :day

    def initialize(date)
      @year, @month, @day = date.split('-').map(&:to_i)
    end

    def add_zeroes(date, number)
      "0" * (number - date.to_s.length) + date.to_s
    end

    def to_s
      "#{add_zeroes(@year, 4)}-#{add_zeroes(@month, 2)}-#{add_zeroes(@day, 2)}"
    end

    def +(other_date)
      new_date = Date.new("0-0-0")
      new_date.day += @day + other_date.day
      new_date.month += @month + other_date.month

      new_date.year += @year + other_date.year
      new_date.normalize_date

      new_date
    end

    def <=>(other_date)
      comparison = @year <=> other_date.year
      return comparison if comparison != 0
      comparison = @month <=> other_date.month
      return comparison if comparison != 0
      @day <=> other_date.day
    end

    def ==(other_date)
      (self <=> other_date) == 0
    end

    def normalize_date
      overflow, @day = normalize(@day, 30)
      @month += overflow
      overflow, @month = normalize(@month, 12)
      @year += overflow
      self
    end

    def normalize(d_m_y, size)
      overflow = d_m_y == size ? 0 : d_m_y / size
      d_m_y = d_m_y % size if d_m_y != size
      [overflow, d_m_y]
    end
  end

  class ScheduleNote
    attr_accessor :interval, :date
    include Enumerable
    SPANS = {d:1, w:7, m:30}

    def initialize(date, interval = nil)
      @date = Date.new(date)
      @interval = make_interval(interval)
    end

    def next
      @date += @interval
    end

    def make_interval(interval)
      return nil if interval.nil?
      days = SPANS[interval[-1].to_sym] * interval[0...-1].to_i
      date = Date.new("0-0-#{days}").normalize_date
    end
  end

  class Note
    attr_accessor :file_name, :sub_notes, :tags, :schedule_note
    attr_reader :header

    def initialize(header, *tags)
      @header = header
      @tags = *tags.flatten
      @file_name = ""
      @body = ""
      @status = :topostpone
      @sub_notes = []
    end

    def date
      @schedule_note.date
    end

    def body(text_body = nil)
      if text_body.nil?
        @body
      else
        @body = text_body
      end
    end

    def status(symbol_status = nil)
      if symbol_status.nil?
        @status
      else
        @status = symbol_status
      end
    end

    def scheduled(schedule)
      @schedule_note = ScheduleNote.new(*schedule.split(" "))
    end


    def note(header, *tags, &block)
      new_note = Note.new(header, *tags)
      @sub_notes << new_note
      new_note.instance_eval(&block)
    end

    def to_s
      "#{@header}-#{@tags}-#{file_name} #{@body}, #{@status},
      #{schedule_note.date}"
    end
  end

  class File
    attr_reader :notes, :name
    def initialize(name, notes)
      @name = name
      @notes = []
      iterate_notes(notes)
    end

    def iterate_notes(notes)
      notes.each do |note|
        sub_notes = note.sub_notes
        note.sub_notes = []
        note.file_name = @name
        @notes << note
        iterate_notes(sub_notes)
      end
    end

    def daily_agenda(date)
      Agenda.new(:day, date, @notes, true)
    end

    def weekly_agenda(date)
      Agenda.new(:week, date, @notes, true)
    end
  end

  class Agenda
    attr_reader :notes
    TYPES_ADD = {
      day: Date.new("0-0-0"),
      week: Date.new("0-0-6"),
      month: Date.new("0-0-29")
    }
    TYPES = {
      day: Date.new("0-0-0"),
      week: Date.new("0-0-7"),
      month: Date.new("0-1-0")
    }

    def initialize(type, beginning_date, notes, add = false)
      @type = type
      if add
        @range = [beginning_date, beginning_date + TYPES_ADD[type]]
      else
        @range = [beginning_date, beginning_date + TYPES[type]]

      end
      @notes = []
      @notes = select_notes(notes)
    end

    def select_notes(notes)
      notes.each do |note|
        add_and_iterate_note(note)
      end
      @notes.select do |note|
        date = note.schedule_note.date
        date >= @range.first && date <= @range.last
      end
    end

    def add_and_iterate_note(note)
      return if note.schedule_note.nil?
      if note.schedule_note.interval.nil?
        @notes << note
      elsif not note.schedule_note.interval.nil?
        @notes << note
        iterate_note(note)
      end
    end

    def iterate_note(note)
      date = note.schedule_note.date
      while date <= @range.last
        @notes << Note.new(note.header, note.tags)
        @notes.last.schedule_note = ScheduleNote.new(date.to_s)
        @notes.last.schedule_note.interval = note.schedule_note.interval
        date = @notes.last.schedule_note.next
      end
    end

    def where(tag: nil, status: nil, text: nil)
      Agenda.new(@type, @range.first, @notes).select_tag(tag)
                                             .select_status(status)
                                             .select_text(text)
    end

    def select_tag(tag)
      return self if tag.nil?
      @notes.select!{ |note| note.tags.include?(tag) }
      self
    end

    def select_status(status)
      return self if status.nil?
      @notes.select!{ |note| note.status == status }
      self
    end

    def select_text(text)
      return self if text.nil?
      @notes.select! do |note|
        text.match(note.header) or text.match(note.body)
      end
      self
    end
  end

  class << self
    def create_file(name, &block)
      new_note = Note.new("")
      new_note.instance_eval(&block)
      new_file = File.new(name, new_note.sub_notes)
    end
  end
end
