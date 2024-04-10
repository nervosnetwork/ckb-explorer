module RgbTransactions
  class Index < ActiveInteraction::Base
    string :sort, default: "number.desc"
    string :leap_direction, default: nil
    integer :page, default: 1
    integer :page_size, default: CkbTransaction.default_per_page

    def execute
      order_by, asc_or_desc = transaction_ordering
      transactions = CkbTransaction.where("tags @> array[?]::varchar[]", ["rgbpp"]).
        order(order_by => asc_or_desc)

      if leap_direction.present?
        transactions = transactions.where(
          "CASE
           WHEN (SELECT COUNT(*) FROM bitcoin_vins WHERE ckb_transaction_id = ckb_transactions.id) <
                (SELECT COUNT(*) FROM bitcoin_vouts WHERE ckb_transaction_id = ckb_transactions.id AND op_return = false)
           THEN 'in'
           WHEN (SELECT COUNT(*) FROM bitcoin_vins WHERE ckb_transaction_id = ckb_transactions.id) >
                (SELECT COUNT(*) FROM bitcoin_vouts WHERE ckb_transaction_id = ckb_transactions.id AND op_return = false)
           THEN 'out'
           ELSE 'equal'
           END = ?", leap_direction
        )
      end

      transactions.page(page).per(page_size)
    end

    private

    def transaction_ordering
      sort_by, sort_order = sort.split(".", 2)
      sort_by =
        case sort_by
        when "confirmation", "number"
          "block_number"
        when "time"
          "block_timestamp"
        end

      if sort_order.nil? || !sort_order.match?(/^(asc|desc)$/i)
        sort_order = "asc"
      end

      [sort_by, sort_order]
    end
  end
end
