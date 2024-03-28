class AddIsRepeatedSymbolToOmigaInscriptionInfo < ActiveRecord::Migration[7.0]
  def change
    add_column :omiga_inscription_infos, :is_repeated_symbol, :boolean, default: false
  end
end
