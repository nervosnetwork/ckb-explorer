class UpdateCellOutputsStatus
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake migration:update_output_cells_status"
      task update_output_cells_status: :environment do
        CellOutput.includes(:ckb_transaction).pending.where(ckb_transaction: { tx_status: "committed" }).find_each do |output|
          puts "output id: #{output.id}"

          output.live!
          update_udt_account(output)
          update_address_live_cells_count(output.address_id)
        end

        puts "done"
      end
    end
  end

  private

  def update_address_live_cells_count(address_id)
    address = Address.find_by_id address_id
    return unless address

    address.cal_balance!
    address.save!
    address.flush_cache
  end

  def update_udt_account(udt_output)
    return unless udt_output.cell_type.in?(%w(udt m_nft_token nrc_721_token))

    address = Address.find(udt_output.address_id)
    udt_type = udt_type(udt_output.cell_type)
    udt_account = address.udt_accounts.where(type_hash: udt_output.type_hash, udt_type: udt_type).first
    amount = udt_account_amount(udt_type, udt_output.type_hash, address)

    if udt_account.present?
      udt_account.update(amount: amount)
    else
      puts "udt_account not found: #{udt_output.id}"

      udt = Udt.where(type_hash: udt_output.type_hash, udt_type: udt_type).take!
      nft_token_id =
        udt_type == "nrc_721_token" ? CkbUtils.parse_nrc_721_args(udt_output.type_script.args).token_id : nil
      new_udt_accounts_attribute = {
        address_id: udt_output.address_id, udt_type: udt.udt_type, full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal,
        published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: amount, udt_id: udt.id, nft_token_id: nft_token_id,
        created_at: Time.current, updated_at: Time.current
      }

      UdtAccount.insert!(new_udt_accounts_attribute)
    end
  end

  def udt_type(cell_type)
    cell_type == "udt" ? "sudt" : cell_type
  end

  def udt_account_amount(udt_type, type_hash, address)
    case udt_type
    when "sudt"
      address.cell_outputs.live.udt.where(type_hash: type_hash).sum(:udt_amount)
    when "m_nft_token"
      address.cell_outputs.live.m_nft_token.where(type_hash: type_hash).sum(:udt_amount)
    else
      0
    end
  end
end

UpdateCellOutputsStatus.new
