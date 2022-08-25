# This file is autogenerated. Do not edit it by hand. Regenerate it with:
#   srb rbi gems

# typed: strict
#
# If you would like to make changes to this file, great! Please create the gem's shim here:
#
#   https://github.com/sorbet/sorbet-typed/new/master?filename=lib/terminal-table/all/terminal-table.rbi
#
# terminal-table-3.0.2

module Terminal
end
class Terminal::Table
  def <<(array); end
  def ==(other); end
  def add_row(array); end
  def add_separator(border_type: nil); end
  def align_column(n, alignment); end
  def cell_padding; end
  def cell_spacing; end
  def column(n, method = nil, array = nil); end
  def column_width(n); end
  def column_widths; end
  def column_with_headings(n, method = nil); end
  def columns; end
  def columns_width; end
  def elaborate_rows; end
  def headings; end
  def headings=(arrays); end
  def headings_with_rows; end
  def initialize(options = nil, &block); end
  def length_of_column(n); end
  def number_of_columns; end
  def recalc_column_widths; end
  def render; end
  def require_column_widths_recalc; end
  def rows; end
  def rows=(array); end
  def style; end
  def style=(options); end
  def title; end
  def title=(title); end
  def title_cell_options; end
  def to_s; end
  def yield_or_eval(&block); end
end
class Terminal::Table::Cell
  def align(val, position, length); end
  def alignment; end
  def alignment=(val); end
  def alignment?; end
  def colspan; end
  def initialize(options = nil); end
  def inspect; end
  def lines; end
  def render(line = nil); end
  def to_s(line = nil); end
  def value; end
  def value_for_column_width_recalc; end
  def width; end
end
class Terminal::Table::Row
  def <<(item); end
  def [](index); end
  def add_cell(item); end
  def cells; end
  def crossings; end
  def height; end
  def initialize(table, array = nil, **_kwargs); end
  def number_of_columns; end
  def render; end
  def table; end
end
class Terminal::Table::Separator < Terminal::Table::Row
  def border_type; end
  def border_type=(arg0); end
  def implicit; end
  def initialize(*args, border_type: nil, implicit: nil); end
  def render; end
  def save_adjacent_rows(prevrow, nextrow); end
end
class Terminal::Table::Border
  def [](key); end
  def []=(key, val); end
  def bottom; end
  def bottom=(arg0); end
  def data; end
  def data=(arg0); end
  def initialize; end
  def initialize_dup(other); end
  def left; end
  def left=(arg0); end
  def maybeleft(key); end
  def mayberight(key); end
  def remove_horizontals; end
  def remove_verticals; end
  def right; end
  def right=(arg0); end
  def top; end
  def top=(arg0); end
end
class Terminal::Table::AsciiBorder < Terminal::Table::Border
  def horizontal(_type); end
  def initialize; end
  def vertical; end
end
class Terminal::Table::MarkdownBorder < Terminal::Table::AsciiBorder
  def initialize; end
end
class Terminal::Table::UnicodeBorder < Terminal::Table::Border
  def horizontal(type); end
  def initialize; end
  def vertical; end
end
class Terminal::Table::UnicodeRoundBorder < Terminal::Table::UnicodeBorder
  def initialize; end
end
class Terminal::Table::UnicodeThickEdgeBorder < Terminal::Table::UnicodeBorder
  def initialize; end
end
class Terminal::Table::Style
  def alignment; end
  def alignment=(arg0); end
  def all_separators; end
  def all_separators=(arg0); end
  def apply(options); end
  def border; end
  def border=(val); end
  def border_bottom; end
  def border_bottom=(val); end
  def border_i=(val); end
  def border_left; end
  def border_left=(val); end
  def border_right; end
  def border_right=(val); end
  def border_top; end
  def border_top=(val); end
  def border_x=(val); end
  def border_y; end
  def border_y=(val); end
  def border_y_width; end
  def horizontal(*args, &block); end
  def initialize(options = nil); end
  def margin_left; end
  def margin_left=(arg0); end
  def on_change(attr); end
  def padding_left; end
  def padding_left=(arg0); end
  def padding_right; end
  def padding_right=(arg0); end
  def remove_horizontals(*args, &block); end
  def remove_verticals(*args, &block); end
  def self.defaults; end
  def self.defaults=(options); end
  def vertical(*args, &block); end
  def width; end
  def width=(arg0); end
  extend Forwardable
end
module Terminal::Table::TableHelper
  def table(headings = nil, *rows, &block); end
end
module Terminal::Table::Util
  def ansi_escape(line); end
  def self.ansi_escape(line); end
end
