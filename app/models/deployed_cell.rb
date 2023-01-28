class DeployedCell < ApplicationRecord
end

# == Schema Information
#
# Table name: deployed_cells
#
#  id             :bigint           not null, primary key
#  cell_id        :bigint
#  contract_id    :bigint
#  is_initialized :boolean          default(FALSE)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
