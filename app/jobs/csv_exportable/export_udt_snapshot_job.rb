module CsvExportable
  class ExportUdtSnapshotJob < BaseExporter
    attr_accessor :udt, :block

    def perform(args)
      find_block_and_udt(args)
      type_script = TypeScript.find_by(@udt.type_script)

      cell_outputs = fetch_cell_outputs(type_script.id)
      data = fetch_address_data(cell_outputs)
      merged_data = merge_data(data)

      rows = prepare_rows(merged_data)
      header = ["Token Symbol", "Block Height", "UnixTimestamp", "date(UTC)", "Owner", "Amount"]
      generate_csv(header, rows)
    end

    private

    def find_block_and_udt(args)
      @block = Block.find_by!(number: args[:number])
      @udt = Udt.published_xudt.find_by!(type_hash: args[:id])
    end

    def fetch_cell_outputs(type_script_id)
      condition = <<-SQL
        type_script_id = #{type_script_id} AND
        block_timestamp <= #{@block.timestamp} AND
        (consumed_block_timestamp > #{@block.timestamp} OR consumed_block_timestamp IS NULL)
      SQL
      cell_outputs = CellOutput.where(condition).group(:address_id).sum(:udt_amount)
      cell_outputs.reject { |_, v| v.to_f.zero? }
    end

    def fetch_address_data(cell_outputs)
      data = []
      cell_outputs.keys.each_slice(1000) do |address_ids|
        addresses = Address.includes(bitcoin_address_mapping: [:bitcoin_address]).
          where(id: address_ids).pluck("addresses.id", "addresses.address_hash", "bitcoin_addresses.address_hash")

        addresses.each do |address|
          data << {
            address_hash: address[1],
            bitcoin_address_hash: address[2],
            udt_amount: cell_outputs[address[0]],
          }
        end
      end
      data
    end

    def merge_data(data)
      data.each_with_object(Hash.new(0)) do |entry, hash|
        owner = entry[:bitcoin_address_hash].presence || entry[:address_hash]
        hash[owner] += entry[:udt_amount]
      end
    end

    def prepare_rows(merged_data)
      merged_data.sort_by { |_, amount| -amount }.map do |item|
        generate_row(item)
      end.compact
    end

    def generate_row(item)
      datetime = datetime_utc(@block.timestamp)
      decimal = @udt.decimal

      [
        @udt.symbol,
        @block.number,
        @block.timestamp,
        datetime,
        item[0],
        decimal.present? ? parse_udt_amount(item[1].to_d, decimal) : "#{item[1]} (raw)",
      ]
    end
  end
end
