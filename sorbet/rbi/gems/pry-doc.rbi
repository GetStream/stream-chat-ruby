# This file is autogenerated. Do not edit it by hand. Regenerate it with:
#   srb rbi gems

# typed: true
#
# If you would like to make changes to this file, great! Please create the gem's shim here:
#
#   https://github.com/sorbet/sorbet-typed/new/master?filename=lib/pry-doc/all/pry-doc.rbi
#
# pry-doc-1.2.0

module PryDoc
  def self.load_yardoc(version); end
  def self.root; end
end
module Pry::CInternals
end
class Pry::CInternals::SymbolExtractor
  def balanced?(str); end
  def complete_function_signature?(str); end
  def extract(info); end
  def extract_code(info, offset: nil, start_line: nil, direction: nil, &block); end
  def extract_function(info); end
  def extract_macro(info); end
  def extract_oneliner(info); end
  def extract_struct(info); end
  def extract_typedef_struct(info); end
  def function_return_type?(str); end
  def initialize(ruby_source_folder); end
  def self.file_cache; end
  def self.file_cache=(arg0); end
  def source_from_file(file); end
  def token_count(tokens, token); end
end
class Pry::CInternals::ETagParser
  def clean_file_name(file_name); end
  def file_name_and_content_for(c_file_section); end
  def initialize(tags_path, ruby_source_folder); end
  def parse_tagfile; end
  def ruby_source_folder; end
  def self.symbol_map_for(tags_path, ruby_source_folder); end
  def symbol_map; end
  def tagfile; end
  def tags_path; end
end
class Pry::CInternals::ETagParser::CFile
  def cleanup_linenumber(line_number); end
  def cleanup_symbol(symbol); end
  def file_name; end
  def file_name=(arg0); end
  def full_path_for(file_name); end
  def initialize(file_name: nil, content: nil, ruby_source_folder: nil); end
  def ruby_source_folder; end
  def source_location_for(symbol, line_number); end
  def symbol_map; end
  def symbol_type_for(symbol); end
  def windows?; end
end
class Pry::CInternals::ETagParser::SourceLocation < Struct
  def file; end
  def file=(_); end
  def line; end
  def line=(_); end
  def self.[](*arg0); end
  def self.inspect; end
  def self.members; end
  def self.new(*arg0); end
  def symbol_type; end
  def symbol_type=(_); end
end
class Pry::CInternals::RubySourceInstaller
  def arch; end
  def ask_for_install; end
  def check_for_error(message, &block); end
  def curl_cmd; end
  def curl_cmd=(arg0); end
  def download_ruby; end
  def etag_binary; end
  def etag_binary=(arg0); end
  def etag_cmd; end
  def etag_cmd=(arg0); end
  def generate_tagfile; end
  def initialize(ruby_version, ruby_source_folder); end
  def install; end
  def linux?; end
  def ruby_source_folder; end
  def ruby_version; end
  def set_platform_specific_commands; end
  def windows?; end
end
class Pry::CInternals::CodeFetcher
  def fetch_all_definitions(symbol); end
  def fetch_first_definition(symbol, index = nil); end
  def initialize(line_number_style: nil); end
  def line_number_style; end
  def self.ruby_source_folder; end
  def self.ruby_source_folder=(arg0); end
  def self.ruby_source_installer; end
  def self.ruby_source_installer=(arg0); end
  def self.ruby_version; end
  def self.symbol_map; end
  def self.symbol_map=(arg0); end
  def start_line_for(line); end
  def symbol_extractor; end
  def use_line_numbers?; end
  include Pry::Helpers::Text
end
class Pry::CInternals::ShowSourceWithCInternals < Pry::Command::ShowSource
  def line_number_style; end
  def options(opt); end
  def process; end
  def show_c_source; end
end
class Pry
end
module Pry::MethodInfo
  def self.aliases(meth); end
  def self.cache(meth); end
  def self.find_gem_dir(meth); end
  def self.gem_dir_from_method(meth); end
  def self.gem_root(dir); end
  def self.guess_gem_name(name); end
  def self.info_for(meth); end
  def self.is_singleton?(meth); end
  def self.method_host(meth); end
  def self.namespace_name(host); end
  def self.parse_and_cache_if_gem_cext(meth); end
  def self.receiver_notation_for(meth); end
  def self.registry_lookup(meth); end
end
