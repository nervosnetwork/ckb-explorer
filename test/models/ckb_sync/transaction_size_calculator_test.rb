require "test_helper"

module CkbSync
  class TransactionSizeCalculatorTest < ActiveSupport::TestCase
    test "matches the SDK for transactions with raw hex witnesses" do
      tx = build_transaction(
        witnesses: ["0x", "0x#{SecureRandom.hex(85)}", "0x#{SecureRandom.hex(16)}"],
      )

      assert_equal tx.serialized_size_in_block,
                   TransactionSizeCalculator.serialized_size_in_block(tx)
    end

    test "matches the SDK for transactions with witness args objects" do
      tx = build_transaction(
        witnesses: [
          CKB::Types::Witness.new(
            lock: "0x#{SecureRandom.hex(65)}",
            input_type: "0x#{SecureRandom.hex(8)}",
            output_type: nil,
          ),
          CKB::Types::Witness.new,
          "0x#{SecureRandom.hex(10)}",
        ],
      )

      assert_equal tx.serialized_size_in_block,
                   TransactionSizeCalculator.serialized_size_in_block(tx)
    end

    test "matches the SDK without type script and with empty args" do
      tx = build_transaction(
        outputs: [
          CKB::Types::Output.new(
            capacity: "0x174876e800",
            lock: CKB::Types::Script.new(
              code_hash: "0x#{SecureRandom.hex(32)}", hash_type: "data", args: "0x",
            ),
            type: nil,
          ),
        ],
        outputs_data: ["0x"],
      )

      assert_equal tx.serialized_size_in_block,
                   TransactionSizeCalculator.serialized_size_in_block(tx)
    end

    private

    def build_transaction(witnesses: ["0x"], outputs: nil, outputs_data: nil)
      outputs ||= [
        build_output,
        build_output(type: build_script(32)),
        build_output(args_bytes: 0),
      ]
      outputs_data ||= ["0x", "0x#{SecureRandom.hex(16)}", "0x"]

      CKB::Types::Transaction.new(
        version: 0,
        cell_deps: [build_cell_dep, build_cell_dep],
        header_deps: ["0x#{SecureRandom.hex(32)}"],
        inputs: [build_input(0), build_input(1)],
        outputs: outputs,
        outputs_data: outputs_data,
        witnesses: witnesses,
      )
    end

    def build_input(index)
      CKB::Types::Input.new(
        previous_output: CKB::Types::OutPoint.new(tx_hash: "0x#{SecureRandom.hex(32)}", index: index),
        since: "0x0",
      )
    end

    def build_cell_dep
      CKB::Types::CellDep.new(
        out_point: CKB::Types::OutPoint.new(tx_hash: "0x#{SecureRandom.hex(32)}", index: 0),
        dep_type: "code",
      )
    end

    def build_output(type: nil, args_bytes: 20)
      CKB::Types::Output.new(
        capacity: "0x174876e800",
        lock: build_script(args_bytes),
        type: type,
      )
    end

    def build_script(args_bytes)
      CKB::Types::Script.new(
        code_hash: "0x#{SecureRandom.hex(32)}",
        hash_type: "type",
        args: "0x#{SecureRandom.hex(args_bytes)}",
      )
    end
  end
end
