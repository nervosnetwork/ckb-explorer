# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_10_15_105234) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "account_books", force: :cascade do |t|
    t.bigint "address_id"
    t.bigint "ckb_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address_id"], name: "index_account_books_on_address_id"
    t.index ["ckb_transaction_id"], name: "index_account_books_on_ckb_transaction_id"
  end

  create_table "addresses", force: :cascade do |t|
    t.decimal "balance", precision: 30, default: "0"
    t.binary "address_hash"
    t.decimal "cell_consumed", precision: 30
    t.decimal "ckb_transactions_count", precision: 30, default: "0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.binary "lock_hash"
    t.decimal "dao_deposit", precision: 30, default: "0"
    t.decimal "interest", precision: 30, default: "0"
    t.decimal "block_timestamp", precision: 30
    t.boolean "visible", default: true
    t.decimal "live_cells_count", precision: 30, default: "0"
    t.integer "mined_blocks_count", default: 0
    t.decimal "average_deposit_time"
    t.decimal "unclaimed_compensation", precision: 30
    t.boolean "is_depositor", default: false
    t.decimal "dao_transactions_count", precision: 30, default: "0"
    t.bigint "lock_script_id"
    t.index ["address_hash"], name: "index_addresses_on_address_hash"
    t.index ["is_depositor"], name: "index_addresses_on_is_depositor", where: "(is_depositor = true)"
    t.index ["lock_hash"], name: "index_addresses_on_lock_hash", unique: true
  end

  create_table "block_propagation_delays", force: :cascade do |t|
    t.string "block_hash"
    t.integer "created_at_unixtimestamp"
    t.jsonb "durations"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at_unixtimestamp"], name: "index_block_propagation_delays_on_created_at_unixtimestamp"
  end

  create_table "block_statistics", force: :cascade do |t|
    t.string "difficulty"
    t.string "hash_rate"
    t.string "live_cells_count", default: "0"
    t.string "dead_cells_count", default: "0"
    t.decimal "block_number", precision: 30
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.decimal "epoch_number", precision: 30
    t.index ["block_number"], name: "index_block_statistics_on_block_number", unique: true
  end

  create_table "block_time_statistics", force: :cascade do |t|
    t.decimal "stat_timestamp", precision: 30
    t.decimal "avg_block_time_per_hour"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["stat_timestamp"], name: "index_block_time_statistics_on_stat_timestamp", unique: true
  end

  create_table "blocks", force: :cascade do |t|
    t.binary "block_hash"
    t.decimal "number", precision: 30
    t.binary "parent_hash"
    t.decimal "timestamp", precision: 30
    t.binary "transactions_root"
    t.binary "proposals_hash"
    t.binary "extra_hash"
    t.binary "uncle_block_hashes"
    t.integer "version"
    t.binary "proposals"
    t.integer "proposals_count"
    t.decimal "cell_consumed", precision: 30
    t.binary "miner_hash"
    t.string "miner_message"
    t.decimal "reward", precision: 30
    t.decimal "total_transaction_fee", precision: 30
    t.decimal "ckb_transactions_count", precision: 30, default: "0"
    t.decimal "total_cell_capacity", precision: 30
    t.decimal "epoch", precision: 30
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address_ids", array: true
    t.integer "reward_status", default: 0
    t.integer "received_tx_fee_status", default: 0
    t.decimal "received_tx_fee", precision: 30, default: "0"
    t.integer "target_block_reward_status", default: 0
    t.binary "miner_lock_hash"
    t.string "dao"
    t.decimal "primary_reward", precision: 30, default: "0"
    t.decimal "secondary_reward", precision: 30, default: "0"
    t.decimal "nonce", precision: 50, default: "0"
    t.decimal "start_number", precision: 30, default: "0"
    t.decimal "length", precision: 30, default: "0"
    t.integer "uncles_count"
    t.decimal "compact_target", precision: 20
    t.integer "live_cell_changes"
    t.decimal "block_time", precision: 13
    t.integer "block_size"
    t.decimal "proposal_reward", precision: 30
    t.decimal "commit_reward", precision: 30
    t.jsonb "extension"
    t.index ["block_hash"], name: "index_blocks_on_block_hash", unique: true
    t.index ["block_size"], name: "index_blocks_on_block_size"
    t.index ["block_time"], name: "index_blocks_on_block_time"
    t.index ["epoch"], name: "index_blocks_on_epoch"
    t.index ["number"], name: "index_blocks_on_number"
    t.index ["timestamp"], name: "index_blocks_on_timestamp", order: "DESC NULLS LAST"
  end

  create_table "cell_inputs", force: :cascade do |t|
    t.jsonb "previous_output"
    t.bigint "ckb_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "previous_cell_output_id"
    t.boolean "from_cell_base", default: false
    t.decimal "block_id", precision: 30
    t.decimal "since", precision: 30, default: "0"
    t.integer "cell_type", default: 0
    t.index ["block_id"], name: "index_cell_inputs_on_block_id"
    t.index ["ckb_transaction_id"], name: "index_cell_inputs_on_ckb_transaction_id"
    t.index ["previous_cell_output_id"], name: "index_cell_inputs_on_previous_cell_output_id"
  end

  create_table "cell_outputs", force: :cascade do |t|
    t.decimal "capacity", precision: 64, scale: 2
    t.binary "data"
    t.bigint "ckb_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", limit: 2, default: 0
    t.decimal "address_id", precision: 30
    t.decimal "block_id", precision: 30
    t.binary "tx_hash"
    t.integer "cell_index"
    t.decimal "generated_by_id", precision: 30
    t.decimal "consumed_by_id", precision: 30
    t.integer "cell_type", default: 0
    t.integer "data_size"
    t.decimal "occupied_capacity", precision: 30
    t.decimal "block_timestamp", precision: 30
    t.decimal "consumed_block_timestamp", precision: 30
    t.string "type_hash"
    t.decimal "udt_amount", precision: 40
    t.string "dao"
    t.bigint "lock_script_id"
    t.bigint "type_script_id"
    t.index ["address_id", "status"], name: "index_cell_outputs_on_address_id_and_status"
    t.index ["block_id"], name: "index_cell_outputs_on_block_id"
    t.index ["block_timestamp"], name: "index_cell_outputs_on_block_timestamp"
    t.index ["ckb_transaction_id"], name: "index_cell_outputs_on_ckb_transaction_id"
    t.index ["consumed_block_timestamp"], name: "index_cell_outputs_on_consumed_block_timestamp"
    t.index ["consumed_by_id"], name: "index_cell_outputs_on_consumed_by_id"
    t.index ["generated_by_id"], name: "index_cell_outputs_on_generated_by_id"
    t.index ["lock_script_id"], name: "index_cell_outputs_on_lock_script_id"
    t.index ["status"], name: "index_cell_outputs_on_status"
    t.index ["tx_hash", "cell_index"], name: "index_cell_outputs_on_tx_hash_and_cell_index"
    t.index ["type_script_id"], name: "index_cell_outputs_on_type_script_id"
  end

  create_table "ckb_transactions", force: :cascade do |t|
    t.binary "tx_hash"
    t.bigint "block_id"
    t.decimal "block_number", precision: 30
    t.decimal "block_timestamp", precision: 30
    t.decimal "transaction_fee", precision: 30
    t.integer "version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_cellbase", default: false
    t.jsonb "witnesses"
    t.binary "header_deps"
    t.jsonb "cell_deps"
    t.integer "live_cell_changes"
    t.decimal "capacity_involved", precision: 30
    t.bigint "contained_address_ids", default: [], array: true
    t.string "tags", default: [], array: true
    t.bigint "contained_udt_ids", default: [], array: true
    t.bigint "dao_address_ids", default: [], array: true
    t.bigint "udt_address_ids", default: [], array: true
    t.index ["block_id", "block_timestamp"], name: "index_ckb_transactions_on_block_id_and_block_timestamp"
    t.index ["block_timestamp", "id"], name: "index_ckb_transactions_on_block_timestamp_and_id", order: { block_timestamp: "DESC NULLS LAST", id: :desc }
    t.index ["contained_address_ids"], name: "index_ckb_transactions_on_contained_address_ids", using: :gin
    t.index ["contained_udt_ids"], name: "index_ckb_transactions_on_contained_udt_ids", using: :gin
    t.index ["dao_address_ids"], name: "index_ckb_transactions_on_dao_address_ids", using: :gin
    t.index ["is_cellbase"], name: "index_ckb_transactions_on_is_cellbase"
    t.index ["tags"], name: "index_ckb_transactions_on_tags", using: :gin
    t.index ["tx_hash", "block_id"], name: "index_ckb_transactions_on_tx_hash_and_block_id", unique: true
    t.index ["udt_address_ids"], name: "index_ckb_transactions_on_udt_address_ids", using: :gin
  end

  create_table "daily_statistics", force: :cascade do |t|
    t.string "transactions_count", default: "0"
    t.string "addresses_count", default: "0"
    t.string "total_dao_deposit", default: "0.0"
    t.decimal "block_timestamp", precision: 30
    t.integer "created_at_unixtimestamp"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "dao_depositors_count", default: "0"
    t.string "unclaimed_compensation", default: "0"
    t.string "claimed_compensation", default: "0"
    t.string "average_deposit_time", default: "0"
    t.string "estimated_apc", default: "0"
    t.string "mining_reward", default: "0"
    t.string "deposit_compensation", default: "0"
    t.string "treasury_amount", default: "0"
    t.string "live_cells_count", default: "0"
    t.string "dead_cells_count", default: "0"
    t.string "avg_hash_rate", default: "0"
    t.string "avg_difficulty", default: "0"
    t.string "uncle_rate", default: "0"
    t.string "total_depositors_count", default: "0"
    t.jsonb "address_balance_distribution"
    t.decimal "total_tx_fee", precision: 30
    t.decimal "occupied_capacity", precision: 30
    t.decimal "daily_dao_deposit", precision: 30
    t.integer "daily_dao_depositors_count"
    t.decimal "daily_dao_withdraw", precision: 30
    t.decimal "circulation_ratio"
    t.decimal "total_supply", precision: 30
    t.decimal "circulating_supply"
    t.jsonb "block_time_distribution"
    t.jsonb "epoch_time_distribution"
    t.jsonb "epoch_length_distribution"
    t.jsonb "average_block_time"
    t.jsonb "nodes_distribution"
    t.integer "nodes_count"
    t.decimal "locked_capacity", precision: 30
    t.index ["created_at_unixtimestamp"], name: "index_daily_statistics_on_created_at_unixtimestamp", order: "DESC NULLS LAST"
  end

  create_table "dao_contracts", force: :cascade do |t|
    t.decimal "total_deposit", precision: 30, default: "0"
    t.decimal "claimed_compensation", precision: 30, default: "0"
    t.bigint "deposit_transactions_count", default: 0
    t.bigint "withdraw_transactions_count", default: 0
    t.integer "depositors_count", default: 0
    t.bigint "total_depositors_count", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.decimal "unclaimed_compensation", precision: 30
    t.decimal "ckb_transactions_count", precision: 30, default: "0"
  end

  create_table "dao_events", force: :cascade do |t|
    t.bigint "block_id"
    t.bigint "ckb_transaction_id"
    t.bigint "address_id"
    t.bigint "contract_id"
    t.integer "event_type", limit: 2
    t.decimal "value", precision: 30, default: "0"
    t.integer "status", limit: 2, default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.decimal "block_timestamp", precision: 30
    t.index ["block_id"], name: "index_dao_events_on_block_id"
    t.index ["block_timestamp"], name: "index_dao_events_on_block_timestamp"
    t.index ["status", "event_type"], name: "index_dao_events_on_status_and_event_type"
  end

  create_table "epoch_statistics", force: :cascade do |t|
    t.string "difficulty"
    t.string "uncle_rate"
    t.decimal "epoch_number", precision: 30
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "hash_rate"
    t.decimal "epoch_time", precision: 13
    t.integer "epoch_length"
    t.index ["epoch_number"], name: "index_epoch_statistics_on_epoch_number", unique: true
  end

  create_table "forked_blocks", force: :cascade do |t|
    t.binary "block_hash"
    t.decimal "number", precision: 30
    t.binary "parent_hash"
    t.decimal "timestamp", precision: 30
    t.binary "transactions_root"
    t.binary "proposals_hash"
    t.binary "extra_hash"
    t.binary "uncle_block_hashes"
    t.integer "version"
    t.binary "proposals"
    t.integer "proposals_count"
    t.decimal "cell_consumed", precision: 30
    t.binary "miner_hash"
    t.decimal "reward", precision: 30
    t.decimal "total_transaction_fee", precision: 30
    t.decimal "ckb_transactions_count", precision: 30, default: "0"
    t.decimal "total_cell_capacity", precision: 30
    t.decimal "epoch", precision: 30
    t.string "address_ids", array: true
    t.integer "reward_status", default: 0
    t.integer "received_tx_fee_status", default: 0
    t.decimal "received_tx_fee", precision: 30, default: "0"
    t.integer "target_block_reward_status", default: 0
    t.binary "miner_lock_hash"
    t.string "dao"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "primary_reward", precision: 30, default: "0"
    t.decimal "secondary_reward", precision: 30, default: "0"
    t.decimal "nonce", precision: 50, default: "0"
    t.decimal "start_number", precision: 30, default: "0"
    t.decimal "length", precision: 30, default: "0"
    t.integer "uncles_count"
    t.decimal "compact_target", precision: 20
    t.integer "live_cell_changes"
    t.decimal "block_time", precision: 13
    t.integer "block_size"
    t.decimal "proposal_reward", precision: 30
    t.decimal "commit_reward", precision: 30
    t.string "miner_message"
    t.jsonb "extension"
  end

  create_table "forked_events", force: :cascade do |t|
    t.decimal "block_number", precision: 30
    t.decimal "epoch_number", precision: 30
    t.decimal "block_timestamp", precision: 30
    t.integer "status", limit: 2, default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["status"], name: "index_forked_events_on_status"
  end

  create_table "lock_scripts", force: :cascade do |t|
    t.string "args"
    t.binary "code_hash"
    t.bigint "cell_output_id"
    t.bigint "address_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hash_type"
    t.string "script_hash"
    t.index ["address_id"], name: "index_lock_scripts_on_address_id"
    t.index ["cell_output_id"], name: "index_lock_scripts_on_cell_output_id"
    t.index ["code_hash", "hash_type", "args"], name: "index_lock_scripts_on_code_hash_and_hash_type_and_args"
    t.index ["script_hash"], name: "index_lock_scripts_on_script_hash"
  end

  create_table "mining_infos", force: :cascade do |t|
    t.bigint "address_id"
    t.bigint "block_id"
    t.decimal "block_number", precision: 30
    t.integer "status", limit: 2, default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["block_id"], name: "index_mining_infos_on_block_id"
    t.index ["block_number"], name: "index_mining_infos_on_block_number"
  end

  create_table "pool_transaction_entries", force: :cascade do |t|
    t.jsonb "cell_deps"
    t.binary "tx_hash"
    t.jsonb "header_deps"
    t.jsonb "inputs"
    t.jsonb "outputs"
    t.jsonb "outputs_data"
    t.integer "version"
    t.jsonb "witnesses"
    t.decimal "transaction_fee", precision: 30
    t.decimal "block_number", precision: 30
    t.decimal "block_timestamp", precision: 30
    t.decimal "cycles", precision: 30
    t.decimal "tx_size", precision: 30
    t.jsonb "display_inputs"
    t.jsonb "display_outputs"
    t.integer "tx_status", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["tx_hash"], name: "index_pool_transaction_entries_on_tx_hash", unique: true
    t.index ["tx_status"], name: "index_pool_transaction_entries_on_tx_status"
  end

  create_table "table_record_counts", force: :cascade do |t|
    t.string "table_name"
    t.bigint "count"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["table_name", "count"], name: "index_table_record_counts_on_table_name_and_count"
  end

  create_table "transaction_propagation_delays", force: :cascade do |t|
    t.string "tx_hash"
    t.integer "created_at_unixtimestamp"
    t.jsonb "durations"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at_unixtimestamp"], name: "index_tx_propagation_timestamp"
  end

  create_table "tx_display_infos", primary_key: "ckb_transaction_id", id: :bigint, default: nil, force: :cascade do |t|
    t.jsonb "inputs"
    t.jsonb "outputs"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.jsonb "income"
  end

  create_table "type_scripts", force: :cascade do |t|
    t.string "args"
    t.binary "code_hash"
    t.bigint "cell_output_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hash_type"
    t.string "script_hash"
    t.index ["cell_output_id"], name: "index_type_scripts_on_cell_output_id"
    t.index ["code_hash", "hash_type", "args"], name: "index_type_scripts_on_code_hash_and_hash_type_and_args"
    t.index ["script_hash"], name: "index_type_scripts_on_script_hash"
  end

  create_table "udt_accounts", force: :cascade do |t|
    t.integer "udt_type"
    t.string "full_name"
    t.string "symbol"
    t.integer "decimal"
    t.decimal "amount", precision: 40, default: "0"
    t.boolean "published", default: false
    t.binary "code_hash"
    t.string "type_hash"
    t.bigint "address_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "udt_id"
    t.index ["address_id"], name: "index_udt_accounts_on_address_id"
    t.index ["type_hash", "address_id"], name: "index_udt_accounts_on_type_hash_and_address_id", unique: true
    t.index ["udt_id"], name: "index_udt_accounts_on_udt_id"
  end

  create_table "udts", force: :cascade do |t|
    t.binary "code_hash"
    t.string "hash_type"
    t.string "args"
    t.string "type_hash"
    t.string "full_name"
    t.string "symbol"
    t.integer "decimal"
    t.string "description"
    t.string "icon_file"
    t.string "operator_website"
    t.decimal "addresses_count", precision: 30, default: "0"
    t.decimal "total_amount", precision: 40, default: "0"
    t.integer "udt_type"
    t.boolean "published", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.decimal "block_timestamp", precision: 30
    t.binary "issuer_address"
    t.decimal "ckb_transactions_count", precision: 30, default: "0"
    t.index ["type_hash"], name: "index_udts_on_type_hash", unique: true
  end

  create_table "uncle_blocks", force: :cascade do |t|
    t.binary "block_hash"
    t.decimal "number", precision: 30
    t.binary "parent_hash"
    t.decimal "timestamp", precision: 30
    t.binary "transactions_root"
    t.binary "proposals_hash"
    t.binary "extra_hash"
    t.integer "version"
    t.binary "proposals"
    t.integer "proposals_count"
    t.bigint "block_id"
    t.decimal "epoch", precision: 30
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "dao"
    t.decimal "nonce", precision: 50, default: "0"
    t.decimal "compact_target", precision: 20
    t.index ["block_hash", "block_id"], name: "index_uncle_blocks_on_block_hash_and_block_id", unique: true
    t.index ["block_id"], name: "index_uncle_blocks_on_block_id"
  end

end
