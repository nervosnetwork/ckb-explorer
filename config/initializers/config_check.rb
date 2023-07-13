require "http"

Config.setup do |config|
  # Name of the constant exposing loaded settings
  config.const_name = "Settings"

  # Ability to remove elements of the array set in earlier loaded settings file. For example value: '--'.
  #
  # config.knockout_prefix = nil

  # Overwrite an existing value when merging a `nil` value.
  # When set to `false`, the existing value is retained after merge.
  #
  # config.merge_nil_values = true

  # Overwrite arrays found in previously loaded settings file. When set to `false`, arrays will be merged.
  #
  # config.overwrite_arrays = true

  # Load environment variables from the `ENV` object and override any settings defined in files.
  #
  # config.use_env = false

  # Define ENV variable prefix deciding which variables to load into config.
  #
  # config.env_prefix = 'Settings'

  # What string to use as level separator for settings loaded from ENV variables. Default value of '.' works well
  # with Heroku, but you might want to change it for example for '__' to easy override settings from command line, where
  # using dots in variable names might not be allowed (eg. Bash).
  #
  # config.env_separator = '.'

  # Ability to process variables names:
  #   * nil  - no change
  #   * :downcase - convert to lower case
  #
  # config.env_converter = :downcase

  # Parse numeric values as integers instead of strings.
  #
  # config.env_parse_values = true

  # Validate presence and type of specific config values. Check https://github.com/dry-rb/dry-validation for details.
  #
  # config.schema do
  #   required(:name).filled
  #   required(:age).maybe(:int?)
  #   required(:email).filled(format?: EMAIL_REGEX)
  # end
end

config_yml_file = "./config/settings.#{ENV['CKB_NET_MODE']}.yml"
Config.load_and_set_settings config_yml_file

def check_environments
  # rule 1: CKB_NET_MODE and CKB_NODE_URL must exist
  if ENV["CKB_NET_MODE"].blank? || ENV["CKB_NODE_URL"].blank?
    raise "environment: CKB_NET_MODE or CKB_NET_MODE not found, please check '.env' and restart."
  end

  # rule 2: CKB_NET_MODE and CKB_NODE_URL must match
  response = HTTP.
    headers("content-type": "application/json").
    post(ENV["CKB_NODE_URL"], json: { "id": 1, "jsonrpc": "2.0", "method": "get_blockchain_info", "params": [] })

  node_mode_from_json_rpc = JSON.parse(response)["result"]["chain"] rescue nil

  is_net_mode_match_json_rpc_result = ENV["CKB_NET_MODE"] == "mainnet" && node_mode_from_json_rpc == "ckb" || ENV["CKB_NET_MODE"] == "testnet" && node_mode_from_json_rpc == "ckb_testnet"

  unless is_net_mode_match_json_rpc_result
    raise "environment: CKB_NET_MODE(#{ENV['CKB_NET_MODE']}) does not match json rpc result (#{node_mode_from_json_rpc}), please check and restart."
  end
end
