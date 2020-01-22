class AddAverageDepositTimeToAddress < ActiveRecord::Migration[6.0]
  def change
    add_column :addresses, :average_deposit_time, :decimal
  end
end
