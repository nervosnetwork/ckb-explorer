require "test_helper"

class XudtTagWorkerTest < ActiveJob::TestCase
  setup do
    @address = create(:address, address_hash: "ckb1qz7xc452rgxs5z0ks3xun46dmdp58sepg0ljtae8ck0d7nah945nvqgqqqqqqx3l3v4")
  end

  test "when xudt with no symbol" do
    create(:udt, :xudt, symbol: nil)
    assert_changes -> { XudtTag.count }, from: 0, to: 1 do
      XudtTagWorker.new.perform
    end
    assert_equal ["rgb++", "layer-2-asset", "supply-unlimited"], XudtTag.last.tags
  end

  test "insert to xudt_tags successfully" do
    udt = create(:udt, :xudt)
    create(:xudt_tag, udt_id: udt.id, udt_type_hash: udt.type_hash, tags: ["out-of-length-range"])
    create(:udt, :xudt, symbol: "CKBB", issuer_address: @address.address_hash)
    assert_changes -> { XudtTag.count }, from: 1, to: 2 do
      XudtTagWorker.new.perform
    end
    assert_equal ["rgb++", "layer-1-asset", "supply-limited"], XudtTag.last.tags
  end

  test "insert invalid tag" do
    create(:udt, :xudt, symbol: "ü")
    assert_changes -> { XudtTag.count }, from: 0, to: 1 do
      XudtTagWorker.new.perform
    end
    assert_equal ["invalid", "rgb++"], XudtTag.last.tags
  end

  test "insert suspicious tag" do
    create(:udt, :xudt, symbol: "CK  BB")
    assert_changes -> { XudtTag.count }, from: 0, to: 1 do
      XudtTagWorker.new.perform
    end
    assert_equal ["suspicious", "rgb++"], XudtTag.last.tags
  end

  test "insert out-of-length-range tag" do
    create(:udt, :xudt, symbol: "CKBBBB" * 11)
    assert_changes -> { XudtTag.count }, from: 0, to: 1 do
      XudtTagWorker.new.perform
    end
    assert_equal ["out-of-length-range", "rgb++"], XudtTag.last.tags
  end

  test "insert utility tag" do
    create(:udt, :xudt, symbol: "CKBBB", args: "0xdd6faefeffaa7d2a7b2e6890713c5fa4bbf378add1cfc1b27672a50a6ad3e83500000040")
    assert_changes -> { XudtTag.count }, from: 0, to: 1 do
      XudtTagWorker.new.perform
    end
    assert_equal ["utility", "rgb++"], XudtTag.last.tags
  end
end
