class Parsers::MnftIssuer
  def parse_data(data)
    data = data.delete_prefix("0x")
    version = data[0..1].to_i(16)
    class_count = data[2..9].to_i(16)
    set_count = data[10..17].to_i(16)
    info_size = data[18..21].to_i(16)
    info = JSON.parse([data[22..-1]].pack("H*").force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace).delete("\u0000"))
    OpenStruct.new(version: version, class_count: class_count, set_count: set_count, info_size: info_size, info: info)
  end    
end
