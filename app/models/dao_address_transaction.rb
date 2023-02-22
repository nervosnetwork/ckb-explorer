class DaoAddressTransaction < ActiveRecord::Base
  belongs_to :ckb_transaction
  belongs_to :address, foreign_key: "dao_address_id", class_name: "Address"

  # Usage:
  # bundle exec rails c
  # rails > DaoAddressTransaction.create_initial_data CkbTransaction.all
  def self.create_initial_data ckb_transactions
    ckb_transactions.find_each do |ckb_transaction|
      DaoAddressTransaction.transaction do
        next if ckb_transaction.dao_address_ids.blank?
        ckb_transaction.dao_address_ids.each do |dao_address_id|
          DaoAddressTransaction.find_or_create_by dao_address_id: dao_address_id, ckb_transaction_id: ckb_transaction.id
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: dao_address_transactions
#
#  id                 :bigint           not null, primary key
#  dao_address_id     :bigint
#  ckb_transaction_id :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_dao_address_transactions_on_ckb_transaction_id  (ckb_transaction_id)
#  index_dao_address_transactions_on_dao_address_id      (dao_address_id)
#
