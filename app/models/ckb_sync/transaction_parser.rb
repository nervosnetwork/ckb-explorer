module CkbSync
  class TransactionParser
    attr_reader :transaction, :extra_data
    attr_accessor :tx_attr, :cell_outputs_attrs, :cell_data_attrs, :cell_inputs_attrs, :cell_deps_attrs, :witnesses_attrs, :header_deps_attrs, :lock_script_attrs, :addresses_attrs,
                  :account_books_attrs, :type_script_attrs

    # {"transaction"=>{"version"=>"0x0", "cell_deps"=>[{"out_point"=>{"tx_hash"=>"0xcd52d714ddea04d2917892f16d47cbd0bbbb7d9ba281233ec4021f79fc34bccc", "index"=>"0x0"}, "dep_type"=>"code"}, {"out_point"=>{"tx_hash"=>"0x9154df4f7336402114d04495175b37390ce86a4906d2d4001cf02c3e6d97f39c", "index"=>"0x0"}, "dep_type"=>"code"}, {"out_point"=>{"tx_hash"=>"0xbcd73881ba53f1cd95d0c855395c4ffe6f54e041765d9ab7602d48a7cb71612e", "index"=>"0x0"}, "dep_type"=>"code"}, {"out_point"=>{"tx_hash"=>"0xf8de3bb47d055cdf460d93a2a6e1b05f7432f9777c8c474abf4eec1d4aee5d37", "index"=>"0x0"}, "dep_type"=>"dep_group"}, {"out_point"=>{"tx_hash"=>"0x053fdb4ed3181eab3a3a5f05693b53a8cdec0a24569e16369f444bac48be7de9", "index"=>"0x0"}, "dep_type"=>"code"}], "header_deps"=>[], "inputs"=>[{"since"=>"0x40000000669f4e30", "previous_output"=>{"tx_hash"=>"0x3d9a919a18d2cc2b64d2063626c75a6c97e87d2e8c30ec7bd33ef3ce14039934", "index"=>"0x0"}}, {"since"=>"0x0", "previous_output"=>{"tx_hash"=>"0x3d9a919a18d2cc2b64d2063626c75a6c97e87d2e8c30ec7bd33ef3ce14039934", "index"=>"0x1"}}, {"since"=>"0x0", "previous_output"=>{"tx_hash"=>"0x3d9a919a18d2cc2b64d2063626c75a6c97e87d2e8c30ec7bd33ef3ce14039934", "index"=>"0x2"}}], "outputs"=>[{"capacity"=>"0x7676d7e00", "lock"=>{"code_hash"=>"0x79f90bb5e892d80dd213439eeab551120eb417678824f282b4ffb5f21bad2e1e", "hash_type"=>"type", "args"=>"0x00c267a8b93cdae15fb06325f11a72b1047bd4d33c00"}, "type"=>{"code_hash"=>"0x1e44736436b406f8e48a30dfbddcf044feb0c9eebfe63b0f81cb5bb727d84854", "hash_type"=>"type", "args"=>"0x86c7429247beba7ddd6e4361bcdfc0510b0b644131e2afb7e486375249a01802"}}, {"capacity"=>"0x3691d6afc000", "lock"=>{"code_hash"=>"0x7f5a09b8bd0e85bcf2ccad96411ccba2f289748a1c16900b0635c2ed9126f288", "hash_type"=>"type", "args"=>"0x702359ea7f073558921eb50d8c1c77e92f760c8f8656bde4995f26b8963e2dd8f245705db4fe72be953e4f9ee3808a1700a578341aa80a8b2349c236c4af64e5e077710000000000"}, "type"=>nil}, {"capacity"=>"0xe529edc1ba", "lock"=>{"code_hash"=>"0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8", "hash_type"=>"type", "args"=>"0xc267a8b93cdae15fb06325f11a72b1047bd4d33c"}, "type"=>nil}], "outputs_data"=>["0xa0cf6037bfc238b179b74a30a9b12e15a4fbdd8881aebc8e5a66a8b5b5c95f0a6d833f7d5c1f8130fa2688970b421a57fbdffeff55bae5b4676043c543355799abe60200de0991241ff42c0255e2e2f65d114951c0a144e89d35527c582adc6603ff1ea2e17771000000000000000000000000000000000000000000000000000000000000000000000000001f779faa1f6184b10c9d865f62bba000e5d54e00a5d4b98cd768e43e376f68421a6b49de900100007c777100000000000001", "0x", "0x"], "witnesses"=>["0xc1030000100000006900000069000000550000005500000010000000550000005500000041000000e74f7818a6d2d1dda76593b30973967cd15fc6853731ecc0a5cf42cdb81859005b4a22781fa67973ccfbd3c5d0c1ccdd62506e2e99a049c19adc972e3909511a0054030000000000005003000010000000480300004c030000380300001c0000006c01000070010000740100007801000034030000500100002c000000340000005400000074000000940000009c000000c0000000e4000000e80000000c010000e0777100000000001c0000000200000014000000715ab282b873b79a7be8b0e8c13c4e8966a52040f7cfb9cf096dc32d69cac2b6f884bb2b1a8bb01660f3edc613ccfbeb7f3506d6f245705db4fe72be953e4f9ee3808a1700a578341aa80a8b2349c236c4af64e51a6b49de900100006d833f7d5c1f8130fa2688970b421a57fbdffeff55bae5b4676043c543355799abe602006d833f7d5c1f8130fa2688970b421a57fbdffeff55bae5b4676043c543355799abe602000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000024ea893c4fa601a048b1d3a8de265fd8b442ba2a1ac37d85dfe320a7c8c2069a000000000000000004000000b80100004c4f05500d310a045d500ed295c313abef5ae2862c24393fdacc2e2e4c2ba76b43828b9d505cfc4cbb06c1083817aa14c6e06df9c300687a61fa0ec947fe79962fb9c557845058409c8c929c05fe19cc818cd0da6f0bf887cdb7ca4e465e85f7796ddd0e1528507119e4869f5a24e613de92605fb220451c0d1727d65f1c030815155c3cb7acd350a011fc6c115f153c24055880abd2a1253281e4e8a894e2a0546ea8799b057667507cee0dc2c4b8b171a0331b3f9ec02cf8906ef52a873523d2dbe3ff9e5f58699a4f01509d5c06f8f45bfaf59625237cb06c099a9c2a59752d5c1032e503ef39fbded2d7506989c3d61168d80ae0e27a2b2ca904f768cc698f783fd4f5d6c45c1b7dd66bbb5090d5dd9cd0b9f66197a69ea30e933982c98b99a067b37a8d0b7adc687d8c8db44f0150da2c4d3f8cc63b7b827c24c55098ec49cc88a9c81ff07abb0057f7d1dc05c9304f0350287fc2f5b5005ff558ae296f4e9cb354876829fa9562d215fbf7cd9536d5e0e550a03eb9492d55fc2d9d63faf8ea6121d66a86230f0752178ab5643a81abff8380508ad8ce2ac94cf885730b362ca4b81787bf85b48d7f72ef7816130bdc54433f644fe9040000000000000000000000", "0x10000000100000001000000010000000", "0x55000000100000005500000055000000410000001ccd614d2dbafb3384f6da8d50fc6cef21e0280c05397a93072d1560c81fd8bf347d299d7879e7b7682812fbb9fd5841c97c2f92b5c3e64737aa61c9fab7a01401"], "hash"=>"0x74758da9a59938724839e442d6e2b10b5c69e8fa398d4bd4d9b64fd311801ac1"}, "cycles"=>"0x4819ea", "size"=>"0x853", "fee"=>"0x853", "timestamp"=>"0x190de4b95b3"}
    def initialize(tx, extra_data = {})
      @transaction = tx
      @extra_data = extra_data
      @cell_outputs_attrs = []
      @cell_data_attrs = []
      @cell_inputs_attrs = []
      @cell_deps_attrs = []
      @witnesses_attrs = []
      @header_deps_attrs = []
      @lock_script_attrs = Set.new
      @addresses_attrs = Set.new
      @account_books_attrs = Set.new
      @type_script_attrs = Set.new
    end

    def parse
      prepare_transaction_params
      prepare_cell_inputs_params
      prepare_cell_outputs_params
      prepare_cell_witness_params
      prepare_header_deps_params
      prepare_cell_deps_params
    end

    def prepare_transaction_params
      @tx_attr =
        {
          tx_hash: transaction.hash,
          version: transaction.version,
          tx_status: "pending",
          transaction_fee: extra_data["fee"]&.hex,
          bytes: extra_data["size"]&.hex,
          capacity_involved: nil,
          cycles: extra_data["cycles"]&.hex,
          live_cell_changes: transaction.outputs.count - transaction.inputs.count,
          confirmation_time: extra_data["timestamp"]&.hex,
        }
    end

    def prepare_cell_inputs_params
      transaction.inputs.each_with_index do |input, index|
        @cell_inputs_attrs <<
          {
            since: input.since,
            previous_tx_hash: input.previous_output.tx_hash,
            previous_index: input.previous_output.index,
            index:,
            tx_hash: transaction.hash,
            from_cell_base: input.previous_output.tx_hash == CellOutput::SYSTEM_TX_HASH,
            block_id: nil,
            cell_type: nil,
            ckb_transaction_id: nil,
            previous_cell_output_id: nil,
          }
      end
    end

    def prepare_cell_outputs_params
      transaction.outputs.each_with_index do |output, index|
        output_data = transaction.outputs_data[index]
        binary_data = CKB::Utils.hex_to_bin(output_data)
        cell_type = CkbUtils.cell_type(output.type, output_data)
        @lock_script_attrs << output.lock.to_h.merge({ script_hash: output.lock.compute_hash })
        @addresses_attrs << { address_hash: CkbUtils.generate_address(output.lock), lock_hash: output.lock.compute_hash }
        @account_books_attrs << { lock_script_hash: output.lock.compute_hash, tx_hash: transaction.hash }
        @type_script_attrs << output.type.to_h.merge({ script_hash: output.type.compute_hash }) if output.type.present?
        @cell_outputs_attrs <<
          {
            capacity: output.capacity,
            tx_hash: transaction.hash,
            cell_index: index,
            status: "pending",
            occupied_capacity: CkbUtils.cal_cell_min_capacity(output.lock, output.type, binary_data),
            address_id: nil,
            cell_type:,
            lock_script_hash: output.lock.compute_hash,
            type_hash: output.type&.compute_hash,
            udt_amount: udt_amount(cell_type, output_data, output.type&.args),
            data_size: binary_data.bytesize,
            data_hash: CKB::Blake2b.hexdigest(binary_data),
            block_id: nil,
            block_timestamp: nil,
            dao: nil,
          }

        if output_data != "0x"
          @cell_data_attrs <<
            {
              data: output_data,
              cell_index: index,
              tx_hash: transaction.hash,
            }
        end
      end
    end

    def prepare_cell_witness_params
      transaction.witnesses.each_with_index do |witness, index|
        @witnesses_attrs <<
          {
            data: witness,
            index:,
            tx_hash: transaction.hash,
          }
      end
    end

    def prepare_header_deps_params
      transaction.header_deps.each_with_index do |header_dep, index|
        @header_deps_attrs <<
          {
            header_hash: header_dep,
            index:,
            tx_hash: transaction.hash,
          }
      end
    end

    def prepare_cell_deps_params
      transaction.cell_deps.each do |cell_dep|
        @cell_deps_attrs <<
          {
            dep_type: cell_dep.dep_type,
            out_point_tx_hash: cell_dep.out_point.tx_hash,
            out_point_index: cell_dep.out_point.index,
            tx_hash: transaction.hash,
          }
      end
    end

    private

    def udt_amount(cell_type, output_data, type_script_args)
      case cell_type
      when "udt", "xudt", "xudt_compatible"
        CkbUtils.parse_udt_cell_data(output_data)
      when "omiga_inscription"
        CkbUtils.parse_omiga_inscription_data(output_data)[:mint_limit]
      when "m_nft_token"
        "0x#{type_script_args[-8..]}".hex
      end
    end
  end
end
