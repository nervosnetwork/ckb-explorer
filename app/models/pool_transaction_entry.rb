class PoolTransactionEntry < ApplicationRecord
  enum tx_status: { pending: 0, proposed: 1, committed: 2 }

  def is_cellbase
    false
  end

  def income
    nil
  end
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
#  size            :decimal(30, )
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
