class Udt < ApplicationRecord
  enum udt_type: { sudt: 0 }

  validates_presence_of :full_name, :symbol, :decimal, :total_amount
  validates_length_of :symbol, minimum: 1, maximum: 16
  validates_length_of :full_name, minimum: 1, maximum: 32
  validates :decimal, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 39 }
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }

  attribute :code_hash, :ckb_hash
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
#
# Indexes
#
#  index_udts_on_type_hash  (type_hash) UNIQUE
#
