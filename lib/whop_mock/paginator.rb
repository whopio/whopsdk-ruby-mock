# frozen_string_literal: true

module WhopMock
  class Paginator
    DEFAULT_LIMIT = 10

    def paginate(records, limit: DEFAULT_LIMIT, after: nil)
      start_index = after ? (records.index { |record| cursor_for(record) == after } || -1) + 1 : 0
      page = records.drop(start_index).first(limit)

      {
        "data" => page,
        "page_info" => {
          "start_cursor" => page.first && cursor_for(page.first),
          "end_cursor" => page.last && cursor_for(page.last),
          "has_next_page" => (start_index + page.length) < records.length,
          "has_previous_page" => start_index.positive?
        }
      }
    end

    def cursor_for(record)
      [record.fetch("id")].pack("m0")
    end
  end
end
