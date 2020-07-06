class AddIsDepositorToAddresses < ActiveRecord::Migration[6.0]
  def change
    add_column :addresses, :is_depositor, :boolean, default: false
    add_index :addresses, :is_depositor, where: "is_depositor = true"
  end
end
