class Address < ApplicationRecord
  PREFIX_MAINNET = "ckb".freeze
  PREFIX_TESTNET = "ckt".freeze

  has_many :cell_outputs
  has_many :account_books
  has_many :ckb_transactions, through: :account_books
  validates_presence_of :balance, :cell_consumed, :ckb_transactions_count
  validates :balance, :cell_consumed, :ckb_transactions_count, numericality: { greater_than_or_equal_to: 0 }

  attribute :lock_hash, :ckb_hash
  after_commit :flush_cache

  def lock_script
    LockScript.where(address: self).first
  end

  def self.find_or_create_address(lock_script)
    address_hash = CkbUtils.generate_address(lock_script)
    lock_hash = lock_script.to_hash

    Rails.cache.fetch(lock_hash, expires_in: 1.day, race_condition_ttl: 3.seconds) do
      transaction(requires_new: true) { Address.create(address_hash: address_hash, balance: 0, cell_consumed: 0, lock_hash: lock_hash) }
    rescue ActiveRecord::RecordNotUnique
      Address.find_by(lock_hash: lock_hash)
    end
  end

  def self.find_address!(query_key)
    cached_find(query_key) || raise(Api::V1::Exceptions::AddressNotFoundError)
  end

  def self.cached_find(query_key)
    Rails.cache.fetch([name, query_key], race_condition_ttl: 3.seconds) do
      if QueryKeyUtils.valid_hex?(query_key)
        find_by(lock_hash: query_key)
      else
        find_by(address_hash: query_key)
      end
    end
  end

  def cached_lock_script
    Rails.cache.fetch([self.class.name, address_hash, "lock_script"], race_condition_ttl: 3.seconds) do
      lock_script.to_node_lock
    end
  end

  def cached_ckb_transactions(address_or_lock_hash, page, page_size, request)
    Rails.cache.fetch([self.class.name, address_or_lock_hash, "ckb_transactions", page, page_size], race_condition_ttl: 3.seconds) do
      paginated_ckb_transactions = self.ckb_transactions.available.recent.distinct.page(page).per(page_size)
      options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: paginated_ckb_transactions, page: page, page_size: page_size).call
      CkbTransactionSerializer.new(paginated_ckb_transactions, options).serialized_json
    end
  end

  def flush_cache
    Rails.cache.delete([self.class.name, address_hash])
    Rails.cache.delete([self.class.name, lock_hash])
    Rails.cache.delete([self.class.name, address_hash, "lock_script"])
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
#
# Indexes
#
#  index_addresses_on_address_hash  (address_hash)
#  index_addresses_on_lock_hash     (lock_hash) UNIQUE
#
