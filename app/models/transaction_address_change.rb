class TransactionAddressChange < ApplicationRecord
  belongs_to :ckb_transaction
  belongs_to :address
end
