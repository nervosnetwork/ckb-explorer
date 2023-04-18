# Address parser (copied from CKB Ruby SDK)
class CkbAddressParser
  # @param address_hash [String]
  def initialize(address_hash)
    @address_hash = address_hash
  end

  # @return [OpenStruct(mode, script, address_type)]
  def parse
    decoded_prefix, data, = CKB::ConvertAddress.decode(address_hash)
    format_type = data[0].unpack1("H*")
    case format_type
    when CKB::Address::SHORT_FORMAT
      parse_short_payload_address(decoded_prefix, data)
    when CKB::Address::FULL_DATA_FORMAT, CKB::Address::FULL_TYPE_FORMAT
      parse_full_payload_address(decoded_prefix, data)
    when CKB::Address::FULL_WITH_IDENTIFIER_FORMAT
      parse_new_full_payload_address(decoded_prefix, data)
    else
      raise InvalidFormatTypeError, "Invalid format type"
    end
  end

  private

  attr_reader :address_hash

  def parse_address_type(format_type, code_hash_index = nil)
    return "FULL" if format_type != CKB::Address::SHORT_FORMAT

    case code_hash_index
    when CKB::Address::CODE_HASH_INDEX_SINGLESIG
      "SHORTSINGLESIG"
    when CKB::Address::CODE_HASH_INDEX_MULTISIG_SIG
      "SHORTMULTISIG"
    when CKB::Address::CODE_HASH_INDEX_ANYONE_CAN_PAY
      "SHORTANYONECANPAY"
    else
      raise InvalidCodeHashIndexError, "Invalid code hash index"
    end
  end

  def parse_short_payload_address(decoded_prefix, data)
    format_type = data[0].unpack1("H*")
    code_hash_index = data[1].unpack1("H*")
    mode = parse_mode(decoded_prefix)
    code_hash = parse_code_hash(code_hash_index, mode)
    args = CKB::Utils.bin_to_hex(data.slice(2..-1))

    OpenStruct.new(mode: mode,
                   script: CKB::Types::Script.new(code_hash: code_hash,
                                                  args: args,
                                                  hash_type: CKB::ScriptHashType::TYPE),
                   address_type: parse_address_type(format_type, code_hash_index))
  end

  def parse_full_payload_address(decoded_prefix, data)
    format_type = data[0].unpack1("H*")
    mode = parse_mode(decoded_prefix)
    hash_type = parse_hash_type(format_type)
    offset = 1
    code_hash_size = 32
    code_hash = "0x#{data.slice(1..code_hash_size).unpack1('H*')}"
    offset += code_hash_size
    args = CKB::Utils.bin_to_hex(data[offset..-1])

    OpenStruct.new(mode: mode,
                   script: CKB::Types::Script.new(code_hash: code_hash,
                                                  args: args,
                                                  hash_type: hash_type),
                   address_type: parse_address_type(format_type))
  end

  def parse_new_full_payload_address(decoded_prefix, data)
    format_type = data[0].unpack1("H*")
    mode = parse_mode(decoded_prefix)
    code_hash_size = 32
    code_hash = "0x#{data.slice(1..code_hash_size).unpack1('H*')}"
    hash_type = CKB::Utils.bin_to_hex(data[code_hash_size + 1...code_hash_size + 2]).hex
    args = CKB::Utils.bin_to_hex(data[code_hash_size + 2..])
    OpenStruct.new(mode: mode,
                   script: CKB::Types::Script.new(code_hash: code_hash,
                                                  args: args,
                                                  hash_type: CKB::ScriptHashType::TYPES[hash_type]),
                   address_type: parse_address_type(format_type))
  end

  def parse_hash_type(format_type)
    case format_type
    when CKB::Address::FULL_DATA_FORMAT
      CKB::ScriptHashType::DATA
    when CKB::Address::FULL_TYPE_FORMAT
      CKB::ScriptHashType::TYPE
    else
      raise InvalidFormatTypeError, "Invalid format type"
    end
  end

  def parse_code_hash(code_hash_index, mode)
    case code_hash_index
    when CKB::Address::CODE_HASH_INDEX_SINGLESIG
      CKB::SystemCodeHash::SECP256K1_BLAKE160_SIGHASH_ALL_TYPE_HASH
    when CKB::Address::CODE_HASH_INDEX_MULTISIG_SIG
      CKB::SystemCodeHash::SECP256K1_BLAKE160_MULTISIG_ALL_TYPE_HASH
    when CKB::Address::CODE_HASH_INDEX_ANYONE_CAN_PAY
      if mode == CKB::MODE::TESTNET
        CKB::SystemCodeHash::ANYONE_CAN_PAY_CODE_HASH_ON_AGGRON
      else
        CKB::SystemCodeHash::ANYONE_CAN_PAY_CODE_HASH_ON_LINA
      end
    else
      raise InvalidCodeHashIndexError, "Invalid code hash index"
    end
  end

  def parse_mode(decoded_prefix)
    case decoded_prefix
    when CKB::Address::PREFIX_TESTNET
      CKB::MODE::TESTNET
    when CKB::Address::PREFIX_MAINNET
      CKB::MODE::MAINNET
    else
      raise InvalidPrefixError, "Invalid prefix"
    end
  end

  class InvalidFormatTypeError < StandardError; end
  class InvalidArgSizeError < StandardError; end
  class InvalidPrefixError < StandardError; end
  class InvalidCodeHashIndexError < StandardError; end
  class InvalidCodeHashSizeError < StandardError; end
end
