class FiberUdtCfgInfo < ApplicationRecord
  belongs_to :fiber_graph_node
  belongs_to :udt

  def udt_info
    udt.as_json(only: %i[full_name symbol decimal icon_file])
  end
end

# == Schema Information
#
# Table name: fiber_udt_cfg_infos
#
#  id                  :bigint           not null, primary key
#  fiber_graph_node_id :bigint
#  udt_id              :bigint
#  auto_accept_amount  :decimal(64, 2)   default(0.0)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_fiber_udt_cfg_infos_on_fiber_graph_node_id_and_udt_id  (fiber_graph_node_id,udt_id) UNIQUE
#
