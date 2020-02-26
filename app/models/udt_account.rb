class UdtAccount < ApplicationRecord
  enum udt_type: { sudt: 0 }

  belongs_to :address

  validates_presence_of :full_name, :symbol, :decimal, :amount
  validates_length_of :symbol, minimum: 1, maximum: 16
  validates :decimal, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 39 }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
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
#  amount     :decimal(40, )
#  address_id :bigint
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_udt_accounts_on_address_id  (address_id)
#
