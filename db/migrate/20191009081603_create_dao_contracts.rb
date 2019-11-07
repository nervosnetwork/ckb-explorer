class CreateDaoContracts < ActiveRecord::Migration[6.0]
  def change
    create_table :dao_contracts do |t|
      t.decimal "total_deposit", precision: 30, default: "0"
      t.decimal "subsidy_granted", precision: 30, default: "0"
      t.bigint "deposit_transactions_count", default: "0"
      t.bigint "withdraw_transactions_count", default: "0"
      t.integer "depositors_count", default: "0"
      t.bigint "total_depositors_count", default: "0"
      t.references

      t.timestamps
    end
  end
end
