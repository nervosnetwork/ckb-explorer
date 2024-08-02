class XudtTag < ApplicationRecord
  belongs_to :udt

  VALID_TAGS = ["unnamed", "invalid", "suspicious", "out-of-length-range", "rgb++", "layer-1-asset", "supply-limited", "utility", "layer-2-asset", "supply-unlimited"]
end

# == Schema Information
#
# Table name: xudt_tags
#
#  id            :bigint           not null, primary key
#  udt_id        :integer
#  udt_type_hash :string
#  tags          :string           default([]), is an Array
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_xudt_tags_on_udt_id  (udt_id) UNIQUE
#
