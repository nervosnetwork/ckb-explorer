class ChangeArgsColumnTypeToString < ActiveRecord::Migration[6.0]
  def change
    change_column :lock_scripts, :args, :string
    change_column :type_scripts, :args, :string
  end
end
