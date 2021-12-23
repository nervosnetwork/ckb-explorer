class PoolTransactionCheckWorker
  include Sidekiq::Worker

  def perform
    pool_tx_entry_attributes = []
    PoolTransactionEntry.pool_transaction_pending.select(:id, :inputs, :created_at, :cell_deps).each do |tx|
      tx.inputs.each do |input|
        if CellOutput.where(tx_hash: input["previous_output"]["tx_hash"], cell_index: input["previous_output"]["index"], status: "dead").exists?
          pool_tx_entry_attributes << { id: tx.id, tx_status: "rejected", created_at: tx.created_at, updated_at: Time.current }
          break
        end
      end
      tx.cell_deps.each do |input|
        if CellOutput.where(tx_hash: input["out_point"]["tx_hash"], cell_index: input["out_point"]["index"], status: "dead").exists?
          pool_tx_entry_attributes << { id: tx.id, tx_status: "rejected", created_at: tx.created_at, updated_at: Time.current }
          break
        end
      end
    end

    pool_tx_entry_attributes = pool_tx_entry_attributes.group_by {|tx| tx[:id]}.map {|_, items| items[0]}.flatten
    PoolTransactionEntry.upsert_all(pool_tx_entry_attributes) if pool_tx_entry_attributes.present?
  end
end
