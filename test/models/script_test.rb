require "test_helper"

class ScriptTest < ActiveSupport::TestCase
  setup do
    @script = create :script
  end

  test "create script" do
    assert_equal false, @script.is_contract
    assert_equal '0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f01855', @script.script_hash
  end

  test "update script" do
    @script.update is_contract: true, args: '0x441714e000fedf3247292c7f34fb16db14f49d9f1', script_hash: '0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f018551'
    assert_equal true, @script.is_contract
    assert_equal '0x441714e000fedf3247292c7f34fb16db14f49d9f1', @script.args
    assert_equal '0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f018551', @script.script_hash
  end

end
