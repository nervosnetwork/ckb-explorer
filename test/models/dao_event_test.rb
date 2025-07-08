require "test_helper"

class DaoEventTest < ActiveSupport::TestCase
  should validate_presence_of(:value)
  should validate_numericality_of(:value).
    is_greater_than_or_equal_to(0)

  test "should have correct columns" do
    dao_event = create(:dao_event)
    expected_attributes = %w(address_id block_id block_timestamp contract_id created_at event_type id status ckb_transaction_id updated_at value cell_index consumed_transaction_id
                             consumed_block_timestamp cell_output_id).sort
    assert_equal expected_attributes, dao_event.attributes.keys.sort
  end
end
