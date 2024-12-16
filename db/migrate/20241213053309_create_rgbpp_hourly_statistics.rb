class CreateRgbppHourlyStatistics < ActiveRecord::Migration[7.0]
  def change
    create_table :rgbpp_hourly_statistics do |t|
      t.integer :xudt_count, default: 0
      t.integer :dob_count, default: 0
      t.integer :created_at_unixtimestamp
      t.timestamps
    end

    add_index :rgbpp_hourly_statistics, :created_at_unixtimestamp, unique: true
  end
end
