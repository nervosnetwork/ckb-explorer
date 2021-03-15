class TxDisplayInfo < ApplicationRecord
end

# == Schema Information
#
# Table name: tx_display_infos
#
#  ckb_transaction_id :bigint           not null, primary key
#  inputs             :jsonb
#  outputs            :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  income             :jsonb
#
