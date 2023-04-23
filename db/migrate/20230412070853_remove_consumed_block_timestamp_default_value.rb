class RemoveConsumedBlockTimestampDefaultValue < ActiveRecord::Migration[7.0]
  def change
    change_column_default :cell_outputs, :consumed_block_timestamp, from: 0, to: nil
    reversible do |dir|
      dir.up do
        CellOutput.where.not(consumed_block_timestamp: nil).where(consumed_by_id: nil).update_all(consumed_block_timestamp: nil)
      end
      dir.down do
      end
    end
  end
end
