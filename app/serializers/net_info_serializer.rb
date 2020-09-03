class NetInfoSerializer
  include FastJsonapi::ObjectSerializer

  attribute :addresses, if: Proc.new { |_record, params|
    params && params[:info_name] == "addresses"
  }

  attribute :node_id, if: Proc.new { |_record, params|
    params && params[:info_name] == "node_id"
  }

  attribute :version, if: Proc.new { |_record, params|
    params && params[:info_name] == "version"
  }

  attribute :local_node_info, if: Proc.new { |_record, params|
    params && params[:info_name] == "local_node_info"
  }
end
