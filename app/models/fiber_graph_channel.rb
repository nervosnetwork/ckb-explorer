class FiberGraphChannel < ApplicationRecord
  acts_as_paranoid

  MAX_PAGINATES_PER = 100
  DEFAULT_PAGINATES_PER = 10
  paginates_per DEFAULT_PAGINATES_PER
  max_paginates_per MAX_PAGINATES_PER

  has_many :fiber_account_books
  belongs_to :udt, optional: true
  belongs_to :open_transaction, class_name: "CkbTransaction"
  belongs_to :closed_transaction, class_name: "CkbTransaction", optional: true
  belongs_to :funding_cell, class_name: "CellOutput", foreign_key: :cell_output_id
  belongs_to :address

  validates :open_transaction_id, presence: true

  scope :open_channels, -> { where(closed_transaction_id: nil) }

  def open_transaction_info
    {
      tx_hash: open_transaction.tx_hash,
      block_number: open_transaction.block_number,
      block_timestamp: open_transaction.block_timestamp,
      capacity: funding_cell.capacity,
      udt_info: funding_cell.udt_info,
      address: funding_cell.address_hash,
    }
  end

  def closed_transaction_info
    return Hash.new unless closed_transaction

    {
      tx_hash: closed_transaction.tx_hash,
      block_number: closed_transaction.block_number,
      block_timestamp: open_transaction.block_timestamp,
    }.merge(
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
#  update_info_of_node1            :jsonb
#  update_info_of_node2            :jsonb
#
# Indexes
#
#  index_fiber_graph_channels_on_address_id        (address_id)
#  index_fiber_graph_channels_on_channel_outpoint  (channel_outpoint) UNIQUE
#  index_fiber_graph_channels_on_deleted_at        (deleted_at)
#
