class ContractStatisticWorker
  include Sidekiq::Worker
  sidekiq_options queue: "critical"

  def perform
    h24_tx_ids = CkbTransaction.h24.pluck(:id)
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    Contract.where(verified: true).find_each do |contract|
      contract_cell_ids = CellDepsOutPoint.list_contract_cell_ids_by_contract([contract.id])
      ckb_transactions_count = CellDependency.where(contract_cell_id: contract_cell_ids).select(:ckb_transaction_id).distinct.count
      h24_ckb_transactions_count = CellDependency.where(contract_cell_id: contract_cell_ids, ckb_transaction_id: h24_tx_ids).select(:ckb_transaction_id).distinct.count
      referring_cells_count = Contract.referring_cells_query([contract]).count
      total_deployed_cells_capacity = CellOutput.find(contract.deployed_cell_output_id).capacity
      total_referring_cells_capacity = Contract.referring_cells_query([contract]).sum(:capacity)
      addresses_count = Contract.referring_cells_query([contract]).distinct(:address_id).count

      contract.update(
        ckb_transactions_count:,
        h24_ckb_transactions_count:,
        deployed_cells_count: 1,
        referring_cells_count:,
        total_deployed_cells_capacity:,
        total_referring_cells_capacity:,
        addresses_count:,
      )
    end
  end
end
