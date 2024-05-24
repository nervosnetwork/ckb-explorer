module CsvExportable
  class ExportUdtSnapshotJob < BaseExporter
    attr_accessor :udt, :block

    def perform(args)
      @block = Block.find_by!(number: args[:number])
      @udt = Udt.published_xudt.find_by!(type_hash: args[:id])
      type_script = TypeScript.find_by(@udt.type_script)

      condition = <<-SQL
        type_script_id = #{type_script.id} AND
        block_timestamp <= #{@block.timestamp} AND
        (consumed_block_timestamp > #{@block.timestamp} OR consumed_block_timestamp IS NULL)
      SQL
      cell_outputs = CellOutput.where(condition).group(:address_id).sum(:udt_amount)
      cell_outputs = cell_outputs.reject { |_, v| v.to_f.zero? }

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

      rows = []
      data.sort_by { |item| -item[:udt_amount] }.each do |item|
        row = generate_row(item)
        next if row.blank?

        rows << row
      end

      header = ["Token Symbol", "Block Height", "UnixTimestamp", "date(UTC)", "Owner", "CKB Address", "Amount"]
      generate_csv(header, rows)
    end

    def generate_row(item)
      datetime = datetime_utc(@block.timestamp)

      if (decimal = @udt.decimal)
        [
          @udt.symbol,
          @block.number,
          @block.timestamp,
          datetime,
          item[:bitcoin_address_hash] || item[:address_hash],
          item[:address_hash],
          parse_udt_amount(item[:udt_amount].to_d, decimal),
        ]
      else
        [
          @udt.symbol,
          @block.number,
          @block.timestamp,
          datetime,
          item[:bitcoin_address_hash] || item[:address_hash],
          item[:address_hash],
          "#{item[:udt_amount]} (raw)",
        ]
      end
    end
  end
end