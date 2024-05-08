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
      snapshot = CellOutput.where(condition).group(:address_id).sum(:udt_amount)

      rows = []
      snapshot = snapshot.reject { |_, v| v.to_f.zero? }
      snapshot.sort_by { |_k, v| -v }.each do |address_id, udt_amount|
        row = generate_row(address_id, udt_amount)
        next if row.blank?

        rows << row
      end

      header = ["Token Symbol", "Block Height", "UnixTimestamp", "date(UTC)", "Owner", "CKB Address", "Amount"]
      generate_csv(header, rows)
    end

    def generate_row(address_id, udt_amount)
      address = Address.find_by(id: address_id)
      return unless address

      owner = address.bitcoin_address&.address_hash || address.address_hash
      datetime = datetime_utc(@block.timestamp)

      if (decimal = @udt.decimal)
        [
          @udt.symbol,
          @block.number,
          @block.timestamp,
          datetime,
          owner,
          address.address_hash,
          parse_udt_amount(udt_amount.to_d, decimal),
        ]
      else
        [
          @udt.symbol,
          @block.number,
          @block.timestamp,
          datetime,
          owner,
          address.address_hash,
          "#{udt_amount} (raw)",
        ]
      end
    end
  end
end
