# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

if Rails.env.production? && Contract.find_by(name: "Zero Lock").nil?
  puts "Creating Zero Lock contract..."
  Contract.create!(
    hash_type: "data",
    name: "Zero Lock",
    verified: true,
    deprecated: false,
    type_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
    data_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
    deployed_cell_output_id: CellOutput.live.where(data_size: 0).first.id,
    deployed_block_timestamp: Block.find_by(number: 0).timestamp,
    is_type_script: false,
    is_lock_script: true,
    is_primary: true,
    is_zero_lock: true,
  )
end
