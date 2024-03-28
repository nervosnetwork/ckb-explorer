module Bitcoin
  class SegwitAddr
    HRP_MAINNET = "bc"
    HRP_TESTNET = "tb"
    HRP_REGTEST = "bcrt"

    attr_accessor :hrp, :ver, :prog # human-readable part # witness version # witness program

    def initialize(addr = nil)
      @hrp = HRP_MAINNET
      parse_addr(addr) if addr
    end

    # Returns segwit script pubkey which generated from witness version and witness program.
    def to_script_pubkey
      v = ver == 0 ? ver : ver + 0x50
      ([v, prog.length] + prog).pack("C*").unpack1("H*")
    end

    # parse script pubkey into witness version and witness program
    def script_pubkey=(script_pubkey)
      values = [script_pubkey].pack("H*").unpack("C*")
      @ver = values[0] == 0 ? values[0] : values[0] - 0x50
      @prog = values[2..-1]
    end

    # Returns segwit address string which generated from hrp, witness version and witness program.
    def addr
      spec = (ver == 0 ? Bech32::Encoding::BECH32 : Bech32::Encoding::BECH32M)
      Bech32.encode(hrp, [ver] + convert_bits(prog, 8, 5), spec)
    end

    # TODO: There is a naming conflict between the "bech32" module in the "gem bech32" and the "bech32" module in "ckb-sdk-ruby".
    def convert_bits(data, from, to, padding = true)
      acc = 0
      bits = 0
      ret = []
      maxv = (1 << to) - 1
      max_acc = (1 << (from + to - 1)) - 1
      data.each do |v|
        return nil if v < 0 || (v >> from) != 0

        acc = ((acc << from) | v) & max_acc
        bits += from
        while bits >= to
          bits -= to
          ret << ((acc >> bits) & maxv)
        end
      end
      if padding
        ret << ((acc << (to - bits)) & maxv) unless bits == 0
      elsif bits >= from || ((acc << (to - bits)) & maxv) != 0
        return nil
      end
      ret
    end

    private

    def parse_addr(addr)
      @hrp, data, spec = Bech32.decode(addr)
      raise "Invalid address." if hrp.nil? || data[0].nil? || ![HRP_MAINNET, HRP_TESTNET, HRP_REGTEST].include?(hrp)

      @ver = data[0]
      raise "Invalid witness version" if @ver > 16

      @prog = convert_bits(data[1..-1], 5, 8, false)
      raise "Invalid witness program" if @prog.nil? || @prog.length < 2 || @prog.length > 40
      raise "Invalid witness program with version 0" if @ver == 0 && (@prog.length != 20 && @prog.length != 32)
      raise "Witness version and encoding spec do not match" if (@ver == 0 && spec != Bech32::Encoding::BECH32) || (@ver != 0 && spec != Bech32::Encoding::BECH32M)
    end
  end
end
