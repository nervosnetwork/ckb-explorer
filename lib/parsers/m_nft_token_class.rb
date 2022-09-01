class Parsers::MnftTokenClass
  def self.parse_data(data)
    data = data.delete_prefix("0x")
    version = data[0..1].to_i(16)
    total = data[2..9].to_i(16)
    issued = data[10..17].to_i(16)
    configure = data[18..19].to_i(16)
    name_size = data[20..23].to_i(16)
    name_end_index = (24 + name_size * 2 - 1)
    name = [data[24..name_end_index]].pack("H*").force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace).delete("\u0000")
    description_size_start_index = name_end_index + 1
    description_size_end_index = description_size_start_index + 4 - 1
    description_size = data[description_size_start_index..description_size_end_index].to_i(16)
    description_start_index = description_size_end_index + 1
    description_end_index = description_start_index + description_size * 2 - 1
    description = [data[description_start_index..description_end_index]].pack("H*").force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace).delete("\u0000")
    renderer_size_start_index = description_end_index + 1
    renderer_size_end_index = renderer_size_start_index + 4 - 1
    renderer_size = data[renderer_size_start_index..renderer_size_end_index].to_i(16)
    renderer_start_index = renderer_size_end_index + 1
    renderer_end_index = renderer_start_index + renderer_size * 2 - 1
    renderer = [data[renderer_start_index, renderer_end_index]].pack("H*").force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace).delete("\u0000")
    OpenStruct.new(version: version, total: total, issued: issued, configure: configure, name: name, description: description, renderer: renderer)
  end
end
