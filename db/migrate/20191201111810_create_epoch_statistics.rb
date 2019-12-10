class CreateEpochStatistics < ActiveRecord::Migration[6.0]
  def change
    create_table :epoch_statistics do |t|
      t.string :difficulty
      t.string :uncle_rate
      t.string :epoch_number

      t.timestamps
    end
  end
end
