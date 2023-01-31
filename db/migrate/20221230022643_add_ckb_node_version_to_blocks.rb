class AddCkbNodeVersionToBlocks < ActiveRecord::Migration[7.0]
  def change
    add_column :blocks, :ckb_node_version, :string, default: nil, comment: 'ckb node version, e.g. 0.105.1'
    add_column :forked_blocks, :ckb_node_version, :string, default: nil, comment: 'ckb node version, e.g. 0.105.1'
  end
end
