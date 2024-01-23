class AddPreUdtHashToOmigaInscriptionInfo < ActiveRecord::Migration[7.0]
  def change
    add_column :omiga_inscription_infos, :pre_udt_hash, :binary
  end
end
