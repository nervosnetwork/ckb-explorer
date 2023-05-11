class ChangeGlobalStatistic < ActiveRecord::Migration[7.0]
  def change
    add_index :global_statistics, :name, unique: true
    reversible do |dir|
      dir.up do
        change_column :global_statistics, :value, :bigint
      end
      dir.down do
        change_column :global_statistics, :value, :integer
      end
    end
  end
end
