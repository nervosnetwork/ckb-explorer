module RecordCounters
  class Blocks
    def total_count
      TableRecordCount.find_by(table_name: "blocks")&.count
    end
  end
end
