namespace :migration do
  task update_multisig_addresses: :environment do
    locks = LockScript.where(code_hash: %w(0xc1fb0ae6915d3d4eded3498aedf5faddd8c5f6bd8921e0f8bfabd5ebcbf259bc 0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8))
    locks.each do |lock|
      address = lock.address
      script = CKB::Types::Script.new(**lock.to_node_lock)
      multisig_address = CkbUtils.generate_address(script)
      puts "Original address: #{address.address_hash}, New address: #{multisig_address}"
      address.update!(address_hash: multisig_address)
    end

    puts "done"
  end
end
