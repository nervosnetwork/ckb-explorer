class NetInfo
  def id
    Time.current.to_i
  end

  def addresses
    local_node_info.addresses
  end

  def node_id
    local_node_info.node_id
  end

  def version
    local_node_info.version
  end

  def local_node_info
    CkbSync::Api.instance.local_node_info
  end
end
