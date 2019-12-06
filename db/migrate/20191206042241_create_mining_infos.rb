class CreateMiningInfos < ActiveRecord::Migration[6.0]
  def change
    create_table :mining_infos do |t|
      t.bigint :address_id
      t.bigint :block_id
      t.integer :status, limit: 1, default: "0"

      t.timestamps
    end
  end
end
