class CreateTableRecordCounts < ActiveRecord::Migration[6.0]
  def change
    create_table :table_record_counts do |t|
      t.string :table_name
      t.bigint :count

      t.timestamps
    end

    add_index :table_record_counts, [:table_name, :count]
  end
end
