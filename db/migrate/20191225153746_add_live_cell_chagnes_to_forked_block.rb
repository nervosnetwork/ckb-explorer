class AddLiveCellChagnesToForkedBlock < ActiveRecord::Migration[6.0]
  def change
    add_column :forked_blocks, :live_cell_changes, :integer
  end
end
