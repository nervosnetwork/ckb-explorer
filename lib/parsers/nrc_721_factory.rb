class Parsers::Nrc721Factory
  def perform(cell)
    factory_data = CellOutput.where(
      type_script_id: nrc_721_factory_cell_type.id, 
      cell_type: "nrc_721_factory").last.data
    cell.update parsed_data: CkbUtils.parse_nrc_721_factory_data(factory_data)
  end

  def self.parse_data(data)
    data = data.delete_prefix(Settings.nrc_721_factory_output_data_header)
    arg_name_length = 4
    name_byte_size = data[0, arg_name_length].to_i(16)
    factory_name_hex = data[arg_name_length, name_byte_size * 2]

    arg_symbol_length = 4
    symbol_byte_size = data[(factory_name_hex.length + arg_name_length), arg_symbol_length].to_i(16)
    factory_symbol_hex = data[arg_name_length + factory_name_hex.length + arg_symbol_length, symbol_byte_size * 2]

    arg_base_token_uri_length = 4
    base_token_uri_length = data[(arg_name_length + factory_name_hex.length + arg_symbol_length + factory_symbol_hex.length), arg_base_token_uri_length].to_i(16)
    factory_base_token_uri_hex = data[(arg_name_length + factory_name_hex.length + arg_symbol_length + factory_symbol_hex.length + arg_base_token_uri_length), base_token_uri_length *2]
    extra_data_hex = data[(arg_name_length + factory_name_hex.length + arg_symbol_length + factory_symbol_hex.length + arg_base_token_uri_length + base_token_uri_length *2)..-1]
    {
      name: [factory_name_hex].pack("H*"), 
      symbol: [factory_symbol_hex].pack("H*"), 
      base_token_uri: [factory_base_token_uri_hex].pack("H*"), 
      extra_data: extra_data_hex
    }
  end
end
