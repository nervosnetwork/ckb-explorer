class CreateRgbppAssetsStatistics < ActiveRecord::Migration[7.0]
  def change
    create_table :rgbpp_assets_statistics do |t|
      t.integer :indicator, null: false
      t.decimal :value, precision: 40, default: 0.0
      t.integer :network, default: 0
      t.integer :created_at_unixtimestamp

      t.timestamps
    end

    add_index :rgbpp_assets_statistics, %i[indicator network created_at_unixtimestamp], unique: true,
                                                                                        name: "index_on_indicator_and_network_and_created_at_unixtimestamp"
  end
end
