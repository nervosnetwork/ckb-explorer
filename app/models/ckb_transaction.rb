class CkbTransaction < ApplicationRecord
  MAX_PAGINATES_PER = 100
  paginates_per 10
  max_paginates_per MAX_PAGINATES_PER

  belongs_to :block
  has_many :account_books
  has_many :addresses, through: :account_books
  has_many :cell_inputs, dependent: :delete_all
  has_many :cell_outputs, dependent: :delete_all
  has_many :inputs, class_name: "CellOutput", inverse_of: "consumed_by", foreign_key: "consumed_by_id"
  has_many :outputs, class_name: "CellOutput", inverse_of: "generated_by", foreign_key: "generated_by_id"

  attribute :tx_hash, :ckb_hash
  attribute :header_deps, :ckb_array_hash, hash_length: ENV["DEFAULT_HASH_LENGTH"]

  scope :recent, -> { order(block_timestamp: :desc) }
  scope :cellbase, -> { where(is_cellbase: true) }

  after_commit :flush_cache

  def self.cached_find(query_key)
    Rails.cache.fetch([name, query_key]) do
      find_by(tx_hash: query_key)
    end
  end

  def flush_cache
    Rails.cache.delete([self.class.name, tx_hash])
  end

  def display_inputs
    if is_cellbase
      cellbase = Cellbase.new(block)
      [{ id: nil, from_cellbase: true, capacity: nil, address_hash: nil, target_block_number: cellbase.target_block_number }]
    else
      self.cell_inputs.order(:id).map do |input|
        previous_cell_output = input.previous_cell_output
        { id: input.id, from_cellbase: false, capacity: previous_cell_output.capacity, address_hash: previous_cell_output.address_hash }
      end
    end
  end

  def display_outputs
    if is_cellbase
      outputs = cell_outputs.order(:id)
      cellbase = Cellbase.new(block)
      outputs.map { |output| { id: output.id, capacity: output.capacity, address_hash: output.address_hash, target_block_number: cellbase.target_block_number, base_reward: cellbase.base_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward, secondary_reward: cellbase.secondary_reward } }
    else
      cell_outputs.order(:id).map do |output|
        { id: output.id, capacity: output.capacity, address_hash: output.address_hash }
      end
    end
  end
end

# == Schema Information
#
# Table name: ckb_transactions
#
#  id              :bigint           not null, primary key
#  tx_hash         :binary
#  deps            :jsonb
#  block_id        :bigint
#  block_number    :decimal(30, )
#  block_timestamp :decimal(30, )
#  transaction_fee :decimal(30, )
#  version         :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  is_cellbase     :boolean          default(FALSE)
#  witnesses       :jsonb
#  header_deps     :binary
#  cell_deps       :jsonb
#
# Indexes
#
#  index_ckb_transactions_on_block_id_and_block_timestamp  (block_id,block_timestamp)
#  index_ckb_transactions_on_is_cellbase                   (is_cellbase)
#  index_ckb_transactions_on_tx_hash_and_block_id          (tx_hash,block_id) UNIQUE
#
