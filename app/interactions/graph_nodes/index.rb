module GraphNodes
  class Index < ActiveInteraction::Base
    string :key, default: nil
    integer :page, default: 1
    integer :page_size, default: FiberGraphNode.default_per_page

    def execute
      scope = FiberGraphNode.with_deleted
      scope = scope.where("node_name = :key or peer_id = :key or node_id = :key", key:) if key
      scope.page(page).per(page_size).fast_page
    end
  end
end
