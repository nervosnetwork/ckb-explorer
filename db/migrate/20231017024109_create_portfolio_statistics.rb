class CreatePortfolioStatistics < ActiveRecord::Migration[7.0]
  def change
    create_table :portfolio_statistics do |t|
      t.bigint :user_id
      t.decimal :capacity, precision: 30, scale: 0, default: 0
      t.decimal :occupied_capacity, precision: 30, scale: 0, default: 0
      t.decimal :dao_deposit, precision: 30, scale: 0, default: 0
      t.decimal :interest, precision: 30, scale: 0, default: 0
      t.decimal :unclaimed_compensation, precision: 30, scale: 0, default: 0

      t.timestamps
    end

    add_index :portfolio_statistics, :user_id, unique: true
  end
end
