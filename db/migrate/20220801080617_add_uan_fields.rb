class AddUanFields < ActiveRecord::Migration[6.1]
  def change
    add_column :udts, :display_name, :string
    add_column :udts, :uan, :string
  end
end
