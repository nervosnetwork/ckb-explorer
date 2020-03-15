class UdtAccount < ApplicationRecord
  enum udt_type: { sudt: 0 }

  belongs_to :address

  validates_presence_of :amount
  validates_length_of :symbol, minimum: 1, maximum: 16, allow_nil: true
  validates_length_of :full_name, minimum: 1, maximum: 32, allow_nil: true
  validates :decimal, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 39 }, allow_nil: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  attribute :code_hash, :ckb_hash

  scope :published, -> { where(published: true) }
end

# == Schema Information
#
# Table name: udt_accounts
#
#  id         :bigint           not null, primary key
#  udt_type   :integer
#  full_name  :string
#  symbol     :string
#  decimal    :integer
#  amount     :decimal(40, )    default(0)
#  published  :boolean          default(FALSE)
#  code_hash  :binary
#  type_hash  :string
#  address_id :bigint
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_udt_accounts_on_address_id                (address_id)
#  index_udt_accounts_on_type_hash_and_address_id  (type_hash,address_id) UNIQUE
#
