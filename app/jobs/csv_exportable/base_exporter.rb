require "csv"

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
      info = {
        symbol: udt_info&.symbol,
        amount: udt_cell.udt_amount,
        decimal: udt_info&.decimal,
        type_hash: udt_cell.type_hash,
        published: !!udt_info&.published,
      }

      { udt_info: info }
    end

    def token_unit(cell)
      is_dao = cell[:cell_type].in?(%w(nervos_dao_deposit nervos_dao_withdrawing))
      return "CKB" if is_dao

      if cell[:udt_info]
        return cell[:udt_info][:type_hash]
      end

      "CKB"
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

      result.to_s("F")
    rescue StandardError => e
      puts "udt amount parse failed: #{e.message}"
      "0"
    end

    def transfer_method(amount_in, amount_out)
      change = amount_out.to_d - amount_in.to_d
      unless change.zero?
        return change.negative? ? "PAYMENT SENT" : "PAYMENT RECEIVED"
      end

      if amount_in && amount_in.zero?
        amount_out.nil? ? "PAYMENT BURN" : "PAYMENT SEND"
      else
        "PAYMENT MINT"
      end
    end

    def build_ckb_data(input, output)
      capacity_in = input&.dig(:capacity)
      capacity_out = output&.dig(:capacity)

      method = transfer_method(capacity_in, capacity_out)
      capacity_diff = (capacity_out.to_d - capacity_in.to_d).abs

      {
        token_in: begin
          CkbUtils.shannon_to_byte(capacity_in)
        rescue StandardError
          "/"
        end,
        token_out: begin
          CkbUtils.shannon_to_byte(capacity_out)
        rescue StandardError
          "/"
        end,
        balance_diff: CkbUtils.shannon_to_byte(capacity_diff),
        method:,
      }
    end

    def build_udt_data(input, output)
      amount_in = input&.dig(:udt_info, :amount)
      amount_out = output&.dig(:udt_info, :amount)

      method = transfer_method(amount_in, amount_out)
      amount_diff = (amount_out.to_d - amount_in.to_d).abs

      decimal = input&.dig(:udt_info, :decimal) || output&.dig(:udt_info, :decimal)
      if decimal
        {
          token_in: amount_in.nil? ? "/" : parse_udt_amount(amount_in, decimal),
          token_out: amount_out.nil? ? "/" : parse_udt_amount(amount_out, decimal),
          balance_diff: parse_udt_amount(amount_diff, decimal),
          method:,
        }
      else
        {
          token_in: amount_in.nil? ? "/" : "#{amount_in} (raw)",
          token_out: amount_out.nil? ? "/" : "#{amount_out} (raw)",
          balance_diff: "#{amount_diff} (raw)",
          method:,
        }
      end
    end

    def parse_udt_token(input, output)
      udt_info = output&.dig(:udt_info) || input&.dig(:udt_info)
      if udt_info[:published]
        udt_info[:symbol]
      else
        type_hash = udt_info[:type_hash]
        "Unknown Token ##{type_hash[-4..]}"
      end
    end
  end
end
