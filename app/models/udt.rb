class Udt < ApplicationRecord
  belongs_to :nrc_factory_cell, optional: true

  MAX_PAGINATES_PER = 100
  enum udt_type: { sudt: 0, m_nft_token: 1, nrc_721_token: 2 }

  validates_presence_of :total_amount
  validates_length_of :symbol, minimum: 1, maximum: 16, allow_nil: true
  validates_length_of :full_name, minimum: 1, maximum: 100, allow_nil: true
  validates :decimal, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 39 }, allow_nil: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }

  attribute :code_hash, :ckb_hash

  def ckb_transactions
    CkbTransaction.where("contained_udt_ids @> array[?]::bigint[]", [id]) # .optimizer_hints("indexscan(ckb_transactions index_ckb_transactions_on_contained_udt_ids)")
  end

  def h24_ckb_transactions_count
    ckb_transactions.where("block_timestamp >= ?", CkbUtils.time_in_milliseconds(24.hours.ago)).count
  end

  def type_script
    return unless published

    {
      args: args,
      code_hash: code_hash,
      hash_type: hash_type
    }
  end


end

# == Schema Information
#
# Table name: udts
#
#  id                     :bigint           not null, primary key
#  code_hash              :binary
#  hash_type              :string
#  args                   :string
#  type_hash              :string
#  full_name              :string
#  symbol                 :string
#  decimal                :integer
#  description            :string
#  icon_file              :string
#  operator_website       :string
#  addresses_count        :decimal(30, )    default(0)
#  total_amount           :decimal(40, )    default(0)
#  udt_type               :integer
#  published              :boolean          default(FALSE)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  block_timestamp        :decimal(30, )
#  issuer_address         :binary
#  ckb_transactions_count :decimal(30, )    default(0)
#  nrc_factory_cell_id    :bigint
#  display_name           :string
#  uan                    :string
#
# Indexes
#
#  index_udts_on_type_hash  (type_hash) USING hash
#  unique_type_hash         (type_hash) UNIQUE
#
