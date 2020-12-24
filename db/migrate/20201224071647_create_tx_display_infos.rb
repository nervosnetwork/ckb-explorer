class CreateTxDisplayInfos < ActiveRecord::Migration[6.0]
  def change
    create_table :tx_display_infos, id: false do |t|
      t.bigint :ckb_transaction_id, primary_key: true, default: nil
      t.jsonb :inputs
      t.jsonb :outputs

      t.timestamps
    end
  end
end
