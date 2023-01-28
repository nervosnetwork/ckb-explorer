require "test_helper"

class ScriptTest < ActiveSupport::TestCase
  setup do
    create :script
  end

  test "create script" do
    script = create :script
    assert_equal false, script.is_contract
    assert_equal '0x441714e000fedf3247292c7f34fb16db14f49d9f', script.args
    assert_equal '0xe04cac9aab8e831537de16a9741f30c164ddf0015ce8e074cc86f7e28ab5914a', script.code_hash
    assert_equal '0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f01855', script.script_hash
  end

  test "update script" do
    script = create :script
    script.update is_contract: true, args: '0x441714e000fedf3247292c7f34fb16db14f49d9f1', script_hash: '0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f018551', code_hash: '0xe04cac9aab8e831537de16a9741f30c164ddf0015ce8e074cc86f7e28ab5914a1'
    assert_equal true, script.is_contract
    assert_equal '0xe04cac9aab8e831537de16a9741f30c164ddf0015ce8e074cc86f7e28ab5914a10', script.code_hash
    assert_equal '0x441714e000fedf3247292c7f34fb16db14f49d9f1', script.args
    assert_equal '0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f018551', script.script_hash
  end

end
