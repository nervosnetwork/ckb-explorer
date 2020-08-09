class TableRecordCount < ApplicationRecord
end

# == Schema Information
#
# Table name: table_record_counts
#
#  id         :bigint           not null, primary key
#  table_name :string
#  count      :bigint
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_table_record_counts_on_table_name_and_count  (table_name,count)
#
