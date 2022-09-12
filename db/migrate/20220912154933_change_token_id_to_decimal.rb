class ChangeTokenIdToDecimal < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        change_column :token_items, :token_id, :decimal, precision: 80
      end
      dir.down do
        change_column :token_items, :token_id, :integer
      end
    end
  end
end
