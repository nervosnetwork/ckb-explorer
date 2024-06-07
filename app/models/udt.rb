class Udt < ApplicationRecord
  MAX_PAGINATES_PER = 100

  belongs_to :nrc_factory_cell, optional: true
  has_one :udt_verification
  has_one :omiga_inscription_info
  has_one :xudt_tag

  enum udt_type: { sudt: 0, m_nft_token: 1, nrc_721_token: 2, spore_cell: 3,
                   omiga_inscription: 4, xudt: 5, xudt_compatible: 6 }

  validates_presence_of :total_amount
  validates :decimal,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 39 }, allow_nil: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :email,
            format: { with: /\A(.+)@(.+)\z/, message: "Not a valid email" }, allow_nil: true

  scope :query_by_name_or_symbl, ->(search) {
                                   where("lower(full_name) LIKE ? or lower(symbol) LIKE ?", "%#{search}%", "%#{search}%")
                                 }
  scope :published_xudt, -> { where(udt_type: %i[xudt xudt_compatible], published: true) }

  attribute :code_hash, :ckb_hash

  has_and_belongs_to_many :ckb_transactions, join_table: :udt_transactions

  def update_h24_ckb_transactions_count
    if ckb_transactions.exists?
      update(h24_ckb_transactions_count: ckb_transactions.where("block_timestamp >= ?",
                                                                CkbUtils.time_in_milliseconds(24.hours.ago)).count)
    end
  end

  def type_script
    return unless published

    {
      args:,
      code_hash:,
      hash_type:,
    }
  end
end

# == Schema Information
#
# Table name: udts
#
#  id                         :bigint           not null, primary key
#  code_hash                  :binary
#  hash_type                  :string
#  args                       :string
#  type_hash                  :string
#  full_name                  :string
#  symbol                     :string
#  decimal                    :integer
#  description                :string
#  icon_file                  :string
#  operator_website           :string
#  addresses_count            :bigint           default(0)
#  total_amount               :decimal(40, )    default(0)
#  udt_type                   :integer
#  published                  :boolean          default(FALSE)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  block_timestamp            :bigint
#  issuer_address             :binary
#  ckb_transactions_count     :bigint           default(0)
#  nrc_factory_cell_id        :bigint
#  display_name               :string
#  uan                        :string
#  h24_ckb_transactions_count :bigint           default(0)
#  email                      :string
#
# Indexes
#
#  index_udts_on_type_hash  (type_hash) USING hash
#  unique_type_hash         (type_hash) UNIQUE
#
