class MNftAccountDataGenerator
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake migration:generate_m_nft_account_data"
      task generate_m_nft_account_data: :environment do
        progress_bar = ProgressBar.create({ total: CellOutput.m_nft_token.live.count, format: "%e %B %p%% %c/%C" })
        CellOutput.m_nft_token.live.find_each do |cell_output|
          cell_output.update(udt_amount: "0x#{cell_output.type_script.args[-8..-1]}".hex)
          udt = Udt.find_or_create_by!(type_hash: cell_output.type_hash, udt_type: cell_output.cell_type)
          udt.update(published: true)
          udt_account = cell_output.address.udt_accounts.find_or_create_by!(udt_type: cell_output.cell_type, type_hash: udt.type_hash, udt: udt)
          udt_account.update!(code_hash: udt.code_hash, amount: cell_output.udt_amount, published: udt.published)
          progress_bar.increment
        end

        puts "done"
      end
    end
  end

  private

end

MNftAccountDataGenerator.new
