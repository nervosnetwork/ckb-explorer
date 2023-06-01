# save the relationship of dao transactions in address
class AddressBlockSnapshot < ApplicationRecord
  belongs_to :block
  belongs_to :address
end

# == Schema Information
#
# Table name: address_block_snapshots
#
#  id           :bigint           not null, primary key
#  address_id   :bigint
#  block_id     :bigint
#  block_number :bigint
#  final_state  :jsonb
#
# Indexes
#
#  index_address_block_snapshots_on_address_id               (address_id)
#  index_address_block_snapshots_on_block_id                 (block_id)
#  index_address_block_snapshots_on_block_id_and_address_id  (block_id,address_id) UNIQUE
#
