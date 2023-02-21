class UdtAddressTransaction < ActiveRecord::Base
  belongs_to :ckb_transaction
  belongs_to :address, foreign_key: "udt_address_id", class_name: "Address"

  # Usage:
  # bundle exec rails c
  # rails > UdtAddressTransaction.create_initial_data CkbTransaction.all
  def self.create_initial_data ckb_transactions
    ckb_transactions.find_each do |ckb_transaction|
      UdtAddressTransaction.transaction do
        next if ckb_transaction.udt_address_ids.blank?
        ckb_transaction.udt_address_ids.each do |udt_address_id|
          UdtAddressTransaction.create udt_address_id: udt_address_id, ckb_transaction_id: ckb_transaction.id
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: udt_address_transactions
#
#  id                 :bigint           not null, primary key
#  udt_address_id     :bigint
#  ckb_transaction_id :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_udt_address_transactions_on_ckb_transaction_id  (ckb_transaction_id)
#  index_udt_address_transactions_on_udt_address_id      (udt_address_id)
#
