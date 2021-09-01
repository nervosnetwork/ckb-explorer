namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_m_nft_token_full_name_and_icon"
  task fill_m_nft_token_full_name_and_icon: :environment do
    progress_bar = ProgressBar.create(total: Udt.m_nft_token.count, format: "%e %B %p%% %c/%C")
    Udt.m_nft_token.where(full_name: nil).find_each do |udt|
      m_nft_type = TypeScript.where(code_hash: udt.code_hash, hash_type: udt.hash_type, args: udt.args).first
      m_nft_cell = m_nft_type.cell_outputs.last
      m_nft_class_type = TypeScript.where(code_hash: CkbSync::Api.instance.token_class_script_code_hash, args: m_nft_cell.type_script.args[0..49]).first
      if m_nft_class_type.present?
        m_nft_class_cell = m_nft_class_type.cell_outputs.last
        parsed_class_data = CkbUtils.parse_token_class_data(m_nft_class_cell.data)
        udt.update!(full_name: parsed_class_data.name, icon_file: parsed_class_data.renderer, published: true)
      end
      progress_bar.increment
    rescue => e
      puts "error: #{e}, udt_id: #{udt.id}"
    end

    puts "done"
  end
end
