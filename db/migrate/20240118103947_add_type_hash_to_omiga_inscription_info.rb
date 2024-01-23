class AddTypeHashToOmigaInscriptionInfo < ActiveRecord::Migration[7.0]
  def change
    add_column :omiga_inscription_infos, :type_hash, :binary
  end
end
