class Witness < ApplicationRecord
  belongs_to :ckb_transaction
  attribute :data, :ckb_hash
end

# == Schema Information
#
# Table name: witnesses
#
#  id                 :bigint           not null, primary key
#  data               :binary           not null
#  ckb_transaction_id :bigint           not null
#  index              :integer          not null
#
# Indexes
#
#  index_witnesses_on_ckb_transaction_id            (ckb_transaction_id)
#  index_witnesses_on_ckb_transaction_id_and_index  (ckb_transaction_id,index) UNIQUE
#
