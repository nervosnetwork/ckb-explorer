class CreateForkedEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :forked_events do |t|
      t.decimal :block_number, precision: 30
      t.decimal :epoch_number, precision: 30
      t.decimal :block_timestamp, precision: 30
      t.integer :status, limit: 1, default: 0, index: true

      t.timestamps
    end
  end
end
