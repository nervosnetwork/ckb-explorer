class CreateCellData < ActiveRecord::Migration[7.0]
  def change
    create_table :cell_data, id: false do |t|
      t.bigint :cell_output_id, null: false, primary_key: true
      t.binary :data, null: false
    end
  end
end
