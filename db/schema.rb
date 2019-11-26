# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_11_26_225038) do

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
    t.decimal "balance", precision: 30
    t.binary "address_hash"
    t.decimal "cell_consumed", precision: 30
    t.decimal "ckb_transactions_count", precision: 30, default: "0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.binary "lock_hash"
    t.integer "pending_reward_blocks_count", default: 0
    t.decimal "dao_deposit", precision: 30, default: "0"
    t.decimal "interest", precision: 30, default: "0"
    t.decimal "block_timestamp", precision: 30
    t.index ["address_hash"], name: "index_addresses_on_address_hash"
    t.index ["lock_hash"], name: "index_addresses_on_lock_hash", unique: true
  end

  create_table "blocks", force: :cascade do |t|
    t.binary "block_hash"
    t.decimal "number", precision: 30
    t.binary "parent_hash"
    t.decimal "timestamp", precision: 30
    t.binary "transactions_root"
    t.binary "proposals_hash"
    t.binary "uncles_hash"
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
    t.index ["block_hash"], name: "index_blocks_on_block_hash", unique: true
    t.index ["number"], name: "index_blocks_on_number"
    t.index ["timestamp"], name: "index_blocks_on_timestamp"
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
    t.index ["address_id", "status"], name: "index_cell_outputs_on_address_id_and_status"
    t.index ["block_id"], name: "index_cell_outputs_on_block_id"
    t.index ["ckb_transaction_id"], name: "index_cell_outputs_on_ckb_transaction_id"
    t.index ["consumed_by_id"], name: "index_cell_outputs_on_consumed_by_id"
    t.index ["generated_by_id"], name: "index_cell_outputs_on_generated_by_id"
    t.index ["tx_hash", "cell_index"], name: "index_cell_outputs_on_tx_hash_and_cell_index"
  end

  create_table "ckb_transactions", force: :cascade do |t|
    t.binary "tx_hash"
    t.jsonb "deps"
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
    t.index ["block_id", "block_timestamp"], name: "index_ckb_transactions_on_block_id_and_block_timestamp"
    t.index ["is_cellbase"], name: "index_ckb_transactions_on_is_cellbase"
    t.index ["tx_hash", "block_id"], name: "index_ckb_transactions_on_tx_hash_and_block_id", unique: true
  end

  create_table "dao_contracts", force: :cascade do |t|
    t.decimal "total_deposit", precision: 30, default: "0"
    t.decimal "interest_granted", precision: 30, default: "0"
    t.bigint "deposit_transactions_count", default: 0
    t.bigint "withdraw_transactions_count", default: 0
    t.integer "depositors_count", default: 0
    t.bigint "total_depositors_count", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
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
    t.index ["block_id"], name: "index_dao_events_on_block_id"
  end

  create_table "forked_blocks", force: :cascade do |t|
    t.binary "block_hash"
    t.decimal "number", precision: 30
    t.binary "parent_hash"
    t.decimal "timestamp", precision: 30
    t.binary "transactions_root"
    t.binary "proposals_hash"
    t.binary "uncles_hash"
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
  end

  create_table "lock_scripts", force: :cascade do |t|
    t.string "args"
    t.binary "code_hash"
    t.bigint "cell_output_id"
    t.bigint "address_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hash_type"
    t.index ["address_id"], name: "index_lock_scripts_on_address_id"
    t.index ["cell_output_id"], name: "index_lock_scripts_on_cell_output_id"
  end

  create_table "type_scripts", force: :cascade do |t|
    t.string "args"
    t.binary "code_hash"
    t.bigint "cell_output_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hash_type"
    t.index ["cell_output_id"], name: "index_type_scripts_on_cell_output_id"
  end

  create_table "uncle_blocks", force: :cascade do |t|
    t.binary "block_hash"
    t.decimal "number", precision: 30
    t.binary "parent_hash"
    t.decimal "timestamp", precision: 30
    t.binary "transactions_root"
    t.binary "proposals_hash"
    t.binary "uncles_hash"
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
