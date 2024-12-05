class AddTransactionIdToFiberGraphChannels < ActiveRecord::Migration[7.0]
  def change
    change_table :fiber_graph_channels, bulk: true do |t|
      t.bigint :open_transaction_id
      t.bigint :closed_transaction_id
    end
  end
end
