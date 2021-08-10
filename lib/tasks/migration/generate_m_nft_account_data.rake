class MNftAccountDataGenerator
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake 'migration:generate_m_nft_account_data[ckb-testnet]'"
      task :generate_m_nft_account_data, [:chain] => :environment do |_, args|
        if args[:chain].blank?
          puts "missing chain type"
          next
        end

        chain = args[:chain]
        puts "chain: #{chain}"

        progress_bar = ProgressBar.create({ total: CellOutput.m_nft_token.live.count, format: "%e %B %p%% %c/%C" })
        CellOutput.m_nft_token.live.find_each do |cell_output|
          cell_output.update(udt_amount: "0x#{cell_output.type_script.args[-8..-1]}".hex)
          udt = Udt.find_or_create_by!(type_hash: cell_output.type_hash, udt_type: cell_output.cell_type)
          unless TypeScript.where(code_hash: CkbSync::Api.instance.token_class_script_code_hash, args: cell_output.type_script.args[0..49]).exists?
            ts = CKB::Types::Script.new(code_hash: CkbSync::Api.instance.token_class_script_code_hash, args: cell_output.type_script.args[0..49], hash_type: "type")
            CellOutput.where(type_hash: ts.compute_hash).each do |output|
              if chain == "ckb"
                output.create_type_script!(code_hash: CkbSync::Api.instance.token_class_script_code_hash, args: cell_output.type_script.args[0..49], hash_type: "type")
              else
                script = TypeScript.find_or_create_by(code_hash: CkbSync::Api.instance.token_class_script_code_hash, args: cell_output.type_script.args[0..49], hash_type: "type")
                output.update(type_script_id: script.id)
              end
            end
          end
          if chain == "ckb"
            m_nft_class_cell = TypeScript.where(code_hash: CkbSync::Api.instance.token_class_script_code_hash, args: cell_output.type_script.args[0..49]).first.cell_output
          else
            m_nft_class_cell = TypeScript.where(code_hash: CkbSync::Api.instance.token_class_script_code_hash, args: cell_output.type_script.args[0..49]).first.cell_outputs.live.last
          end
          parsed_class_data = CkbUtils.parse_token_class_data(m_nft_class_cell.data)
          udt.update!(published: true, full_name: parsed_class_data.name, icon_file: parsed_class_data.renderer)
          udt_account = cell_output.address.udt_accounts.find_or_create_by!(udt_type: cell_output.cell_type, type_hash: udt.type_hash, udt: udt)
          udt_account.update!(code_hash: udt.code_hash, amount: cell_output.udt_amount, published: udt.published, full_name: udt.full_name)
          progress_bar.increment
        end

        puts "done"
      end
    end
  end
end

MNftAccountDataGenerator.new
