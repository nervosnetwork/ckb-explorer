class StatisticInfo < ApplicationRecord
  include AttrLogics
  # def initialize(
  #   hash_rate_statistical_interval: (Settings.hash_rate_statistical_interval || 900).to_i,
  # average_block_time_interval: (Settings.average_block_time_interval || 100)
  # )
  #   @hash_rate_statistical_interval = hash_rate_statistical_interval.to_i
  #   @average_block_time_interval = average_block_time_interval.to_i
  # end

  def self.default
    first_or_create!
  end

  def cache_key
    tip_block_number
  end

  def tip_block_number
    tip_block.number
  end

  def tip_block_hash
    tip_block.block_hash
  end

  def epoch_info
    {
      epoch_number: tip_block.epoch.to_s,
      epoch_length: tip_block.length.to_s,
      index: (tip_block_number - tip_block.start_number).to_s
    }
  end

  def estimated_epoch_time
    if hash_rate.present?
      (tip_block.difficulty * tip_block.length / hash_rate).truncate(6)
    end
  end

  def current_epoch_difficulty
    tip_block.difficulty
  end

  define_logic :transactions_last_24hrs do
    Block.h24.sum(:ckb_transactions_count).to_i
  end

  define_logic :transactions_count_per_minute do
    interval = 100
    start_block_number = [tip_block_number.to_i - interval + 1, 0].max
    timestamps = Block.where(number: [start_block_number, tip_block_number]).recent.pluck(:timestamp)
    next if timestamps.empty?

    transactions_count = Block.where(number: start_block_number..tip_block_number).sum(:ckb_transactions_count)

    (transactions_count.to_d / (total_block_time(timestamps) / 1000 / 60)).truncate(3)
  end

  define_logic :average_block_time do
    interval = (Settings.average_block_time_interval || 100)
    start_block_number = [tip_block_number.to_i - interval + 1, 0].max
    timestamps = Block.where(number: [start_block_number, tip_block_number]).recent.pluck(:timestamp)
    next if timestamps.empty?

    total_block_time(timestamps) / blocks_count(interval)
  end

  def self.hash_rate(block_number)
    hash_rate_statistical_interval = Settings.hash_rate_statistical_interval || 900
    blocks = Block.select(:id, :timestamp, :compact_target).
      where("number <= ?", block_number).recent.limit(hash_rate_statistical_interval)
    return if blocks.blank?

    total_difficulties = blocks.sum(&:difficulty)
    total_difficulties += UncleBlock.where(block_id: blocks.map(&:id)).select(:compact_target).to_a.sum(&:difficulty)
    total_time = blocks.first.timestamp - blocks.last.timestamp

    (total_difficulties.to_d / total_time).truncate(6)
  end

  define_logic :hash_rate do
    self.class.hash_rate(tip_block_number)
  end

  define_logic :miner_ranking do
    MinerRanking.new.ranking
  end

  define_logic :address_balance_ranking do
    addresses = Address.visible.where("balance > 0").order(balance: :desc).limit(50)
    addresses.each.with_index(1).map do |address, index|
      { address: address.address_hash, balance: address.balance.to_s, ranking: index.to_s }
    end
  end

  define_logic :blockchain_info do
    message_need_to_be_fitlered_out = "CKB v0.105.* have bugs. Please upgrade to the latest version."
    result = CkbSync::Api.instance.get_blockchain_info
    result.alerts.delete_if { |alert| alert.message == message_need_to_be_fitlered_out }
    result
  end

  define_logic :transaction_fee_rates do
    txs = CkbTransaction.tx_committed.
      where("bytes > 0 and transaction_fee > 0").
      order("id desc").limit(10000).
      pluck(:id, :created_at, :transaction_fee, :bytes, :confirmation_time, :block_timestamp, :created_at)
    txs.map do |id, created_at, transaction_fee, bytes, confirmation_time, block_timestamp|
      if confirmation_time && confirmation_time >= 0
        {
          id: id,
          timestamp: created_at.to_i,
          fee_rate: (transaction_fee.to_f / bytes),
          confirmation_time: confirmation_time < 0 ? 0 : confirmation_time
        }
      else
        b = block_timestamp.to_i / 1000
        a = created_at.to_i
        c = b - a

        CkbTransaction.where(id: id).update_all(confirmation_time: c)
        {
          id: id,
          timestamp: created_at.to_i,
          fee_rate: (transaction_fee.to_f / bytes),
          confirmation_time: c < 0 ? 0 : c
        }
      end
    end
  end

  define_logic :pending_transaction_fee_rates do
    # select from database
    fee_rates = CkbTransaction.tx_pending.
      where("transaction_fee > 0").
      order("id desc").limit(100)

    # This is a patch for those pending tx which has no `bytes`
    fee_rates = fee_rates.map { |tx|
      tx_bytes = 0
      if tx.bytes.blank? || tx.bytes == 0
        Rails.logger.info "== checking tx bytes: #{tx.tx_hash}, #{tx.id}"
        begin
          tx_bytes = CkbSync::Api.instance.get_transaction(tx.tx_hash).transaction.serialized_size_in_block
        rescue Exception => e
          Rails.logger.error "== tx not found"
          tx_bytes = 0
        end
        tx.update bytes: tx_bytes
      end

      tx
    }.select { |e| e.bytes > 0 }

    fee_rates.map do |tx|
      {
        id: tx.id,
        fee_rate: (tx.transaction_fee.to_f / tx.bytes)
      }
    end
  end

  define_logic :last_n_days_transaction_fee_rates do
    CkbTransaction.last_n_days_transaction_fee_rates(20)
  end

  # def self.last_n_days_transaction_fee_rates(timestamp)
  #   sql = <<-SQL
  #   select date_trunc('day', to_timestamp(timestamp/1000.0)) date,
  #     avg(total_transaction_fee / ckb_transactions_count ) fee_rate
  #     from blocks
  #     where timestamp > #{timestamp}
  #       and ckb_transactions_count != 0
  #     group by 1 order by 1 desc
  #   SQL
  #   last_n_days_transaction_fee_rates =
  #     Rails.cache.fetch("last_n_days_transaction_fee_rates", expires_in: 10.seconds) do
  #       ActiveRecord::Base.connection.execute(sql).values
  #     end
  #   return last_n_days_transaction_fee_rates
  # end

  def maintenance_info
    Rails.cache.fetch("maintenance_info")
  end

  def flush_cache_info
    Rails.cache.realize("flush_cache_info") || []
  end

  private

  attr_reader :hash_rate_statistical_interval, :average_block_time_interval

  def total_block_time(timestamps)
    (timestamps.first - timestamps.last).to_d
  end

  def blocks_count(interval = average_block_time_interval)
    tip_block_number > interval ? interval : tip_block_number
  end

  def tip_block
    @tip_block ||= Block.recent.first || OpenStruct.new(number: 0, epoch: 0, length: 0, start_number: 0,
                                                        difficulty: 0)
  end
end

# == Schema Information
#
# Table name: statistic_infos
#
#  id                                :bigint           not null, primary key
#  transactions_last_24hrs           :bigint
#  transactions_count_per_minute     :bigint
#  average_block_time                :float
#  hash_rate                         :decimal(, )
#  address_balance_ranking           :jsonb
#  miner_ranking                     :jsonb
#  blockchain_info                   :string
#  last_n_days_transaction_fee_rates :jsonb
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  pending_transaction_fee_rates     :jsonb
#  transaction_fee_rates             :jsonb
#
