class CreateBlockStatistics < ActiveRecord::Migration[6.0]
  def change
    create_table :block_statistics do |t|
      t.string :difficulty
      t.string :hash_rate
      t.string :live_cell_count, default: "0"
      t.string :dead_cell_count, default: "0"
      t.string :block_number

      t.timestamps
    end
  end
end
