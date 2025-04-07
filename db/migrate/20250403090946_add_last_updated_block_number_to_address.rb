class AddLastUpdatedBlockNumberToAddress < ActiveRecord::Migration[7.0]
  def change
    remove_columns :addresses, :cell_consumed
    add_column :addresses, :last_updated_block_number, :bigint
  end
end
