class UpdateRpcListeningAddrToArray < ActiveRecord::Migration[7.0]
  def change
    change_column :fiber_peers, :rpc_listening_addr, :string, array: true, default: [], using: "(string_to_array(rpc_listening_addr, ','))"
  end
end
