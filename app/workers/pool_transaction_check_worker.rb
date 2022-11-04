class PoolTransactionCheckWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform
    pool_tx_entry_attributes = []
    # Because iterating over all pool transaction entry record and get tx detail from CKB Node one by one
    # will make heavy load to CKB node, slowing block processing, sometimes will lead to HTTP timeout
    # So here we directly check the inputs and dependencies of the transaction locally in database
    # If any of the input or dependency cells is used, the transaction will never be valid.
    # Thus we can directly mark this transaction rejected without requesting to CKB Node.
    # Only request the CKB Node for reject reason after we find the transaction is rejeceted.
    PoolTransactionEntry.pool_transaction_pending.select(:id, :tx_hash, :inputs, :created_at, :cell_deps).find_each do |tx|
      is_rejected = false
      rejected_transaction = nil
      tx.inputs.each do |input|
        if CellOutput.where(tx_hash: input["previous_output"]["tx_hash"], cell_index: input["previous_output"]["index"], status: "dead").exists?
          rejected_transaction = {
            id: tx.id,
            tx_status: "rejected",
            created_at: tx.created_at,
            updated_at: Time.current
          }
          is_rejected = true
          break
        end
      end
      unless is_rejected
        tx.cell_deps.each do |input|
          if CellOutput.where(tx_hash: input["out_point"]["tx_hash"], cell_index: input["out_point"]["index"], status: "dead").exists?
            rejected_transaction = {
              id: tx.id,
              tx_status: "rejected",
              created_at: tx.created_at,
              updated_at: Time.current
            }
            is_rejected = true
            break
          end
        end
      end
      if is_rejected
        PoolTransactionUpdateRejectReasonWorker.perform_async tx.tx_hash, rejected_transaction
      end
    end
  end
end
