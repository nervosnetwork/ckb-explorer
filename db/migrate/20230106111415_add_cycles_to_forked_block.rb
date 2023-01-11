class AddCyclesToForkedBlock < ActiveRecord::Migration[7.0]
  def change
    add_column :forked_blocks, :cycles, :integer
  end
end
