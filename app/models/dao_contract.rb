class DaoContract < ApplicationRecord
  validates :total_deposit, :interest_granted, :deposit_transactions_count, :withdraw_transactions_count, :depositors_count, :total_depositors_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  CONTRACT_NAME = "nervos_dao".freeze

  def self.default_contract
    find_or_create_by(id: 1)
  end

  def ckb_transactions
    ckb_transaction_ids = CellOutput.nervos_dao_deposit.pluck("generated_by_id") + CellOutput.nervos_dao_withdrawing.pluck("consumed_by_id").compact
    CkbTransaction.where(id: ckb_transaction_ids)
  end
end

# == Schema Information
#
# Table name: dao_contracts
#
#  id                          :bigint           not null, primary key
#  total_deposit               :decimal(30, )    default(0)
#  interest_granted            :decimal(30, )    default(0)
#  deposit_transactions_count  :bigint           default(0)
#  withdraw_transactions_count :bigint           default(0)
#  depositors_count            :integer          default(0)
#  total_depositors_count      :bigint           default(0)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
