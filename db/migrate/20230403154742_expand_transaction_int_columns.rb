class ExpandTransactionIntColumns < ActiveRecord::Migration[7.0]
  def up
    change_table :ckb_transactions, bulk: true do |t|
      t.change :bytes, :bigint
      t.change :cycles, :bigint
    end
  end

  def down
    change_table :ckb_transactions, bulk: true do |t|
      t.change :bytes, :integer
      t.change :cycles, :integer
    end
  end
end
