class FiberGraphChannel < ApplicationRecord
  MAX_PAGINATES_PER = 100
  DEFAULT_PAGINATES_PER = 10
  paginates_per DEFAULT_PAGINATES_PER
  max_paginates_per MAX_PAGINATES_PER

  belongs_to :udt, optional: true
  belongs_to :open_transaction, class_name: "CkbTransaction"
  belongs_to :closed_transaction, class_name: "CkbTransaction", optional: true

  validates :open_transaction_id, presence: true

  scope :open_channels, -> { where(closed_transaction_id: nil) }

  def open_transaction_info
    open_transaction.as_json(only: %i[tx_hash block_number block_timestamp]).merge(
      {
        capacity: funding_cell.capacity,
        udt_amount: funding_cell.udt_amount,
        address: funding_cell.address_hash,
      },
    )
  end

  def closed_transaction_info
    return Hash.new unless closed_transaction

    closed_transaction.as_json(only: %i[tx_hash block_number block_timestamp]).merge(
      close_accounts: closed_transaction.outputs.map do |cell|
        {
          capacity: cell.capacity,
          udt_amount: cell.udt_amount,
          address: cell.address_hash,
        }
      end,
    )
  end

  def udt_info
    udt&.as_json(only: %i[full_name symbol decimal icon_file])
  end

  def funding_cell
    open_transaction.outputs.includes(:lock_script).find_by(
      lock_scripts: { code_hash: Settings.fiber_funding_code_hash },
    )
  end
end

# == Schema Information
#
# Table name: fiber_graph_channels
#
#  id                              :bigint           not null, primary key
#  channel_outpoint                :string
#  node1                           :string
#  node2                           :string
#  created_timestamp               :bigint
#  capacity                        :decimal(64, 2)   default(0.0)
#  chain_hash                      :string
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  udt_id                          :bigint
#  open_transaction_id             :bigint
#  closed_transaction_id           :bigint
#  last_updated_timestamp_of_node1 :bigint
#  last_updated_timestamp_of_node2 :bigint
#  fee_rate_of_node1               :decimal(30, )    default(0)
#  fee_rate_of_node2               :decimal(30, )    default(0)
#
# Indexes
#
#  index_fiber_graph_channels_on_channel_outpoint  (channel_outpoint) UNIQUE
#
