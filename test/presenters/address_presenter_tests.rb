require "test_helper"

class AddressPresenterTest < ActiveSupport::TestCase
  test "#transactions_count should return correct transactions count" do
    script_type1 = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], args: ["0xac33e9ca6965beb166204d0c6bf427dcab3b6f4b"], hash_type: "type")
    script_type2 = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], args: ["0xac33e9ca6965beb166204d0c6bf427dcab3b6f4b"], hash_type: "data")
    script_data1 = CKB::Types::Script.new(code_hash: ENV["CODE_HASH"], args: ["0xac33e9ca6965beb166204d0c6bf427dcab3b6f4b"], hash_type: "data")
    script_data2 = CKB::Types::Script.new(code_hash: ENV["CODE_HASH"], args: ["0xac33e9ca6965beb166204d0c6bf427dcab3b6f4b"], hash_type: "type")

    address_hash1 = CkbUtils.generate_address(script_type1)
    address_hash2 = CkbUtils.generate_address(script_type2)
    address_hash3 = CkbUtils.generate_address(script_data1)
    address_hash4 = CkbUtils.generate_address(script_data2)

    addr1 = create(:address, address_hash: address_hash1, lock_hash: script_type1.compute_hash)
    addr2 = create(:address, address_hash: address_hash2, lock_hash: script_type2.compute_hash)
    addr3 = create(:address, address_hash: address_hash3, lock_hash: script_data1.compute_hash)
    addr4 = create(:address, address_hash: address_hash4, lock_hash: script_data2.compute_hash)
    block = create(:block, :with_block_hash)
    transactions = create_list(:ckb_transaction, 8, block: block)
    [addr1, addr2, addr3, addr4].each_with_index do |addr, index|
      addr.ckb_transactions << transactions[index..index + 1]
      addr.ckb_transactions << transactions[index * 2..index * 2 + 1]
    end
    [addr1, addr2, addr3, addr4].map { |addr| addr.update(ckb_transactions_count: addr.ckb_transactions.distinct.count) }
    address = Address.find_address!(address_hash1)
    presented_address = AddressPresenter.new(address)

    assert_equal presented_address.ckb_transactions.count, presented_address.transactions_count
  end
end
