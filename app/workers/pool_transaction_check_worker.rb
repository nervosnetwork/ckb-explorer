# Check every pending transaction in the pool if rejected
class PoolTransactionCheckWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform
    # Because iterating over all pool transaction entry record and get tx detail from CKB Node one by one
    # will make heavy load to CKB node, slowing block processing, sometimes will lead to HTTP timeout
    # So here we directly check the inputs and dependencies of the transaction locally in database
    # If any of the input or dependency cells is used, the transaction will never be valid.
    # Thus we can directly mark this transaction rejected without requesting to CKB Node.
    # Only request the CKB Node for reject reason after we find the transaction is rejected.
    pending_transactions = CkbTransaction.tx_pending.
      includes(:cell_dependencies, cell_inputs: :previous_cell_output).
      order(id: :asc).limit(150)
    pending_transactions.each do |tx|
      is_rejected = false
      rejected_transaction = nil
      # check if any input is used by other transactions
      tx.cell_inputs.each do |input|
        if input.previous_cell_output && input.previous_cell_output.dead?
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
        # check if any dependency cell(contract) is consumed by other transactions
        tx.cell_dependencies.each do |dep|
          if dep.cell_output && dep.cell_output.dead?
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
        AfterCommitEverywhere.after_commit do
          # fetch the reason from node
          PoolTransactionUpdateRejectReasonWorker.perform_async tx.tx_hash
        end
        CkbTransaction.where(tx_hash: tx.tx_hash).update_all tx_status: :rejected # , detailed_message: reason
      end
    end
  end
end
