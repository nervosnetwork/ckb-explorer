class ContractStatisticWorker
  include Sidekiq::Worker
  sidekiq_options queue: "critical"

  def perform
    h24_tx_ids = CkbTransaction.h24.pluck(:id)
    pool_size = 10
    pool = Concurrent::FixedThreadPool.new(pool_size)

    Contract.find_each do |contract|
      # ckb_address_ids = fetch_ckb_address_ids(contract, pool)
      contract.update(
        ckb_transactions_count: contract.cell_dependencies.count,
        h24_ckb_transactions_count: contract.cell_dependencies.where(ckb_transaction_id: h24_tx_ids).count,
        deployed_cells_count: contract.deployed_cell_outputs&.live&.size,
        referring_cells_count: contract.referring_cell_outputs.live.size,
        total_deployed_cells_capacity: contract.deployed_cell_outputs&.live&.sum(:capacity),
        total_referring_cells_capacity: contract.referring_cell_outputs.live.sum(:capacity),
        # addresses_count: ckb_address_ids.count,
      )
    end

    # 关闭线程池
    pool.shutdown
    pool.wait_for_termination
  end

  private

  def fetch_ckb_address_ids(contract, pool)
    ckb_address_ids = Concurrent::Set.new

    futures = []

    contract.referring_cell_outputs.live.find_in_batches(batch_size: 10_000) do |batch|
      futures << Concurrent::Promises.future_on(pool) do
        batch.each { |cell_output| ckb_address_ids.add(cell_output.address_id) }
      end
    end

    Concurrent::Promises.zip(*futures).value!

    ckb_address_ids
  end
end
