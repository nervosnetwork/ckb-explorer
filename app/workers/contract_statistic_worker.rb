class ContractStatisticWorker
  include Sidekiq::Worker
  sidekiq_options queue: "critical"

  def perform
    Contract.find_each do |contract|
      referring_cells = contract.referring_cell_outputs&.live
      deployed_cells = contract.deployed_cell_outputs&.live
      transactions = contract.cell_dependencies

      contract.update(
        ckb_transactions_count: transactions.count,
        deployed_cells_count: deployed_cells&.count.to_i,
        referring_cells_count: referring_cells&.count.to_i,
        total_deployed_cells_capacity: deployed_cells&.sum(:capacity),
        total_referring_cells_capacity: referring_cells&.sum(:capacity)
      )
    end
  end
end
