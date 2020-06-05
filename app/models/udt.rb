class Udt < ApplicationRecord
  enum udt_type: { sudt: 0 }

  validates_presence_of :total_amount
  validates_length_of :symbol, minimum: 1, maximum: 16, allow_nil: true
  validates_length_of :full_name, minimum: 1, maximum: 32, allow_nil: true
  validates :decimal, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 39 }, allow_nil: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }

  attribute :code_hash, :ckb_hash

  def ckb_transactions
    ckb_transaction_ids = CellOutput.udt.where(type_hash: type_hash).pluck("generated_by_id") + CellOutput.udt.where(type_hash: type_hash).pluck("consumed_by_id").compact
    CkbTransaction.where(id: ckb_transaction_ids.uniq)
  end

  def h24_ckb_transactions_count
    Rails.cache.realize("udt_h24_ckb_transactions_count_#{id}", expires_in: 1.hour) do
      ckb_transactions.where("block_timestamp >= ?", CkbUtils.time_in_milliseconds(24.hours.ago)).count
    end
  end
end

# == Schema Information
#
# Table name: udts
#
#  id               :bigint           not null, primary key
#  code_hash        :binary
#  hash_type        :string
#  args             :string
#  type_hash        :string
#  full_name        :string
#  symbol           :string
#  decimal          :integer
#  description      :string
#  icon_file        :string
#  operator_website :string
#  addresses_count  :decimal(30, )    default(0)
#  total_amount     :decimal(40, )    default(0)
#  udt_type         :integer
#  published        :boolean          default(FALSE)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  block_timestamp  :decimal(30, )
#
# Indexes
#
#  index_udts_on_type_hash  (type_hash) UNIQUE
#
