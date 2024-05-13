module RgbTransactions
  class Index < ActiveInteraction::Base
    string :sort, default: "number.desc"
    string :leap_direction, default: nil
    integer :page, default: 1
    integer :page_size, default: CkbTransaction.default_per_page

    def execute
      order_by, asc_or_desc = transaction_ordering
      annotations = BitcoinAnnotation.includes(:ckb_transaction).
        where("bitcoin_annotations.tags @> array[?]::varchar[]", ["rgbpp"])

      if leap_direction.present?
        annotations = annotations.where("bitcoin_annotations.leap_direction = ?", leap_direction)
      end

      annotations.page(page).per(page_size)
    end

    private

    def transaction_ordering
      sort_by, sort_order = sort.split(".", 2)
      sort_by =
        case sort_by
        when "confirmation", "number"
          "ckb_transactions.block_number"
        when "time"
          "ckb_transactions.block_timestamp"
        end

      if sort_order.nil? || !sort_order.match?(/^(asc|desc)$/i)
        sort_order = "asc"
      end

      [sort_by, sort_order]
    end
  end
end
