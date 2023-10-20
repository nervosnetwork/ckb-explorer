class CreatePortfolios < ActiveRecord::Migration[7.0]
  def change
    create_table :portfolios do |t|
      t.bigint :user_id
      t.bigint :address_id
    end

    add_index :portfolios, [:user_id, :address_id], unique: true
  end
end
