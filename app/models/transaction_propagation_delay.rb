class TransactionPropagationDelay < ApplicationRecord
end

# == Schema Information
#
# Table name: transaction_propagation_delays
#
#  id                       :bigint           not null, primary key
#  tx_hash                  :string
#  created_at_unixtimestamp :integer
#  durations                :jsonb
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_tx_propagation_timestamp  (created_at_unixtimestamp)
#
