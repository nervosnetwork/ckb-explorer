class RejectReason < ApplicationRecord
  belongs_to :ckb_transaction
  validates :ckb_transaction_id, uniqueness: true
end

# == Schema Information
#
# Table name: reject_reasons
#
#  id                 :bigint           not null, primary key
#  ckb_transaction_id :bigint           not null
#  message            :text
#
# Indexes
#
#  index_reject_reasons_on_ckb_transaction_id  (ckb_transaction_id) UNIQUE
#
