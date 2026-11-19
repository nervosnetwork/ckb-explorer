# frozen_string_literal: true

module CkbSync
  # Computes the molecule size of a transaction in a block without actually
  # serializing it to hex first.
  #
  # CKB::Types::Transaction#serialized_size_in_block builds every field as a
  # hex string, converts the whole transaction back to bytes (pack/unpack) and
  # joins the pieces together. For a ~1,100 transaction block that costs ~3.6s
  # of pure Ruby. The molecule layout is arithmetic, so the same number can be
  # computed from the field byte lengths directly (~4ms per block, verified
  # byte-for-byte against the SDK on real blocks of 1,100+ transactions).
  module TransactionSizeCalculator
    # 4-byte offset cost of a transaction inside the block's molecule array.
    BLOCK_TRANSACTION_OFFSET = 4

    # Table headers are a 4-byte full-length field plus one 4-byte offset per
    # field. Structs have no header.
    RAW_TRANSACTION_HEADER = 4 + (6 * 4)     # 6 fields
    TRANSACTION_HEADER = 4 + (2 * 4)         # raw transaction + witnesses
    WITNESS_ARGS_HEADER = 4 + (3 * 4)        # lock + input_type + output_type

    SCRIPT_FIXED_SIZE = (4 * 4) + 32 + 1 + 4 # header + code_hash + hash_type + args length
    OUTPUT_FIXED_SIZE = (4 * 4) + 8          # header + capacity
    INPUT_SIZE = 8 + 32 + 4                # since + OutPoint
    CELL_DEP_SIZE = 32 + 4 + 1             # OutPoint + dep_type
    HEADER_DEP_SIZE = 32

    module_function

    # Equivalent to transaction.serialized_size_in_block, in bytes.
    def serialized_size_in_block(transaction)
      raw_transaction_size(transaction) +
        witnesses_size(transaction.witnesses) +
        TRANSACTION_HEADER +
        BLOCK_TRANSACTION_OFFSET
    end

    def raw_transaction_size(transaction)
      RAW_TRANSACTION_HEADER +
        4 + # version
        vector_size(transaction.cell_deps, CELL_DEP_SIZE) +
        vector_size(transaction.header_deps, HEADER_DEP_SIZE) +
        vector_size(transaction.inputs, INPUT_SIZE) +
        dyn_vector_size(transaction.outputs) { |output| output_size(output) } +
        dyn_vector_size(transaction.outputs_data) { |data| 4 + hex_bytesize(data) }
    end

    def witnesses_size(witnesses)
      dyn_vector_size(witnesses) { |witness| witness_size(witness) }
    end

    # Molecule `vector` (fixed-size items): count + items.
    def vector_size(items, item_size)
      4 + (items.size * item_size)
    end

    # Molecule `dynvec` (variable-size items): total size + one offset per item + items.
    def dyn_vector_size(items, &)
      (4 * (items.size + 1)) + items.sum(&)
    end

    def output_size(output)
      OUTPUT_FIXED_SIZE +
        script_size(output.lock) +
        (output.type ? script_size(output.type) : 0)
    end

    def script_size(script)
      SCRIPT_FIXED_SIZE + hex_bytesize(script.args)
    end

    def witness_size(witness)
      payload_size =
        witness.is_a?(CKB::Types::Witness) ? witness_args_size(witness) : hex_bytesize(witness)

      4 + payload_size # Bytes: 4-byte length + data
    end

    # WitnessArgs is a 3-field table of optional byte arrays. An empty option
    # is encoded as zero bytes, a present one as a 4-byte length plus data.
    def witness_args_size(witness)
      WITNESS_ARGS_HEADER +
        bytes_opt_size(witness.lock) +
        bytes_opt_size(witness.input_type) +
        bytes_opt_size(witness.output_type)
    end

    def bytes_opt_size(value)
      size = hex_bytesize(value)
      size.zero? ? 0 : 4 + size
    end

    def hex_bytesize(value)
      return 0 if value.nil?

      value = value[2..] if value.start_with?("0x")
      value.size / 2
    end
  end
end
