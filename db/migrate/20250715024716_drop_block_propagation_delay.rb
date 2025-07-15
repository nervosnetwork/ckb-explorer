class DropBlockPropagationDelay < ActiveRecord::Migration[7.0]
  def change
    drop_table :block_propagation_delays, if_exists: true
  end
end
