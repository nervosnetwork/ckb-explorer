class ContractStatisticWorker
  include Sidekiq::Worker
  sidekiq_options queue: "critical"

  def perform
    Contract.find_each do |contract|
      contract.update(
        ckb_transactions_count: contract.cell_dependencies.count,
        deployed_cells_count: contract.deployed_cell_outputs&.live&.size,
        referring_cells_count: contract.referring_cell_outputs&.size,
        total_deployed_cells_capacity: contract.deployed_cell_outputs&.live&.sum(:capacity),
        total_referring_cells_capacity: contract.referring_cell_outputs&.live&.sum(:capacity)
      )
    end
  end
end
