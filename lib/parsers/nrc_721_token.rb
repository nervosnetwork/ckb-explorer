class Parsers::Nrc721Token
  def parse_args(args)
    args = args.delete_prefix("0x")
    factory_code_hash = "0x#{args[0..63]}"
    factory_type = args[64..65] == "01" ? "type" : "data"
    factory_args = "0x#{args[66..129]}"
    factory_token_id = args[130..-1]
    {
      token_id: factory_token_id
    }
  end
end
