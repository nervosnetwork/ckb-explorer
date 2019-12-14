class Address < ApplicationRecord
  PREFIX_MAINNET = "ckb".freeze
  PREFIX_TESTNET = "ckt".freeze

  has_many :cell_outputs, dependent: :destroy
  has_many :account_books, dependent: :destroy
  has_many :ckb_transactions, through: :account_books
  validates :balance, :cell_consumed, :ckb_transactions_count, :interest, :dao_deposit, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :visible, -> { where(visible: true) }

  after_commit :flush_cache

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
        where(address_hash: query_key).to_a.presence || NullAddress.new(query_key)
      end
    end
  end

  def cached_lock_script
    Rails.cache.realize([self.class.name, "lock_script", lock_hash], race_condition_ttl: 3.seconds) do
      lock_script.to_node_lock
    end
  end

  def flush_cache
    Rails.cache.delete([self.class.name, address_hash])
    Rails.cache.delete([self.class.name, lock_hash])
  end

  def special?
    Settings.special_addresses[address_hash].present?
  end
end

# == Schema Information
#
# Table name: addresses
#
#  id                          :bigint           not null, primary key
#  balance                     :decimal(30, )
#  address_hash                :binary
#  cell_consumed               :decimal(30, )
#  ckb_transactions_count      :decimal(30, )    default(0)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  lock_hash                   :binary
#  pending_reward_blocks_count :integer          default(0)
#  dao_deposit                 :decimal(30, )    default(0)
#  interest                    :decimal(30, )    default(0)
#  block_timestamp             :decimal(30, )
#  visible                     :boolean          default(TRUE)
#
# Indexes
#
#  index_addresses_on_address_hash  (address_hash)
#  index_addresses_on_lock_hash     (lock_hash) UNIQUE
#
