class PoolTransactionEntry < ApplicationRecord
  enum tx_status: { pending: 0, proposed: 1, committed: 2 }, _prefix: :pool_transaction

  def is_cellbase
    false
  end

  def income(address = nil)
    nil
  end

  def display_outputs(previews: false)
    self.attributes["display_outputs"]
  end

  def display_inputs(previews: false)
    self.attributes["display_inputs"]
  end

  def proposal_short_id
    tx_hash[0...12]
  end

  def display_inputs_info; end
end

# == Schema Information
#
# Table name: pool_transaction_entries
#
#  id              :bigint           not null, primary key
#  cell_deps       :jsonb
#  tx_hash         :binary
#  header_deps     :jsonb
#  inputs          :jsonb
#  outputs         :jsonb
#  outputs_data    :jsonb
#  version         :integer
#  witnesses       :jsonb
#  transaction_fee :decimal(30, )
#  block_number    :decimal(30, )
#  block_timestamp :decimal(30, )
#  cycles          :decimal(30, )
#  tx_size         :decimal(30, )
#  display_inputs  :jsonb
#  display_outputs :jsonb
#  tx_status       :integer          default("pending")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_pool_transaction_entries_on_tx_hash  (tx_hash) UNIQUE
#
