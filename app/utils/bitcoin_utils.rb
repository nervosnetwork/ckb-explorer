module BitcoinUtils
  def self.valid_address?(addr)
    parse_from_addr(addr)
    true
  rescue Exception
    false
  end

  def self.parse_from_addr(addr)
    segwit_addr = Bitcoin::SegwitAddr.new(addr)
    raise ArgumentError, "Invalid address." unless Bitcoin.chain_params.bech32_hrp == segwit_addr.hrp

    Bitcoin::Script.parse_from_payload(segwit_addr.to_script_pubkey.htb)
  rescue Exception => e
    begin
      hex, addr_version = Bitcoin.decode_base58_address(addr)
    rescue StandardError
      raise ArgumentError, "Invalid address."
    end

    case addr_version
    when Bitcoin.chain_params.address_version
      Bitcoin::Script.to_p2pkh(hex)
    when Bitcoin.chain_params.p2sh_version
      Bitcoin::Script.to_p2sh(hex)
    else
      raise ArgumentError, "Invalid address."
    end
  end
end
