class BlockStatistic < ApplicationRecord
end

# == Schema Information
#
# Table name: block_statistics
#
#  id              :bigint           not null, primary key
#  difficulty      :string
#  hash_rate       :string
#  live_cell_count :string           default("0")
#  dead_cell_count :string           default("0")
#  block_number    :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
