class Address < ApplicationRecord
  PREFIX_MAINNET = "ckb".freeze
  PREFIX_TESTNET = "ckt".freeze

  has_many :cell_outputs, dependent: :destroy
  has_many :account_books, dependent: :destroy
  has_many :ckb_transactions, through: :account_books, counter_cache: true
  has_many :mining_infos
  has_many :udt_accounts
  has_many :dao_events
  validates :balance, :cell_consumed, :ckb_transactions_count, :interest, :dao_deposit,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :lock_hash, presence: true, uniqueness: true

  scope :visible, -> { where(visible: true) }
  scope :created_after, ->(block_timestamp) { where("block_timestamp >= ?", block_timestamp) }
  scope :created_before, ->(block_timestamp) { where("block_timestamp <= ?", block_timestamp) }

  after_commit :flush_cache

  attr_accessor :query_address

  def custom_ckb_transactions
    ckb_transactions
  end

  has_and_belongs_to_many :ckb_dao_transactions, class_name: "CkbTransaction", join_table: "address_dao_transactions"

  def ckb_udt_transactions(udt)
    udt = Udt.find_by_id(udt) unless udt.is_a?(Udt)
    udt&.ckb_transactions || []
  end

  def lock_info
    lock_script.lock_info
  end

  def lock_script
    if lock_script_id
      Rails.cache.realize(["Address", "lock_script", id], race_condition_ttl: 3.seconds) do
        LockScript.where(address_id: self)&.first || LockScript.find(lock_script_id)
      end
    else
      create_lock_script
    end
  end

  def create_lock_script
    addr = CkbUtils.parse_address address_hash
    script = addr.script
    ls = LockScript.find_or_create_by code_hash: script.code_hash, hash_type: script.hash_type, args: script.args
    ls.update address_id: self.id
    self.update lock_script_id: ls.id
    ls
  end

  def self.find_by_address_hash(address_hash, *args, **kargs)
    parsed = CkbUtils.parse_address(address_hash)
    lock_hash = parsed.script.compute_hash
    find_by lock_hash: lock_hash
  end

  def self.find_or_create_by_address_hash(address_hash, block_timestamp = 0)
    parsed = CkbUtils.parse_address(address_hash)
    lock_hash = parsed.script.compute_hash
    lock_script = LockScript.find_by(
      code_hash: parsed.code_hash,
      hash_type: parsed.hash_type,
      args: parsed.args
    )

    create_with(
      address_hash: CkbUtils.generate_address(parsed.script),
      block_timestamp: block_timestamp,
      lock_script_id: lock_script&.id
    ).find_or_create_by lock_hash: lock_hash
  end

  def self.find_or_create_by_lock(lock_script)
    lock_hash = lock_script.compute_hash
    address_hash = CkbUtils.generate_address(lock_script)
    address = Address.find_or_initialize_by(lock_hash: lock_hash)
    # force use new version address
    address.address_hash = address_hash
    address.lock_script = LockScript
    address.save!
    address
  end

  # @param lock_script [CKB::Types::Script]
  # @param block_timestamp [Integer]
  # @param lock_script_id [Integer]
  # @return [Address]
  def self.find_or_create_address(lock_script, block_timestamp, lock_script_id = nil)
    lock_hash = lock_script.compute_hash
    address_hash = CkbUtils.generate_address(lock_script, CKB::Address::Version::CKB2019)
    address_hash_2021 = CkbUtils.generate_address(lock_script, CKB::Address::Version::CKB2021)

    address = Address.find_by(lock_hash: lock_hash)
    if address.blank?
      address = Address.new lock_hash: lock_hash
    end

    # force use new version address
    address.address_hash = address_hash_2021
    address.block_timestamp ||= block_timestamp
    address.lock_script_id ||= lock_script_id
    if address.balance < 0 || address.balance_occupied < 0 # wrong balance, recalculate balance
      Rails.logger.info "#{address.address_hash} balance #{address.balance}, #{address.balance_occupied} < 0, resetting"
      wrong_balance = address.balance
      address.cal_balance!
      Rails.logger.info "#{address.address_hash} balance #{address.balance}, #{address.balance_occupied}"
      Sentry.capture_message(
        "Reset balance",
        extra: {
          address: address.address_hash,
          wrong_balance: wrong_balance,
          calced_balance: address.balance,
          calced_occupied_balance: address.balance_occupied
        }
      )
    end
    address.save!
    address
  end

  def self.find_address!(query_key)
    cached_find(query_key) || raise(Api::V1::Exceptions::AddressNotFoundError)
  end

  def self.cached_find(query_key)
    cache_key = query_key
    unless QueryKeyUtils.valid_hex?(query_key)
      cache_key = CkbUtils.parse_address(query_key).script.compute_hash
    end
    address =
      Rails.cache.realize([name, cache_key], race_condition_ttl: 3.seconds) do
        if QueryKeyUtils.valid_hex?(query_key)
          find_by(lock_hash: query_key)
        else
          lock_hash = CkbUtils.parse_address(query_key).script.compute_hash
          find_by(lock_hash: lock_hash)
        end
      end
    unless QueryKeyUtils.valid_hex?(query_key)
      if address.present?
        address.query_address = query_key
      else
        address = NullAddress.new(query_key)
      end
    end
    address
  end

  def cached_lock_script
    if lock_script_id
      Rails.cache.realize([self.class.name, "lock_script", lock_hash], race_condition_ttl: 3.seconds) do
        lock_script.to_node
      end
    else
      addr = CkbUtils.parse_address address_hash
      script = addr.script
      {
        code_hash: script.code_hash,
        args: script.args,
        hash_type: script.hash_type
      }
    end
  end

  def flush_cache
    $redis.pipelined do
      Rails.cache.delete_multi(cache_keys)
    end
  end

  def cache_keys
    %W(#{self.class.name}/#{lock_hash})
  end

  def special?
    Settings.special_addresses[address_hash].present?
  end

  def cal_unclaimed_compensation
    phase1_dao_interests + unmade_dao_interests
  end

  def tx_list_cache_key
    "Address/txs/#{id}"
  end

  def recalc_revalidate_balance!
    cell_outputs.find_each do |c|
      if c.status == "dead" and !c.consumed_by
        c.update  status: "live", consumed_by_id: nil, consumed_block_timestamp: nil
      end
    end
    cal_balance!
    save!
  end

  def cal_balance
    total = cell_outputs.live.sum(:capacity)
    occupied = cell_outputs.live.occupied.sum(:capacity)
    [total, occupied]
  end

  def cal_balance!
    self.balance, self.balance_occupied = cal_balance
  end

  def cal_balance_occupied
    cell_outputs.live.find_each.map { |cell|
      next if cell.type_hash.blank? && (cell.data.present? && cell.data == "0x")

      cell.capacity
    }.compact.sum
  end

  def cal_balance_occupied_inner_block(block_id)
    cell_outputs.inner_block(block_id).live.find_each.map { |cell|
      next if cell.type_hash.blank? && (cell.data.present? && cell.data == "0x")

      cell.capacity
    }.compact.sum
  end

  private

  def phase1_dao_interests
    cell_outputs.nervos_dao_withdrawing.live.find_each.reduce(0) do |memo, nervos_dao_withdrawing_cell|
      memo + CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
    end
  end

  def unmade_dao_interests
    tip_dao = Block.recent.first.dao
    cell_outputs.nervos_dao_deposit.live.find_each.reduce(0) do |memo, cell_output|
      memo + DaoCompensationCalculator.new(cell_output, tip_dao).call
    end
  end
end

# == Schema Information
#
# Table name: addresses
#
#  id                     :bigint           not null, primary key
#  balance                :decimal(30, )    default(0)
#  address_hash           :binary
#  cell_consumed          :bigint
#  ckb_transactions_count :bigint           default(0)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  lock_hash              :binary
#  dao_deposit            :decimal(30, )    default(0)
#  interest               :decimal(30, )    default(0)
#  block_timestamp        :bigint
#  live_cells_count       :bigint           default(0)
#  mined_blocks_count     :integer          default(0)
#  visible                :boolean          default(TRUE)
#  average_deposit_time   :bigint
#  unclaimed_compensation :decimal(30, )
#  is_depositor           :boolean          default(FALSE)
#  dao_transactions_count :bigint           default(0)
#  lock_script_id         :bigint
#  balance_occupied       :decimal(30, )    default(0)
#
# Indexes
#
#  index_addresses_on_address_hash  (address_hash) USING hash
#  index_addresses_on_is_depositor  (is_depositor) WHERE (is_depositor = true)
#  index_addresses_on_lock_hash     (lock_hash) USING hash
#  unique_lock_hash                 (lock_hash) UNIQUE
#
