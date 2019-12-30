class ForkedEvent < ApplicationRecord
  enum status: { pending: 0, processed: 1 }
end

# == Schema Information
#
# Table name: forked_events
#
#  id              :bigint           not null, primary key
#  block_number    :decimal(30, )
#  epoch_number    :decimal(30, )
#  block_timestamp :decimal(30, )
#  status          :integer          default("pending")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_forked_events_on_status  (status)
#
