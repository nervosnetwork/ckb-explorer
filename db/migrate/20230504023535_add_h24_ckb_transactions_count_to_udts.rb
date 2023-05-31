class AddH24CkbTransactionsCountToUdts < ActiveRecord::Migration[7.0]
  def up
    add_column :udts, :h24_ckb_transactions_count, :bigint, default: 0

    Udt.all.each do |udt|
      h24_ckb_transactions_count = Rails.cache.realize("udt_h24_ckb_transactions_count_#{udt.id}", expires_in: 1.hour) do
        udt.ckb_transactions.where("block_timestamp >= ?", CkbUtils.time_in_milliseconds(24.hours.ago)).count
      end

      udt.update_columns(h24_ckb_transactions_count: h24_ckb_transactions_count)
    end
  end

  def down
    remove_column :udts, :h24_ckb_transactions_count, :bigint, default: 0
  end
end
