class FiberGraphChannel < ApplicationRecord
  acts_as_paranoid

  MAX_PAGINATES_PER = 100
  DEFAULT_PAGINATES_PER = 10
  paginates_per DEFAULT_PAGINATES_PER
  max_paginates_per MAX_PAGINATES_PER

  belongs_to :udt, optional: true
  belongs_to :open_transaction, class_name: "CkbTransaction"
  belongs_to :closed_transaction, class_name: "CkbTransaction", optional: true
  belongs_to :address
  belongs_to :cell_output

  validates :open_transaction_id, presence: true

  scope :open_channels, -> { where(closed_transaction_id: nil) }

  def open_transaction_info
    open_transaction.as_json(only: %i[tx_hash block_number block_timestamp]).merge(
      {
        capacity: funding_cell.capacity,
        udt_info: funding_cell.udt_info,
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
          udt_info: cell.udt_info,
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

  def deleted_at_timestamp
    return unless deleted_at

    (deleted_at.to_f * 1000).to_i.to_s
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
#  deleted_at                      :datetime
#  cell_output_id                  :bigint
#  address_id                      :bigint
#
# Indexes
#
#  index_fiber_graph_channels_on_address_id        (address_id)
#  index_fiber_graph_channels_on_channel_outpoint  (channel_outpoint) UNIQUE
#  index_fiber_graph_channels_on_deleted_at        (deleted_at)
#
