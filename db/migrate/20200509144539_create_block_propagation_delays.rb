class CreateBlockPropagationDelays < ActiveRecord::Migration[6.0]
  def change
    create_table :block_propagation_delays do |t|
      t.string :block_hash
      t.integer :created_at_unixtimestamp, index: true
      t.jsonb :durations

      t.timestamps
    end
  end
end
