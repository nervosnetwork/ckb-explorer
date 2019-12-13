class AddVisibleToAddress < ActiveRecord::Migration[6.0]
  def change
    add_column :addresses, :visible, :boolean, default: true
  end
end
