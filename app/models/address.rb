class Address < ApplicationRecord
  PREFIX_MAINNET = "ckb".freeze
  PREFIX_TESTNET = "ckt".freeze

  has_many :cell_outputs, dependent: :destroy
  has_many :account_books, dependent: :destroy
  has_many :ckb_transactions, through: :account_books
  has_many :mining_infos
  has_many :udt_accounts
  validates :balance, :cell_consumed, :ckb_transactions_count, :interest, :dao_deposit, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :visible, -> { where(visible: true) }
  scope :created_after, ->(block_timestamp) { where("block_timestamp >= ?", block_timestamp) }
  scope :created_before, ->(block_timestamp) { where("block_timestamp <= ?", block_timestamp) }

  after_commit :flush_cache

  attr_accessor :query_address

  def custom_ckb_transactions
    ckb_transaction_ids = account_books.select(:ckb_transaction_id).distinct
    CkbTransaction.where(id: ckb_transaction_ids)
  end

  def ckb_dao_transactions
    ckb_transaction_ids = cell_outputs.where(cell_type: %w(nervos_dao_deposit nervos_dao_withdrawing)).select("ckb_transaction_id").distinct
    CkbTransaction.where(id: ckb_transaction_ids)
  end

  def ckb_udt_transactions(type_hash)
    sql =
      <<-SQL
        SELECT
          generated_by_id ckb_transaction_id
        FROM
          cell_outputs
        WHERE
          address_id = #{id}
          AND
          cell_type = #{CellOutput::cell_types['udt']}
          AND
          type_hash = '#{type_hash}'

        UNION

        SELECT
          consumed_by_id ckb_transaction_id
        FROM
          cell_outputs
        WHERE
          address_id = #{id}
          AND
          cell_type = #{CellOutput::cell_types['udt']}
          AND
          type_hash = '#{type_hash}'
          AND
          consumed_by_id is not null
      SQL
    ckb_transaction_ids = CellOutput.select("ckb_transaction_id").from("(#{sql}) as cell_outputs")
    CkbTransaction.where(id: ckb_transaction_ids.distinct)
  end

  def lock_info
    lock_script.lock_info
  end

  def lock_script
    LockScript.where(address: self).first
  end

  def self.find_or_create_address(lock_script, block_timestamp)
    address_hash = CkbUtils.generate_address(lock_script)
    lock_hash = lock_script.compute_hash
    address = Address.find_or_create_by!(address_hash: address_hash, lock_hash: lock_hash)
    address.update(block_timestamp: block_timestamp) if address.block_timestamp.blank?

    address
  end

  def self.find_address!(query_key)
    cached_find(query_key) || raise(Api::V1::Exceptions::AddressNotFoundError)
  end

  def self.cached_find(query_key)
    Rails.cache.realize([name, query_key], race_condition_ttl: 3.seconds) do
      if QueryKeyUtils.valid_hex?(query_key)
        find_by(lock_hash: query_key)
      else
        lock_hash = CkbUtils.parse_address(query_key).script.compute_hash
        address = find_by(lock_hash: lock_hash)
        if address.present?
          address.query_address = query_key
          address
        else
          NullAddress.new(query_key)
        end
      end
    end
  end

  def cached_lock_script
    Rails.cache.realize([self.class.name, "lock_script", lock_hash], race_condition_ttl: 3.seconds) do
      lock_script.to_node_lock
    end
  end

  def flush_cache
    $redis.pipelined do
      $redis.del(*cache_keys)
    end
  end

  def cache_keys
    %W(#{self.class.name}/#{address_hash} #{self.class.name}/#{lock_hash})
  end

  def special?
    Settings.special_addresses[address_hash].present?
  end
end

# == Schema Information
#
# Table name: addresses
#
#  id                     :bigint           not null, primary key
#  balance                :decimal(30, )
#  address_hash           :binary
#  cell_consumed          :decimal(30, )
#  ckb_transactions_count :decimal(30, )    default(0)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  lock_hash              :binary
#  dao_deposit            :decimal(30, )    default(0)
#  interest               :decimal(30, )    default(0)
#  block_timestamp        :decimal(30, )
#  visible                :boolean          default(TRUE)
#  live_cells_count       :decimal(30, )    default(0)
#  mined_blocks_count     :integer          default(0)
#  average_deposit_time   :decimal(, )
#
# Indexes
#
#  index_addresses_on_address_hash  (address_hash)
#  index_addresses_on_lock_hash     (lock_hash) UNIQUE
#
