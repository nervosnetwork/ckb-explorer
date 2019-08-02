class RemoveSyncInfos < ActiveRecord::Migration[5.2]
  def change
    drop_table :sync_infos
  end
end
