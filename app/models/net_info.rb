class NetInfo
  def id
    Time.current.to_i
  end

  def addresses
    local_node_info.addresses
  end

  def is_outbound
    local_node_info.is_outbound
  end

  def node_id
    local_node_info.node_id
  end

  def version
    local_node_info.version
  end

  def local_node_info
    Rails.cache.realize("local_node_info") do
      CkbSync::Api.instance.local_node_info
    end
  end
end
