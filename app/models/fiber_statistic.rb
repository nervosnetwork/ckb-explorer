class FiberStatistic < ApplicationRecord
  include AttrLogics

  VALID_INDICATORS = %w(total_nodes total_channels total_capacity created_at_unixtimestamp).freeze

  scope :filter_by_indicator, ->(indicator) {
    raise ArgumentError, "Invalid indicator" unless VALID_INDICATORS.include?(indicator.to_s)

    select(indicator, :created_at_unixtimestamp)
  }

  define_logic(:total_nodes) { FiberGraphNode.count }
  define_logic(:total_channels) { FiberGraphChannel.count }
  define_logic(:total_capacity) { FiberGraphChannel.sum(:capacity) }

  define_logic :total_liquidity do
    result = Hash.new { |h, k| h[k] = 0.0 }

    FiberGraphNode.find_each do |node|
      channels = FiberGraphChannel.with_deleted.where(node1: node.node_id).or(
        FiberGraphChannel.with_deleted.where(node2: node.node_id),
      ).where(closed_transaction_id: nil)

      channels.each do |channel|
        funding_cell = channel.funding_cell
        if funding_cell.cell_type.in?(%w(udt xudt xudt_compatible))
          result[funding_cell.type_hash] += funding_cell.udt_amount
        else
          result[""] += channel.capacity
        end
      end
    end

    CkbUtils.hash_value_to_s(result)
  end

  define_logic :mean_value_locked do
    total_channels.zero? ? 0.0 : total_capacity.to_f / total_channels
  end

  define_logic :mean_fee_rate do
    rates = FiberGraphChannel.all.filter_map do |ch|
      r1 = ch.update_info_of_node1["fee_rate"]
      r2 = ch.update_info_of_node2["fee_rate"]
      next unless r1 && r2

      r1.to_i + r2.to_i
    end

    rates.any? ? rates.sum.to_f / rates.size : 0.0
  end

  define_logic :medium_value_locked do
    capacities = FiberGraphChannel.pluck(:capacity).compact
    calculate_median(capacities)
  end

  define_logic :medium_fee_rate do
    combined_fee_rates = FiberGraphChannel.all.flat_map do |ch|
      [
        ch.update_info_of_node1["fee_rate"]&.to_i,
        ch.update_info_of_node2["fee_rate"]&.to_i,
      ]
    end.compact

    calculate_median(combined_fee_rates)
  end

  def calculate_median(array)
    sorted = array.sort
    count = sorted.size
    return nil if count.zero?

    if count.odd?
      sorted[count / 2]
    else
      (sorted[(count / 2) - 1] + sorted[count / 2]).to_f / 2
    end
  end

  def parsed_total_liquidity
    total_liquidity&.map do |type_hash, amount|
      if type_hash.present?
        udt_info = Udt.find_by(type_hash: type_hash)
        CkbUtils.hash_value_to_s(
          symbol: udt_info.symbol,
          amount: amount,
          decimal: udt_info.decimal,
          type_hash: type_hash,
          published: !!udt_info.published,
        )
      else
        CkbUtils.hash_value_to_s(symbol: "CKB", amount: amount)
      end
    end
  end

  def as_json(_options = {})
    CkbUtils.hash_value_to_s(
      total_nodes:,
      total_channels:,
      total_capacity:,
      mean_value_locked:,
      mean_fee_rate:,
      medium_value_locked:,
      medium_fee_rate:,
      created_at_unixtimestamp:,
    ).merge(total_liquidity: parsed_total_liquidity)
  end
end

# == Schema Information
#
# Table name: fiber_statistics
#
#  id                       :bigint           not null, primary key
#  total_nodes              :integer
#  total_channels           :integer
#  total_capacity           :bigint
#  mean_value_locked        :bigint
#  mean_fee_rate            :integer
#  medium_value_locked      :bigint
#  medium_fee_rate          :integer
#  created_at_unixtimestamp :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  total_liquidity          :jsonb
#
# Indexes
#
#  index_fiber_statistics_on_created_at_unixtimestamp  (created_at_unixtimestamp) UNIQUE
#
