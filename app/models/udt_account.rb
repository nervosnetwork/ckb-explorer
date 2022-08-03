class UdtAccount < ApplicationRecord
  enum udt_type: { sudt: 0, m_nft_token: 1, nrc_721_token: 2 }

  belongs_to :address
  belongs_to :udt

  validates_presence_of :amount
  validates_length_of :symbol, minimum: 1, maximum: 16, allow_nil: true
  validates_length_of :full_name, minimum: 1, maximum: 100, allow_nil: true
  validates :decimal, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 39 }, allow_nil: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  delegate :display_name, :uan, to: :udt

  attribute :code_hash, :ckb_hash

  scope :published, -> { where(published: true) }

  def udt_icon_file
    Rails.cache.realize([self.class.name, "udt_icon_file", id], race_condition_ttl: 3.seconds, expires_in: 1.day) do
      udt.icon_file
    end
  end
end

# == Schema Information
#
# Table name: udt_accounts
#
#  id           :bigint           not null, primary key
#  udt_type     :integer
#  full_name    :string
#  symbol       :string
#  decimal      :integer
#  amount       :decimal(40, )    default(0)
#  published    :boolean          default(FALSE)
#  code_hash    :binary
#  type_hash    :string
#  address_id   :bigint
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  udt_id       :bigint
#  nft_token_id :string
#
# Indexes
#
#  index_udt_accounts_on_address_id                (address_id)
#  index_udt_accounts_on_type_hash_and_address_id  (type_hash,address_id) UNIQUE
#  index_udt_accounts_on_udt_id                    (udt_id)
#
