module CsvExportable
  class BaseExporter < ApplicationJob
    def perform(*)
      raise NotImplementedError
    end

    def generate_csv(header, rows)
      CSV.generate do |csv|
        csv << header
        rows.each { |row| csv << row }
      end
    end

    def generate_row(*)
      raise NotImplementedError
    end

    def attributes_for_udt_cell(udt_cell)
      udt_info = Udt.find_by(type_hash: udt_cell.type_hash, published: true)
      CkbUtils.hash_value_to_s(
        udt_info: {
          symbol: udt_info&.symbol,
          amount: udt_cell.udt_amount,
          decimal: udt_info&.decimal,
          uan: udt_info&.uan,
          type_hash: udt_cell.type_hash
        }
      )
    end

    def capacity_units(cell)
      units = ["CKB"]
      if cell[:udt_info]
        units << (cell[:udt_info][:uan].presence || cell[:udt_info][:symbol])
      end

      units
    end

    def cell_capacity(cell, unit)
      return nil unless cell

      if unit == "CKB"
        byte = CkbUtils.shannon_to_byte(BigDecimal(cell[:capacity]))
        return byte.to_s("F")
      end

      if cell[:udt_info] && cell[:udt_info][:type_hash].present?
        return parse_udt_amount(cell[:udt_info][:amount], cell[:udt_info][:decimal])
      end
    end

    def datetime_utc(timestamp)
      Time.at((timestamp / 1000).to_i).in_time_zone("UTC").strftime("%Y-%m-%d %H:%M:%S")
    end

    def parse_transaction_fee(fee)
      CkbUtils.shannon_to_byte(BigDecimal(fee))
    end

    def parse_udt_amount(amount, decimal)
      decimal_int = decimal.to_i
      amount_big_decimal = BigDecimal(amount)
      result = amount_big_decimal / (BigDecimal(10)**decimal_int)

      if decimal_int > 20
        return "#{result.round(20).to_s('F')}..."
      end

      if result.to_s.length >= 16 || result < BigDecimal("0.000001")
        return result.round(decimal_int).to_s("F")
      end

      return result.to_s("F")
    rescue StandardError => e
      puts "udt amount parse failed: #{e.message}"
      return "0"
    end
  end
end
