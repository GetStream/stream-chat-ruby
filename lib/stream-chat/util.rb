# frozen_string_literal: true

# lib/util.rb

def get_sort_fields(sort)
  sort_fields = []
  sort&.each do |k, v|
    sort_fields << { field: k, direction: v }
  end
  sort_fields
end
