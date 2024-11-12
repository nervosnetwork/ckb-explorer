class GenerateCellDependenciesWorker
  include Sidekiq::Worker

  def perform(block_id)
    block = Block.find_by(id: block_id)
    return unless block

    tx_cell_deps = build_cell_deps(block.number)
    block.ckb_transactions.each do |txs|
      CellDependency.parse_cell_dpes_from_ckb_transaction(txs, tx_cell_deps[txs.tx_hash])
    end
  end

  def build_cell_deps(number)
    node_block = CkbSync::Api.instance.get_block_by_number(number)
    node_block.transactions.each_with_object({}) do |tx, deps|
      deps[tx.hash] = tx.cell_deps
    end
  end
end
