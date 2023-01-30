class CreateContracts < ActiveRecord::Migration[7.0]
  def self.up
    create_table :contracts do |t|
      t.binary :code_hash
      t.string :hash_type
      t.string :deployed_args
      t.string :role
      t.string :name
      t.string :symbol
      t.boolean :verified, default: false

      t.timestamps null: false
    end

    add_index :contracts, :code_hash
    add_index :contracts, :hash_type
    add_index :contracts, :name
    add_index :contracts, :role
    add_index :contracts, :symbol
    add_index :contracts, :verified
    Contract.create code_hash: '0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8', hash_type: 'type'
    Contract.create code_hash: '0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8', hash_type: 'type'
    Contract.create code_hash: '0xd369597ff47f29fbc0d47d2e3775370d1250b85140c670e4718af712983a2354', hash_type: 'type'
    Contract.create code_hash: '0x82d76d1b75fe2fd9a27dfbaa65a039221a380d76c926f378d3f81cf3e7e13f2e', hash_type: 'type'
    Contract.create code_hash: '0x5e7a36a77e68eecc013dfa2fe6a23f3b6c344b04005808694ae6dd45eea4cfd5', hash_type: 'type'
    Contract.create code_hash: '0xd01f5152c267b7f33b9795140c2467742e8424e49ebe2331caec197f7281b60a', hash_type: 'type'
    Contract.create code_hash: '0x1122a4fb54697cf2e6e3a96c9d80fd398a936559b90954c6e88eb7ba0cf652df', hash_type: 'type'
    Contract.create code_hash: '0x90ca618be6c15f5857d3cbd09f9f24ca6770af047ba9ee70989ec3b229419ac7', hash_type: 'type'
    Contract.create code_hash: '0xbf43c3602455798c1a61a596e0d95278864c552fafe231c063b3fabf97a8febc', hash_type: 'type'
    Contract.create code_hash: '0x000f87062a2fe9bb4a6cc475212ea11014b84deb32e0375ee51e6ec4a553e009', hash_type: 'type'
    Contract.create code_hash: '0xff602581f07667eef54232cce850cbca2c418b3418611c132fca849d1edcd775', hash_type: 'type'
    Contract.create code_hash: '0x3714af858b8b82b2bb8f13d51f3cffede2dd8d352a6938334bb79e6b845e3658', hash_type: 'type'
  end

  def self.down
    drop_table :contracts
    remove_index :contracts, :code_hash
    remove_index :contracts, :hash_type
    remove_index :contracts, :name
    remove_index :contracts, :role
    remove_index :contracts, :symbol
    remove_index :contracts, :verified
  end

end
