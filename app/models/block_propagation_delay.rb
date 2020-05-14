class BlockPropagationDelay < ApplicationRecord
end

# == Schema Information
#
# Table name: block_propagation_delays
#
#  id                       :bigint           not null, primary key
#  block_hash               :string
#  created_at_unixtimestamp :integer
#  durations                :jsonb
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_block_propagation_delays_on_created_at_unixtimestamp  (created_at_unixtimestamp)
#
