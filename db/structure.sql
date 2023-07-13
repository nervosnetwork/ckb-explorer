SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gin; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA public;


--
-- Name: EXTENSION btree_gin; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gin IS 'support for indexing common datatypes in GIN';


--
-- Name: array_subtract(anyarray, anyarray); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.array_subtract(minuend anyarray, subtrahend anyarray, OUT difference anyarray) RETURNS anyarray
    LANGUAGE plpgsql STRICT
    AS $_$
begin
    execute 'select array(select unnest($1) except select unnest($2))'
      using minuend, subtrahend
       into difference;
end;
$_$;


--
-- Name: decrease_ckb_transactions_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.decrease_ckb_transactions_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$begin
    UPDATE global_statistics SET value = value - 1 WHERE name = 'ckb_transactions';
    if new.tx_status = 0 then
      update global_statistics SET value = value - 1 where name = 'pending_transactions';
    end if;
    if new.tx_status = 2 then
      update global_statistics SET value = value - 1 where name = 'committed_transactions';
    end if;
    RETURN NEW;
end;$$;


--
-- Name: increase_ckb_transactions_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increase_ckb_transactions_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$begin

  UPDATE global_statistics SET value = value + 1 WHERE name = 'ckb_transactions';
  if new.tx_status = 0 then
    update global_statistics SET value = value + 1 where name = 'pending_transactions';
  end if;
  if new.tx_status = 2 then
    update global_statistics SET value = value + 1 where name = 'committed_transactions';
  end if;
  RETURN NEW;
end;$$;


--
-- Name: insert_into_ckb_transactions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_into_ckb_transactions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    header_deps_size integer;
    i integer;
    header_hash bytea;
    transaction_id bigint;
    w text;
    out_point jsonb;
    cell_output_record record;
BEGIN
  INSERT INTO ckb_transactions
  (
    tx_status, tx_hash,
    bytes, cycles, version,
    transaction_fee, created_at, updated_at
  )
  VALUES
  (NEW.tx_status, NEW.tx_hash,
  NEW.tx_size, NEW.cycles, COALESCE(NEW.version, 0),
  NEW.transaction_fee, NOW(), NOW()
  )
  RETURNING id into transaction_id;

  -- insert witnesses
  i := 0;
  for w in
    select jsonb_array_elements_text(NEW.witnesses)
  loop
    INSERT INTO witnesses (ckb_transaction_id, index, data)
    values
    (transaction_id, i, (E'\x' || substring(w from 3))::bytea);
    i := i+1;
  end loop;

  -- insert header_deps
  i := 0;
  for w in
    select jsonb_array_elements_text(NEW.header_deps)
  loop
    INSERT INTO header_dependencies
    (ckb_transaction_id, header_hash, index)
    values
    (transaction_id, (E'\x' || substring(w from 3))::bytea, i);
  end loop;

  -- insert cell_deps
  for out_point in
    select jsonb_array_elements(NEW.cell_deps)
  loop
    SELECT id, tx_hash, cell_index
    INTO cell_output_record
    FROM cell_outputs
    WHERE tx_hash = (E'\x' || substring((out_point->'out_point'->>'tx_hash') from 3))::bytea
    AND cell_index = (out_point->'out_point'->>'index')::integer;

    IF FOUND THEN
      insert into cell_dependencies
      (ckb_transaction_id, contract_cell_id, dep_type, implicit)
      values(
        transaction_id, cell_output_record.id,
        CASE WHEN out_point->>'dep_type' = 'code' THEN 0
             WHEN out_point->>'dep_type' = 'dep_group' THEN 1
             ELSE NULL
        END, false
      );
    END IF;
  end loop;

  RETURN NEW;
END;
$$;


--
-- Name: sync_full_account_book(); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sync_full_account_book()
    LANGUAGE plpgsql
    AS $$
declare
    c cursor for select * from ckb_transactions;
    i int;
     row  RECORD;
begin
    open c;
    LOOP
      FETCH FROM c INTO row;
      EXIT WHEN NOT FOUND;
      foreach i in array row.contained_address_ids loop
        insert into account_books (ckb_transaction_id, address_id)
        values (row.id, i) ON CONFLICT DO NOTHING;
        end loop;
    END LOOP;
    close c;
end
$$;


--
-- Name: synx_tx_to_account_book(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.synx_tx_to_account_book() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  i int;
  to_add int[];
  to_remove int[];
   BEGIN
   RAISE NOTICE 'trigger ckb tx(%)', new.id;
   if new.contained_address_ids is null then
   	new.contained_address_ids := array[]::int[];
	end if;
	if old is null
	then
		to_add := new.contained_address_ids;
		to_remove := array[]::int[];
	else

	   to_add := array_subtract(new.contained_address_ids, old.contained_address_ids);
	   to_remove := array_subtract(old.contained_address_ids, new.contained_address_ids);
	end if;

   if to_add is not null then
	   FOREACH i IN ARRAY to_add
	   LOOP
	   	RAISE NOTICE 'ckb_tx_addr_id(%)', i;
			insert into account_books (ckb_transaction_id, address_id)
			values (new.id, i);
	   END LOOP;
	end if;
	if to_remove is not null then
	   delete from account_books where ckb_transaction_id = new.id and address_id = ANY(to_remove);
	end if;
      RETURN NEW;
   END;
$$;


--
-- Name: update_cell_dependencies_implicit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_cell_dependencies_implicit() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    cur CURSOR FOR SELECT id, cell_deps FROM ckb_transactions;
    transaction_id bigint;
    cell_deps jsonb;
    out_point jsonb;
    cell_output_record record;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO transaction_id, cell_deps;
        EXIT WHEN NOT FOUND;

        FOR out_point IN
            SELECT jsonb_array_elements(cell_deps)
        LOOP
            SELECT id, tx_hash, cell_index
            INTO cell_output_record
            FROM cell_outputs
            WHERE tx_hash = (E'\x' || substring((out_point->'out_point'->>'tx_hash') from 3))::bytea
            AND cell_index = (out_point->'out_point'->>'index')::integer;

            IF FOUND THEN
                UPDATE cell_dependencies
                SET implicit = false
                WHERE ckb_transaction_id = transaction_id
                AND contract_cell_id = cell_output_record.id;
            END IF;
        END LOOP;
    END LOOP;
    CLOSE cur;
END;
$$;


--
-- Name: update_cell_inputs(); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.update_cell_inputs()
    LANGUAGE plpgsql
    AS $$
DECLARE
  input_id BIGINT;
  input_output_id BIGINT;
  input_previous_output JSONB;
  input_tx_hash BYTEA;
  input_cell_index BIGINT;
  output_id BIGINT;
BEGIN
  FOR input_id, input_previous_output, input_output_id IN
    SELECT ci.id, ci.previous_output, ci.previous_cell_output_id
    FROM cell_inputs ci
    WHERE ci.previous_cell_output_id IS NULL AND ci.previous_output->>'tx_hash' <> '0x0000000000000000000000000000000000000000000000000000000000000000'
  LOOP
    input_tx_hash := decode(input_previous_output->>'tx_hash', 'hex');
    input_cell_index := input_previous_output->>'index';

    SELECT id INTO output_id FROM cell_outputs WHERE tx_hash = input_tx_hash AND cell_index = input_cell_index;

    IF output_id IS NOT NULL THEN
      UPDATE cell_inputs SET previous_cell_output_id = output_id WHERE id = input_id;
    END IF;
  END LOOP;
END;
$$;


--
-- Name: update_ckb_transactions_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_ckb_transactions_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$begin
    if new.tx_status = 0 then
      update global_statistics SET value = value + 1 where name = 'pending_transactions';
    end if;
    if new.tx_status = 2 then
      update global_statistics SET value = value + 1 where name = 'committed_transactions';
    end if;
    RETURN NEW;
  end;$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_books; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_books (
    id bigint NOT NULL,
    address_id bigint,
    ckb_transaction_id bigint
);


--
-- Name: account_books_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_books_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_books_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_books_id_seq OWNED BY public.account_books.id;


--
-- Name: address_block_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.address_block_snapshots (
    id bigint NOT NULL,
    address_id bigint,
    block_id bigint,
    block_number bigint,
    final_state jsonb
);


--
-- Name: address_block_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.address_block_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: address_block_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.address_block_snapshots_id_seq OWNED BY public.address_block_snapshots.id;


--
-- Name: address_dao_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.address_dao_transactions (
    ckb_transaction_id bigint,
    address_id bigint
);


--
-- Name: address_udt_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.address_udt_transactions (
    ckb_transaction_id bigint,
    address_id bigint
);


--
-- Name: addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.addresses (
    id bigint NOT NULL,
    balance numeric(30,0) DEFAULT 0,
    address_hash bytea,
    cell_consumed bigint,
    ckb_transactions_count bigint DEFAULT 0.0,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    lock_hash bytea,
    dao_deposit numeric(30,0) DEFAULT 0.0,
    interest numeric(30,0) DEFAULT 0.0,
    block_timestamp bigint,
    live_cells_count bigint DEFAULT 0.0,
    mined_blocks_count integer DEFAULT 0,
    visible boolean DEFAULT true,
    average_deposit_time bigint,
    unclaimed_compensation numeric(30,0),
    is_depositor boolean DEFAULT false,
    dao_transactions_count bigint DEFAULT 0.0,
    lock_script_id bigint,
    balance_occupied numeric(30,0) DEFAULT 0.0
);


--
-- Name: addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.addresses_id_seq OWNED BY public.addresses.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blocks (
    id bigint NOT NULL,
    block_hash bytea,
    number bigint,
    parent_hash bytea,
    "timestamp" bigint,
    transactions_root bytea,
    proposals_hash bytea,
    uncles_count integer,
    extra_hash bytea,
    uncle_block_hashes bytea,
    version integer,
    proposals bytea,
    proposals_count integer,
    cell_consumed bigint,
    miner_hash bytea,
    reward numeric(30,0),
    total_transaction_fee numeric(30,0),
    ckb_transactions_count bigint DEFAULT 0.0,
    total_cell_capacity numeric(30,0),
    epoch bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    address_ids character varying[],
    reward_status integer DEFAULT 0,
    received_tx_fee_status integer DEFAULT 0,
    received_tx_fee numeric(30,0) DEFAULT 0.0,
    target_block_reward_status integer DEFAULT 0,
    miner_lock_hash bytea,
    dao character varying,
    primary_reward numeric(30,0) DEFAULT 0.0,
    secondary_reward numeric(30,0) DEFAULT 0.0,
    nonce numeric(50,0) DEFAULT 0.0,
    start_number numeric(30,0) DEFAULT 0.0,
    length numeric(30,0) DEFAULT 0.0,
    compact_target numeric(20,0),
    live_cell_changes integer,
    block_time bigint,
    block_size bigint,
    proposal_reward numeric(30,0),
    commit_reward numeric(30,0),
    miner_message character varying,
    extension jsonb,
    median_timestamp bigint DEFAULT 0.0,
    ckb_node_version character varying,
    cycles bigint
);


--
-- Name: COLUMN blocks.ckb_node_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.blocks.ckb_node_version IS 'ckb node version, e.g. 0.105.1';


--
-- Name: average_block_time_by_hour; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.average_block_time_by_hour AS
 SELECT (blocks."timestamp" / 3600000) AS hour,
    avg(blocks.block_time) AS avg_block_time_per_hour
   FROM public.blocks
  GROUP BY (blocks."timestamp" / 3600000)
  WITH NO DATA;


--
-- Name: block_propagation_delays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.block_propagation_delays (
    id bigint NOT NULL,
    block_hash character varying,
    created_at_unixtimestamp integer,
    durations jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: block_propagation_delays_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.block_propagation_delays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: block_propagation_delays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.block_propagation_delays_id_seq OWNED BY public.block_propagation_delays.id;


--
-- Name: block_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.block_statistics (
    id bigint NOT NULL,
    difficulty character varying,
    hash_rate character varying,
    live_cells_count character varying DEFAULT '0'::character varying,
    dead_cells_count character varying DEFAULT '0'::character varying,
    block_number bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    epoch_number bigint,
    primary_issuance numeric(36,8),
    secondary_issuance numeric(36,8),
    accumulated_total_deposits numeric(36,8),
    accumulated_rate numeric(36,8),
    unissued_secondary_issuance numeric(36,8),
    total_occupied_capacities numeric(36,8)
);


--
-- Name: COLUMN block_statistics.accumulated_total_deposits; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.block_statistics.accumulated_total_deposits IS 'C_i in DAO header (accumulated deposits)';


--
-- Name: COLUMN block_statistics.accumulated_rate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.block_statistics.accumulated_rate IS 'AR_i in DAO header';


--
-- Name: COLUMN block_statistics.unissued_secondary_issuance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.block_statistics.unissued_secondary_issuance IS 'S_i in DAO header';


--
-- Name: COLUMN block_statistics.total_occupied_capacities; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.block_statistics.total_occupied_capacities IS 'U_i in DAO header';


--
-- Name: block_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.block_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: block_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.block_statistics_id_seq OWNED BY public.block_statistics.id;


--
-- Name: block_time_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.block_time_statistics (
    id bigint NOT NULL,
    stat_timestamp numeric(30,0),
    avg_block_time_per_hour numeric,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: block_time_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.block_time_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: block_time_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.block_time_statistics_id_seq OWNED BY public.block_time_statistics.id;


--
-- Name: block_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.block_transactions (
    id bigint NOT NULL,
    block_id bigint,
    ckb_transaction_id bigint,
    tx_index integer DEFAULT 0 NOT NULL
);


--
-- Name: block_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.block_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: block_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.block_transactions_id_seq OWNED BY public.block_transactions.id;


--
-- Name: blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blocks_id_seq OWNED BY public.blocks.id;


--
-- Name: cell_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cell_data (
    cell_output_id bigint NOT NULL,
    data bytea NOT NULL
);


--
-- Name: cell_data_cell_output_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cell_data_cell_output_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cell_data_cell_output_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cell_data_cell_output_id_seq OWNED BY public.cell_data.cell_output_id;


--
-- Name: cell_dependencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cell_dependencies (
    id bigint NOT NULL,
    contract_id bigint,
    ckb_transaction_id bigint NOT NULL,
    dep_type integer,
    contract_cell_id bigint NOT NULL,
    script_id bigint,
    implicit boolean DEFAULT true NOT NULL
);


--
-- Name: cell_dependencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cell_dependencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cell_dependencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cell_dependencies_id_seq OWNED BY public.cell_dependencies.id;


--
-- Name: cell_inputs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cell_inputs (
    id bigint NOT NULL,
    ckb_transaction_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    previous_cell_output_id bigint,
    from_cell_base boolean DEFAULT false,
    block_id numeric(30,0),
    since numeric(30,0) DEFAULT 0.0,
    cell_type integer DEFAULT 0,
    index integer,
    previous_tx_hash bytea,
    previous_index integer
);


--
-- Name: cell_inputs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cell_inputs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cell_inputs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cell_inputs_id_seq OWNED BY public.cell_inputs.id;


--
-- Name: cell_outputs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cell_outputs (
    id bigint NOT NULL,
    capacity numeric(64,2),
    data bytea,
    ckb_transaction_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    status smallint DEFAULT 0,
    address_id numeric(30,0),
    block_id numeric(30,0),
    tx_hash bytea,
    cell_index integer,
    consumed_by_id numeric(30,0),
    cell_type integer DEFAULT 0,
    data_size integer,
    occupied_capacity numeric(30,0),
    block_timestamp numeric(30,0),
    consumed_block_timestamp numeric(30,0),
    type_hash character varying,
    udt_amount numeric(40,0),
    dao character varying,
    lock_script_id bigint,
    type_script_id bigint,
    data_hash bytea
);


--
-- Name: cell_outputs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cell_outputs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cell_outputs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cell_outputs_id_seq OWNED BY public.cell_outputs.id;


--
-- Name: ckb_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ckb_transactions (
    id bigint NOT NULL,
    tx_hash bytea,
    block_id bigint,
    block_number bigint,
    block_timestamp bigint,
    tx_status integer DEFAULT 2 NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    is_cellbase boolean DEFAULT false,
    transaction_fee bigint,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    live_cell_changes integer,
    capacity_involved numeric(30,0),
    tags character varying[] DEFAULT '{}'::character varying[],
    bytes bigint DEFAULT 0,
    cycles bigint,
    confirmation_time integer
)
PARTITION BY LIST (tx_status);


--
-- Name: ckb_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ckb_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ckb_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ckb_transactions_id_seq OWNED BY public.ckb_transactions.id;


--
-- Name: ckb_transactions_committed; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ckb_transactions_committed (
    id bigint DEFAULT nextval('public.ckb_transactions_id_seq'::regclass) NOT NULL,
    tx_hash bytea,
    block_id bigint,
    block_number bigint,
    block_timestamp bigint,
    tx_status integer DEFAULT 2 NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    is_cellbase boolean DEFAULT false,
    transaction_fee bigint,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    live_cell_changes integer,
    capacity_involved numeric(30,0),
    tags character varying[] DEFAULT '{}'::character varying[],
    bytes bigint DEFAULT 0,
    cycles bigint,
    confirmation_time integer
);


--
-- Name: ckb_transactions_pending; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ckb_transactions_pending (
    id bigint DEFAULT nextval('public.ckb_transactions_id_seq'::regclass) NOT NULL,
    tx_hash bytea,
    block_id bigint,
    block_number bigint,
    block_timestamp bigint,
    tx_status integer DEFAULT 2 NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    is_cellbase boolean DEFAULT false,
    transaction_fee bigint,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    live_cell_changes integer,
    capacity_involved numeric(30,0),
    tags character varying[] DEFAULT '{}'::character varying[],
    bytes bigint DEFAULT 0,
    cycles bigint,
    confirmation_time integer
);


--
-- Name: ckb_transactions_proposed; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ckb_transactions_proposed (
    id bigint DEFAULT nextval('public.ckb_transactions_id_seq'::regclass) NOT NULL,
    tx_hash bytea,
    block_id bigint,
    block_number bigint,
    block_timestamp bigint,
    tx_status integer DEFAULT 2 NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    is_cellbase boolean DEFAULT false,
    transaction_fee bigint,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    live_cell_changes integer,
    capacity_involved numeric(30,0),
    tags character varying[] DEFAULT '{}'::character varying[],
    bytes bigint DEFAULT 0,
    cycles bigint,
    confirmation_time integer
);


--
-- Name: ckb_transactions_rejected; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ckb_transactions_rejected (
    id bigint DEFAULT nextval('public.ckb_transactions_id_seq'::regclass) NOT NULL,
    tx_hash bytea,
    block_id bigint,
    block_number bigint,
    block_timestamp bigint,
    tx_status integer DEFAULT 2 NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    is_cellbase boolean DEFAULT false,
    transaction_fee bigint,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    live_cell_changes integer,
    capacity_involved numeric(30,0),
    tags character varying[] DEFAULT '{}'::character varying[],
    bytes bigint DEFAULT 0,
    cycles bigint,
    confirmation_time integer
);


--
-- Name: contracts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contracts (
    id bigint NOT NULL,
    code_hash bytea,
    hash_type character varying,
    deployed_args character varying,
    role character varying DEFAULT 'type_script'::character varying,
    name character varying,
    symbol character varying,
    description character varying,
    verified boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deprecated boolean
);


--
-- Name: contracts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contracts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contracts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contracts_id_seq OWNED BY public.contracts.id;


--
-- Name: daily_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_statistics (
    id bigint NOT NULL,
    transactions_count character varying DEFAULT 0,
    addresses_count character varying DEFAULT 0,
    total_dao_deposit character varying DEFAULT 0.0,
    block_timestamp numeric(30,0),
    created_at_unixtimestamp integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    dao_depositors_count character varying DEFAULT '0'::character varying,
    unclaimed_compensation character varying DEFAULT '0'::character varying,
    claimed_compensation character varying DEFAULT '0'::character varying,
    average_deposit_time character varying DEFAULT '0'::character varying,
    estimated_apc character varying DEFAULT '0'::character varying,
    mining_reward character varying DEFAULT '0'::character varying,
    deposit_compensation character varying DEFAULT '0'::character varying,
    treasury_amount character varying DEFAULT '0'::character varying,
    live_cells_count character varying DEFAULT '0'::character varying,
    dead_cells_count character varying DEFAULT '0'::character varying,
    avg_hash_rate character varying DEFAULT '0'::character varying,
    avg_difficulty character varying DEFAULT '0'::character varying,
    uncle_rate character varying DEFAULT '0'::character varying,
    total_depositors_count character varying DEFAULT '0'::character varying,
    total_tx_fee numeric(30,0),
    address_balance_distribution jsonb,
    occupied_capacity numeric(30,0),
    daily_dao_deposit numeric(30,0),
    daily_dao_depositors_count integer,
    daily_dao_withdraw numeric(30,0),
    circulation_ratio numeric,
    total_supply numeric(30,0),
    circulating_supply numeric,
    block_time_distribution jsonb,
    epoch_time_distribution jsonb,
    epoch_length_distribution jsonb,
    average_block_time jsonb,
    nodes_distribution jsonb,
    nodes_count integer,
    locked_capacity numeric(30,0)
);


--
-- Name: daily_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.daily_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: daily_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.daily_statistics_id_seq OWNED BY public.daily_statistics.id;


--
-- Name: dao_contracts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dao_contracts (
    id bigint NOT NULL,
    total_deposit numeric(30,0) DEFAULT 0.0,
    claimed_compensation numeric(30,0) DEFAULT 0.0,
    deposit_transactions_count bigint DEFAULT 0,
    withdraw_transactions_count bigint DEFAULT 0,
    depositors_count integer DEFAULT 0,
    total_depositors_count bigint DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    unclaimed_compensation numeric(30,0),
    ckb_transactions_count numeric(30,0) DEFAULT 0.0
);


--
-- Name: dao_contracts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dao_contracts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dao_contracts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dao_contracts_id_seq OWNED BY public.dao_contracts.id;


--
-- Name: dao_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dao_events (
    id bigint NOT NULL,
    block_id bigint,
    ckb_transaction_id bigint,
    address_id bigint,
    contract_id bigint,
    event_type smallint,
    value numeric(30,0) DEFAULT 0.0,
    status smallint DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    block_timestamp numeric(30,0)
);


--
-- Name: dao_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dao_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dao_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dao_events_id_seq OWNED BY public.dao_events.id;


--
-- Name: deployed_cells; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deployed_cells (
    id bigint NOT NULL,
    cell_output_id bigint NOT NULL,
    contract_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: deployed_cells_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deployed_cells_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deployed_cells_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deployed_cells_id_seq OWNED BY public.deployed_cells.id;


--
-- Name: epoch_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.epoch_statistics (
    id bigint NOT NULL,
    difficulty character varying,
    uncle_rate character varying,
    epoch_number bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    hash_rate character varying,
    epoch_time bigint,
    epoch_length integer,
    largest_block_number integer,
    largest_block_size integer,
    largest_tx_hash bytea,
    largest_tx_bytes integer,
    max_block_cycles bigint,
    max_tx_cycles integer
);


--
-- Name: epoch_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.epoch_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: epoch_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.epoch_statistics_id_seq OWNED BY public.epoch_statistics.id;


--
-- Name: forked_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forked_blocks (
    id bigint NOT NULL,
    block_hash bytea,
    number bigint,
    parent_hash bytea,
    "timestamp" bigint,
    transactions_root bytea,
    proposals_hash bytea,
    uncles_count integer,
    extra_hash bytea,
    uncle_block_hashes bytea,
    version integer,
    proposals bytea,
    proposals_count integer,
    cell_consumed numeric(30,0),
    miner_hash bytea,
    reward numeric(30,0),
    total_transaction_fee numeric(30,0),
    ckb_transactions_count numeric(30,0) DEFAULT 0.0,
    total_cell_capacity numeric(30,0),
    epoch bigint,
    address_ids character varying[],
    reward_status integer DEFAULT 0,
    received_tx_fee_status integer DEFAULT 0,
    received_tx_fee numeric(30,0) DEFAULT 0.0,
    target_block_reward_status integer DEFAULT 0,
    miner_lock_hash bytea,
    dao character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    primary_reward numeric(30,0) DEFAULT 0.0,
    secondary_reward numeric(30,0) DEFAULT 0.0,
    nonce numeric(50,0) DEFAULT 0.0,
    start_number numeric(30,0) DEFAULT 0.0,
    length numeric(30,0) DEFAULT 0.0,
    compact_target numeric(20,0),
    live_cell_changes integer,
    block_time numeric(13,0),
    block_size integer,
    proposal_reward numeric(30,0),
    commit_reward numeric(30,0),
    miner_message character varying,
    extension jsonb,
    median_timestamp numeric DEFAULT 0.0,
    ckb_node_version character varying,
    cycles bigint
);


--
-- Name: COLUMN forked_blocks.ckb_node_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.forked_blocks.ckb_node_version IS 'ckb node version, e.g. 0.105.1';


--
-- Name: forked_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forked_blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forked_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.forked_blocks_id_seq OWNED BY public.forked_blocks.id;


--
-- Name: forked_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forked_events (
    id bigint NOT NULL,
    block_number numeric(30,0),
    epoch_number numeric(30,0),
    block_timestamp numeric(30,0),
    status smallint DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: forked_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forked_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forked_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.forked_events_id_seq OWNED BY public.forked_events.id;


--
-- Name: global_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.global_statistics (
    id bigint NOT NULL,
    name character varying,
    value bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    comment character varying,
    "#<ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition" character varying
);


--
-- Name: COLUMN global_statistics.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.global_statistics.name IS 'the name of something, e.g. my_table_rows_count';


--
-- Name: COLUMN global_statistics.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.global_statistics.value IS 'value of something, e.g. 888';


--
-- Name: global_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.global_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: global_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.global_statistics_id_seq OWNED BY public.global_statistics.id;


--
-- Name: header_dependencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.header_dependencies (
    id bigint NOT NULL,
    header_hash bytea NOT NULL,
    ckb_transaction_id bigint NOT NULL,
    index integer NOT NULL
);


--
-- Name: header_dependencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.header_dependencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: header_dependencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.header_dependencies_id_seq OWNED BY public.header_dependencies.id;


--
-- Name: lock_scripts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lock_scripts (
    id bigint NOT NULL,
    args character varying,
    code_hash bytea,
    cell_output_id bigint,
    address_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    hash_type character varying,
    script_hash character varying,
    script_id bigint
);


--
-- Name: lock_scripts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.lock_scripts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lock_scripts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.lock_scripts_id_seq OWNED BY public.lock_scripts.id;


--
-- Name: mining_infos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mining_infos (
    id bigint NOT NULL,
    address_id bigint,
    block_id bigint,
    block_number numeric(30,0),
    status smallint DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: mining_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mining_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mining_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mining_infos_id_seq OWNED BY public.mining_infos.id;


--
-- Name: nrc_factory_cells; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nrc_factory_cells (
    id bigint NOT NULL,
    code_hash bytea,
    hash_type character varying,
    args character varying,
    name character varying,
    symbol character varying,
    base_token_uri character varying,
    extra_data character varying,
    verified boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: nrc_factory_cells_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nrc_factory_cells_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nrc_factory_cells_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nrc_factory_cells_id_seq OWNED BY public.nrc_factory_cells.id;


--
-- Name: old_ckb_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.old_ckb_transactions (
    id bigint NOT NULL,
    tx_hash bytea,
    block_id bigint,
    block_number numeric(30,0),
    block_timestamp numeric(30,0),
    transaction_fee numeric(30,0),
    version integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_cellbase boolean DEFAULT false,
    header_deps bytea,
    cell_deps jsonb,
    witnesses jsonb,
    live_cell_changes integer,
    capacity_involved numeric(30,0),
    contained_address_ids bigint[] DEFAULT '{}'::bigint[],
    tags character varying[] DEFAULT '{}'::character varying[],
    contained_udt_ids bigint[] DEFAULT '{}'::bigint[],
    dao_address_ids bigint[] DEFAULT '{}'::bigint[],
    udt_address_ids bigint[] DEFAULT '{}'::bigint[],
    bytes integer DEFAULT 0,
    cycles integer,
    confirmation_time integer,
    tx_status integer DEFAULT 2 NOT NULL
);


--
-- Name: COLUMN old_ckb_transactions.confirmation_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.old_ckb_transactions.confirmation_time IS 'it cost how many seconds to confirm this transaction';


--
-- Name: old_ckb_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.old_ckb_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: old_ckb_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.old_ckb_transactions_id_seq OWNED BY public.old_ckb_transactions.id;


--
-- Name: pool_transaction_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pool_transaction_entries (
    id bigint NOT NULL,
    cell_deps jsonb,
    tx_hash bytea,
    header_deps jsonb,
    inputs jsonb,
    outputs jsonb,
    outputs_data jsonb,
    version integer,
    witnesses jsonb,
    transaction_fee numeric(30,0),
    block_number numeric(30,0),
    block_timestamp numeric(30,0),
    cycles numeric(30,0),
    tx_size numeric(30,0),
    display_inputs jsonb,
    display_outputs jsonb,
    tx_status integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    detailed_message text,
    bytes integer DEFAULT 0
);


--
-- Name: pool_transaction_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pool_transaction_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pool_transaction_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pool_transaction_entries_id_seq OWNED BY public.pool_transaction_entries.id;


--
-- Name: referring_cells; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referring_cells (
    id bigint NOT NULL,
    cell_output_id bigint,
    contract_id bigint,
    ckb_transaction_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: referring_cells_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.referring_cells_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: referring_cells_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.referring_cells_id_seq OWNED BY public.referring_cells.id;


--
-- Name: reject_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reject_reasons (
    id bigint NOT NULL,
    ckb_transaction_id bigint NOT NULL,
    message text
);


--
-- Name: reject_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reject_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reject_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reject_reasons_id_seq OWNED BY public.reject_reasons.id;


--
-- Name: rolling_avg_block_time; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.rolling_avg_block_time AS
 SELECT (average_block_time_by_hour.hour * 3600) AS "timestamp",
    avg(average_block_time_by_hour.avg_block_time_per_hour) OVER (ORDER BY average_block_time_by_hour.hour ROWS BETWEEN 24 PRECEDING AND CURRENT ROW) AS avg_block_time_daily,
    avg(average_block_time_by_hour.avg_block_time_per_hour) OVER (ORDER BY average_block_time_by_hour.hour ROWS BETWEEN (7 * 24) PRECEDING AND CURRENT ROW) AS avg_block_time_weekly
   FROM public.average_block_time_by_hour
  WITH NO DATA;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: script_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.script_transactions (
    id bigint NOT NULL,
    script_id bigint NOT NULL,
    ckb_transaction_id bigint NOT NULL
);


--
-- Name: script_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.script_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: script_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.script_transactions_id_seq OWNED BY public.script_transactions.id;


--
-- Name: scripts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scripts (
    id bigint NOT NULL,
    args character varying,
    script_hash character varying,
    is_contract boolean DEFAULT false,
    contract_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: scripts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scripts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scripts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scripts_id_seq OWNED BY public.scripts.id;


--
-- Name: statistic_infos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.statistic_infos (
    id bigint NOT NULL,
    transactions_last_24hrs bigint,
    transactions_count_per_minute bigint,
    average_block_time double precision,
    hash_rate numeric,
    address_balance_ranking jsonb,
    miner_ranking jsonb,
    blockchain_info character varying,
    last_n_days_transaction_fee_rates jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    pending_transaction_fee_rates jsonb,
    transaction_fee_rates jsonb
);


--
-- Name: statistic_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.statistic_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: statistic_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.statistic_infos_id_seq OWNED BY public.statistic_infos.id;


--
-- Name: table_record_counts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.table_record_counts (
    id bigint NOT NULL,
    table_name character varying,
    count bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: table_record_counts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.table_record_counts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: table_record_counts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.table_record_counts_id_seq OWNED BY public.table_record_counts.id;


--
-- Name: token_collections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.token_collections (
    id bigint NOT NULL,
    standard character varying,
    name character varying,
    description text,
    creator_id integer,
    icon_url character varying,
    items_count integer,
    holders_count integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    symbol character varying,
    cell_id integer,
    verified boolean DEFAULT false,
    type_script_id integer,
    sn character varying
);


--
-- Name: token_collections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.token_collections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: token_collections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.token_collections_id_seq OWNED BY public.token_collections.id;


--
-- Name: token_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.token_items (
    id bigint NOT NULL,
    collection_id integer,
    token_id numeric(80,0),
    name character varying,
    icon_url character varying,
    owner_id integer,
    metadata_url character varying,
    cell_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    type_script_id integer,
    status integer DEFAULT 1
);


--
-- Name: token_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.token_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: token_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.token_items_id_seq OWNED BY public.token_items.id;


--
-- Name: token_transfers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.token_transfers (
    id bigint NOT NULL,
    item_id integer,
    from_id integer,
    to_id integer,
    transaction_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    action integer
);


--
-- Name: token_transfers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.token_transfers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: token_transfers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.token_transfers_id_seq OWNED BY public.token_transfers.id;


--
-- Name: transaction_address_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction_address_changes (
    id bigint NOT NULL,
    ckb_transaction_id bigint NOT NULL,
    address_id bigint NOT NULL,
    changes jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: transaction_address_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transaction_address_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_address_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transaction_address_changes_id_seq OWNED BY public.transaction_address_changes.id;


--
-- Name: transaction_propagation_delays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction_propagation_delays (
    id bigint NOT NULL,
    tx_hash character varying,
    created_at_unixtimestamp integer,
    durations jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: transaction_propagation_delays_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transaction_propagation_delays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_propagation_delays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transaction_propagation_delays_id_seq OWNED BY public.transaction_propagation_delays.id;


--
-- Name: tx_display_infos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tx_display_infos (
    ckb_transaction_id bigint NOT NULL,
    inputs jsonb,
    outputs jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    income jsonb
);


--
-- Name: type_scripts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.type_scripts (
    id bigint NOT NULL,
    args character varying,
    code_hash bytea,
    cell_output_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    hash_type character varying,
    script_hash character varying,
    script_id bigint
);


--
-- Name: type_scripts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.type_scripts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: type_scripts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.type_scripts_id_seq OWNED BY public.type_scripts.id;


--
-- Name: udt_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.udt_accounts (
    id bigint NOT NULL,
    udt_type integer,
    full_name character varying,
    symbol character varying,
    "decimal" integer,
    amount numeric(40,0) DEFAULT 0.0,
    published boolean DEFAULT false,
    code_hash bytea,
    type_hash character varying,
    address_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    udt_id bigint,
    nft_token_id character varying
);


--
-- Name: udt_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.udt_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: udt_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.udt_accounts_id_seq OWNED BY public.udt_accounts.id;


--
-- Name: udt_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.udt_transactions (
    udt_id bigint,
    ckb_transaction_id bigint
);


--
-- Name: udts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.udts (
    id bigint NOT NULL,
    code_hash bytea,
    hash_type character varying,
    args character varying,
    type_hash character varying,
    full_name character varying,
    symbol character varying,
    "decimal" integer,
    description character varying,
    icon_file character varying,
    operator_website character varying,
    addresses_count bigint DEFAULT 0.0,
    total_amount numeric(40,0) DEFAULT 0.0,
    udt_type integer,
    published boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    block_timestamp bigint,
    issuer_address bytea,
    ckb_transactions_count bigint DEFAULT 0.0,
    nrc_factory_cell_id bigint,
    display_name character varying,
    uan character varying,
    h24_ckb_transactions_count bigint DEFAULT 0
);


--
-- Name: udts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.udts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: udts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.udts_id_seq OWNED BY public.udts.id;


--
-- Name: uncle_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uncle_blocks (
    id bigint NOT NULL,
    block_hash bytea,
    number bigint,
    parent_hash bytea,
    "timestamp" bigint,
    transactions_root bytea,
    proposals_hash bytea,
    extra_hash bytea,
    version integer,
    proposals bytea,
    proposals_count integer,
    block_id bigint,
    epoch bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    dao character varying,
    nonce numeric(50,0) DEFAULT 0.0,
    compact_target numeric(20,0)
);


--
-- Name: uncle_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.uncle_blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: uncle_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.uncle_blocks_id_seq OWNED BY public.uncle_blocks.id;


--
-- Name: witnesses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.witnesses (
    id bigint NOT NULL,
    data bytea NOT NULL,
    ckb_transaction_id bigint NOT NULL,
    index integer NOT NULL
);


--
-- Name: witnesses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.witnesses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: witnesses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.witnesses_id_seq OWNED BY public.witnesses.id;


--
-- Name: ckb_transactions_committed; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions ATTACH PARTITION public.ckb_transactions_committed FOR VALUES IN (2);


--
-- Name: ckb_transactions_pending; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions ATTACH PARTITION public.ckb_transactions_pending FOR VALUES IN (0);


--
-- Name: ckb_transactions_proposed; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions ATTACH PARTITION public.ckb_transactions_proposed FOR VALUES IN (1);


--
-- Name: ckb_transactions_rejected; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions ATTACH PARTITION public.ckb_transactions_rejected FOR VALUES IN (3);


--
-- Name: account_books id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_books ALTER COLUMN id SET DEFAULT nextval('public.account_books_id_seq'::regclass);


--
-- Name: address_block_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_block_snapshots ALTER COLUMN id SET DEFAULT nextval('public.address_block_snapshots_id_seq'::regclass);


--
-- Name: addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses ALTER COLUMN id SET DEFAULT nextval('public.addresses_id_seq'::regclass);


--
-- Name: block_propagation_delays id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.block_propagation_delays ALTER COLUMN id SET DEFAULT nextval('public.block_propagation_delays_id_seq'::regclass);


--
-- Name: block_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.block_statistics ALTER COLUMN id SET DEFAULT nextval('public.block_statistics_id_seq'::regclass);


--
-- Name: block_time_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.block_time_statistics ALTER COLUMN id SET DEFAULT nextval('public.block_time_statistics_id_seq'::regclass);


--
-- Name: block_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.block_transactions ALTER COLUMN id SET DEFAULT nextval('public.block_transactions_id_seq'::regclass);


--
-- Name: blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks ALTER COLUMN id SET DEFAULT nextval('public.blocks_id_seq'::regclass);


--
-- Name: cell_data cell_output_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_data ALTER COLUMN cell_output_id SET DEFAULT nextval('public.cell_data_cell_output_id_seq'::regclass);


--
-- Name: cell_dependencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_dependencies ALTER COLUMN id SET DEFAULT nextval('public.cell_dependencies_id_seq'::regclass);


--
-- Name: cell_inputs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_inputs ALTER COLUMN id SET DEFAULT nextval('public.cell_inputs_id_seq'::regclass);


--
-- Name: cell_outputs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_outputs ALTER COLUMN id SET DEFAULT nextval('public.cell_outputs_id_seq'::regclass);


--
-- Name: ckb_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions ALTER COLUMN id SET DEFAULT nextval('public.ckb_transactions_id_seq'::regclass);


--
-- Name: contracts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts ALTER COLUMN id SET DEFAULT nextval('public.contracts_id_seq'::regclass);


--
-- Name: daily_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_statistics ALTER COLUMN id SET DEFAULT nextval('public.daily_statistics_id_seq'::regclass);


--
-- Name: dao_contracts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dao_contracts ALTER COLUMN id SET DEFAULT nextval('public.dao_contracts_id_seq'::regclass);


--
-- Name: dao_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dao_events ALTER COLUMN id SET DEFAULT nextval('public.dao_events_id_seq'::regclass);


--
-- Name: deployed_cells id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deployed_cells ALTER COLUMN id SET DEFAULT nextval('public.deployed_cells_id_seq'::regclass);


--
-- Name: epoch_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_statistics ALTER COLUMN id SET DEFAULT nextval('public.epoch_statistics_id_seq'::regclass);


--
-- Name: forked_blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forked_blocks ALTER COLUMN id SET DEFAULT nextval('public.forked_blocks_id_seq'::regclass);


--
-- Name: forked_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forked_events ALTER COLUMN id SET DEFAULT nextval('public.forked_events_id_seq'::regclass);


--
-- Name: global_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.global_statistics ALTER COLUMN id SET DEFAULT nextval('public.global_statistics_id_seq'::regclass);


--
-- Name: header_dependencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.header_dependencies ALTER COLUMN id SET DEFAULT nextval('public.header_dependencies_id_seq'::regclass);


--
-- Name: lock_scripts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lock_scripts ALTER COLUMN id SET DEFAULT nextval('public.lock_scripts_id_seq'::regclass);


--
-- Name: mining_infos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mining_infos ALTER COLUMN id SET DEFAULT nextval('public.mining_infos_id_seq'::regclass);


--
-- Name: nrc_factory_cells id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nrc_factory_cells ALTER COLUMN id SET DEFAULT nextval('public.nrc_factory_cells_id_seq'::regclass);


--
-- Name: old_ckb_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.old_ckb_transactions ALTER COLUMN id SET DEFAULT nextval('public.old_ckb_transactions_id_seq'::regclass);


--
-- Name: pool_transaction_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_transaction_entries ALTER COLUMN id SET DEFAULT nextval('public.pool_transaction_entries_id_seq'::regclass);


--
-- Name: referring_cells id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referring_cells ALTER COLUMN id SET DEFAULT nextval('public.referring_cells_id_seq'::regclass);


--
-- Name: reject_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reject_reasons ALTER COLUMN id SET DEFAULT nextval('public.reject_reasons_id_seq'::regclass);


--
-- Name: script_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.script_transactions ALTER COLUMN id SET DEFAULT nextval('public.script_transactions_id_seq'::regclass);


--
-- Name: scripts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scripts ALTER COLUMN id SET DEFAULT nextval('public.scripts_id_seq'::regclass);


--
-- Name: statistic_infos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statistic_infos ALTER COLUMN id SET DEFAULT nextval('public.statistic_infos_id_seq'::regclass);


--
-- Name: table_record_counts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_record_counts ALTER COLUMN id SET DEFAULT nextval('public.table_record_counts_id_seq'::regclass);


--
-- Name: token_collections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_collections ALTER COLUMN id SET DEFAULT nextval('public.token_collections_id_seq'::regclass);


--
-- Name: token_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_items ALTER COLUMN id SET DEFAULT nextval('public.token_items_id_seq'::regclass);


--
-- Name: token_transfers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_transfers ALTER COLUMN id SET DEFAULT nextval('public.token_transfers_id_seq'::regclass);


--
-- Name: transaction_address_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_address_changes ALTER COLUMN id SET DEFAULT nextval('public.transaction_address_changes_id_seq'::regclass);


--
-- Name: transaction_propagation_delays id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_propagation_delays ALTER COLUMN id SET DEFAULT nextval('public.transaction_propagation_delays_id_seq'::regclass);


--
-- Name: type_scripts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.type_scripts ALTER COLUMN id SET DEFAULT nextval('public.type_scripts_id_seq'::regclass);


--
-- Name: udt_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udt_accounts ALTER COLUMN id SET DEFAULT nextval('public.udt_accounts_id_seq'::regclass);


--
-- Name: udts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udts ALTER COLUMN id SET DEFAULT nextval('public.udts_id_seq'::regclass);


--
-- Name: uncle_blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uncle_blocks ALTER COLUMN id SET DEFAULT nextval('public.uncle_blocks_id_seq'::regclass);


--
-- Name: witnesses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.witnesses ALTER COLUMN id SET DEFAULT nextval('public.witnesses_id_seq'::regclass);


--
-- Name: account_books account_books_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_books
    ADD CONSTRAINT account_books_pkey PRIMARY KEY (id);


--
-- Name: address_block_snapshots address_block_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_block_snapshots
    ADD CONSTRAINT address_block_snapshots_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: block_propagation_delays block_propagation_delays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.block_propagation_delays
    ADD CONSTRAINT block_propagation_delays_pkey PRIMARY KEY (id);


--
-- Name: block_statistics block_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.block_statistics
    ADD CONSTRAINT block_statistics_pkey PRIMARY KEY (id);


--
-- Name: block_time_statistics block_time_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.block_time_statistics
    ADD CONSTRAINT block_time_statistics_pkey PRIMARY KEY (id);


--
-- Name: block_transactions block_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.block_transactions
    ADD CONSTRAINT block_transactions_pkey PRIMARY KEY (id);


--
-- Name: blocks blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (id);


--
-- Name: cell_data cell_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_data
    ADD CONSTRAINT cell_data_pkey PRIMARY KEY (cell_output_id);


--
-- Name: cell_dependencies cell_dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_dependencies
    ADD CONSTRAINT cell_dependencies_pkey PRIMARY KEY (id);


--
-- Name: cell_inputs cell_inputs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_inputs
    ADD CONSTRAINT cell_inputs_pkey PRIMARY KEY (id);


--
-- Name: cell_outputs cell_outputs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_outputs
    ADD CONSTRAINT cell_outputs_pkey PRIMARY KEY (id);


--
-- Name: ckb_transactions ckb_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions
    ADD CONSTRAINT ckb_transactions_pkey PRIMARY KEY (id, tx_status);


--
-- Name: ckb_transactions_committed ckb_transactions_committed_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions_committed
    ADD CONSTRAINT ckb_transactions_committed_pkey PRIMARY KEY (id, tx_status);


--
-- Name: ckb_transactions ckb_tx_uni_tx_hash; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions
    ADD CONSTRAINT ckb_tx_uni_tx_hash UNIQUE (tx_status, tx_hash);


--
-- Name: ckb_transactions_committed ckb_transactions_committed_tx_status_tx_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions_committed
    ADD CONSTRAINT ckb_transactions_committed_tx_status_tx_hash_key UNIQUE (tx_status, tx_hash);


--
-- Name: ckb_transactions_pending ckb_transactions_pending_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions_pending
    ADD CONSTRAINT ckb_transactions_pending_pkey PRIMARY KEY (id, tx_status);


--
-- Name: ckb_transactions_pending ckb_transactions_pending_tx_status_tx_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions_pending
    ADD CONSTRAINT ckb_transactions_pending_tx_status_tx_hash_key UNIQUE (tx_status, tx_hash);


--
-- Name: ckb_transactions_proposed ckb_transactions_proposed_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions_proposed
    ADD CONSTRAINT ckb_transactions_proposed_pkey PRIMARY KEY (id, tx_status);


--
-- Name: ckb_transactions_proposed ckb_transactions_proposed_tx_status_tx_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions_proposed
    ADD CONSTRAINT ckb_transactions_proposed_tx_status_tx_hash_key UNIQUE (tx_status, tx_hash);


--
-- Name: ckb_transactions_rejected ckb_transactions_rejected_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions_rejected
    ADD CONSTRAINT ckb_transactions_rejected_pkey PRIMARY KEY (id, tx_status);


--
-- Name: ckb_transactions_rejected ckb_transactions_rejected_tx_status_tx_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ckb_transactions_rejected
    ADD CONSTRAINT ckb_transactions_rejected_tx_status_tx_hash_key UNIQUE (tx_status, tx_hash);


--
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (id);


--
-- Name: daily_statistics daily_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_statistics
    ADD CONSTRAINT daily_statistics_pkey PRIMARY KEY (id);


--
-- Name: dao_contracts dao_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dao_contracts
    ADD CONSTRAINT dao_contracts_pkey PRIMARY KEY (id);


--
-- Name: dao_events dao_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dao_events
    ADD CONSTRAINT dao_events_pkey PRIMARY KEY (id);


--
-- Name: deployed_cells deployed_cells_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deployed_cells
    ADD CONSTRAINT deployed_cells_pkey PRIMARY KEY (id);


--
-- Name: epoch_statistics epoch_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_statistics
    ADD CONSTRAINT epoch_statistics_pkey PRIMARY KEY (id);


--
-- Name: forked_blocks forked_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forked_blocks
    ADD CONSTRAINT forked_blocks_pkey PRIMARY KEY (id);


--
-- Name: forked_events forked_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forked_events
    ADD CONSTRAINT forked_events_pkey PRIMARY KEY (id);


--
-- Name: global_statistics global_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.global_statistics
    ADD CONSTRAINT global_statistics_pkey PRIMARY KEY (id);


--
-- Name: header_dependencies header_dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.header_dependencies
    ADD CONSTRAINT header_dependencies_pkey PRIMARY KEY (id);


--
-- Name: lock_scripts lock_scripts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lock_scripts
    ADD CONSTRAINT lock_scripts_pkey PRIMARY KEY (id);


--
-- Name: mining_infos mining_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mining_infos
    ADD CONSTRAINT mining_infos_pkey PRIMARY KEY (id);


--
-- Name: nrc_factory_cells nrc_factory_cells_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nrc_factory_cells
    ADD CONSTRAINT nrc_factory_cells_pkey PRIMARY KEY (id);


--
-- Name: old_ckb_transactions old_ckb_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.old_ckb_transactions
    ADD CONSTRAINT old_ckb_transactions_pkey PRIMARY KEY (id);


--
-- Name: pool_transaction_entries pool_transaction_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_transaction_entries
    ADD CONSTRAINT pool_transaction_entries_pkey PRIMARY KEY (id);


--
-- Name: referring_cells referring_cells_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referring_cells
    ADD CONSTRAINT referring_cells_pkey PRIMARY KEY (id);


--
-- Name: reject_reasons reject_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reject_reasons
    ADD CONSTRAINT reject_reasons_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: script_transactions script_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.script_transactions
    ADD CONSTRAINT script_transactions_pkey PRIMARY KEY (id);


--
-- Name: scripts scripts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scripts
    ADD CONSTRAINT scripts_pkey PRIMARY KEY (id);


--
-- Name: statistic_infos statistic_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statistic_infos
    ADD CONSTRAINT statistic_infos_pkey PRIMARY KEY (id);


--
-- Name: table_record_counts table_record_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_record_counts
    ADD CONSTRAINT table_record_counts_pkey PRIMARY KEY (id);


--
-- Name: token_collections token_collections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_collections
    ADD CONSTRAINT token_collections_pkey PRIMARY KEY (id);


--
-- Name: token_items token_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_items
    ADD CONSTRAINT token_items_pkey PRIMARY KEY (id);


--
-- Name: token_transfers token_transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_transfers
    ADD CONSTRAINT token_transfers_pkey PRIMARY KEY (id);


--
-- Name: transaction_address_changes transaction_address_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_address_changes
    ADD CONSTRAINT transaction_address_changes_pkey PRIMARY KEY (id);


--
-- Name: transaction_propagation_delays transaction_propagation_delays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_propagation_delays
    ADD CONSTRAINT transaction_propagation_delays_pkey PRIMARY KEY (id);


--
-- Name: tx_display_infos tx_display_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tx_display_infos
    ADD CONSTRAINT tx_display_infos_pkey PRIMARY KEY (ckb_transaction_id);


--
-- Name: type_scripts type_scripts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.type_scripts
    ADD CONSTRAINT type_scripts_pkey PRIMARY KEY (id);


--
-- Name: udt_accounts udt_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udt_accounts
    ADD CONSTRAINT udt_accounts_pkey PRIMARY KEY (id);


--
-- Name: udts udts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udts
    ADD CONSTRAINT udts_pkey PRIMARY KEY (id);


--
-- Name: uncle_blocks uncle_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uncle_blocks
    ADD CONSTRAINT uncle_blocks_pkey PRIMARY KEY (id);


--
-- Name: addresses unique_lock_hash; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT unique_lock_hash UNIQUE (lock_hash);


--
-- Name: token_collections unique_sn; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_collections
    ADD CONSTRAINT unique_sn UNIQUE (sn);


--
-- Name: pool_transaction_entries unique_tx_hash; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_transaction_entries
    ADD CONSTRAINT unique_tx_hash UNIQUE (tx_hash);


--
-- Name: udts unique_type_hash; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udts
    ADD CONSTRAINT unique_type_hash UNIQUE (type_hash);


--
-- Name: witnesses witnesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.witnesses
    ADD CONSTRAINT witnesses_pkey PRIMARY KEY (id);


--
-- Name: address_dao_tx_alt_pk; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX address_dao_tx_alt_pk ON public.address_dao_transactions USING btree (address_id, ckb_transaction_id);


--
-- Name: address_udt_tx_alt_pk; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX address_udt_tx_alt_pk ON public.address_udt_transactions USING btree (address_id, ckb_transaction_id);


--
-- Name: block_tx_alt_pk; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX block_tx_alt_pk ON public.block_transactions USING btree (block_id, ckb_transaction_id);


--
-- Name: block_tx_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX block_tx_index ON public.block_transactions USING btree (block_id, tx_index);


--
-- Name: cell_deps_tx_cell_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cell_deps_tx_cell_idx ON public.cell_dependencies USING btree (ckb_transaction_id, contract_cell_id);


--
-- Name: idx_ckb_txs_for_blocks; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ckb_txs_for_blocks ON ONLY public.ckb_transactions USING btree (block_id, block_timestamp);


--
-- Name: ckb_transactions_committed_block_id_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_committed_block_id_block_timestamp_idx ON public.ckb_transactions_committed USING btree (block_id, block_timestamp);


--
-- Name: idx_ckb_txs_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ckb_txs_timestamp ON ONLY public.ckb_transactions USING btree (block_timestamp DESC NULLS LAST, id);


--
-- Name: ckb_transactions_committed_block_timestamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_committed_block_timestamp_id_idx ON public.ckb_transactions_committed USING btree (block_timestamp DESC NULLS LAST, id);


--
-- Name: index_ckb_transactions_on_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ckb_transactions_on_tags ON ONLY public.ckb_transactions USING gin (tags);


--
-- Name: ckb_transactions_committed_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_committed_tags_idx ON public.ckb_transactions_committed USING gin (tags);


--
-- Name: index_ckb_transactions_on_tx_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ckb_transactions_on_tx_hash ON ONLY public.ckb_transactions USING hash (tx_hash);


--
-- Name: ckb_transactions_committed_tx_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_committed_tx_hash_idx ON public.ckb_transactions_committed USING hash (tx_hash);


--
-- Name: ckb_transactions_pending_block_id_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_pending_block_id_block_timestamp_idx ON public.ckb_transactions_pending USING btree (block_id, block_timestamp);


--
-- Name: ckb_transactions_pending_block_timestamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_pending_block_timestamp_id_idx ON public.ckb_transactions_pending USING btree (block_timestamp DESC NULLS LAST, id);


--
-- Name: ckb_transactions_pending_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_pending_tags_idx ON public.ckb_transactions_pending USING gin (tags);


--
-- Name: ckb_transactions_pending_tx_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_pending_tx_hash_idx ON public.ckb_transactions_pending USING hash (tx_hash);


--
-- Name: ckb_transactions_proposed_block_id_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_proposed_block_id_block_timestamp_idx ON public.ckb_transactions_proposed USING btree (block_id, block_timestamp);


--
-- Name: ckb_transactions_proposed_block_timestamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_proposed_block_timestamp_id_idx ON public.ckb_transactions_proposed USING btree (block_timestamp DESC NULLS LAST, id);


--
-- Name: ckb_transactions_proposed_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_proposed_tags_idx ON public.ckb_transactions_proposed USING gin (tags);


--
-- Name: ckb_transactions_proposed_tx_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_proposed_tx_hash_idx ON public.ckb_transactions_proposed USING hash (tx_hash);


--
-- Name: ckb_transactions_rejected_block_id_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_rejected_block_id_block_timestamp_idx ON public.ckb_transactions_rejected USING btree (block_id, block_timestamp);


--
-- Name: ckb_transactions_rejected_block_timestamp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_rejected_block_timestamp_id_idx ON public.ckb_transactions_rejected USING btree (block_timestamp DESC NULLS LAST, id);


--
-- Name: ckb_transactions_rejected_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_rejected_tags_idx ON public.ckb_transactions_rejected USING gin (tags);


--
-- Name: ckb_transactions_rejected_tx_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_rejected_tx_hash_idx ON public.ckb_transactions_rejected USING hash (tx_hash);


--
-- Name: index_account_books_on_address_id_and_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_account_books_on_address_id_and_ckb_transaction_id ON public.account_books USING btree (address_id, ckb_transaction_id);


--
-- Name: index_account_books_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_books_on_ckb_transaction_id ON public.account_books USING btree (ckb_transaction_id);


--
-- Name: index_address_block_snapshots_on_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_address_block_snapshots_on_address_id ON public.address_block_snapshots USING btree (address_id);


--
-- Name: index_address_block_snapshots_on_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_address_block_snapshots_on_block_id ON public.address_block_snapshots USING btree (block_id);


--
-- Name: index_address_block_snapshots_on_block_id_and_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_address_block_snapshots_on_block_id_and_address_id ON public.address_block_snapshots USING btree (block_id, address_id);


--
-- Name: index_address_dao_transactions_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_address_dao_transactions_on_ckb_transaction_id ON public.address_dao_transactions USING btree (ckb_transaction_id);


--
-- Name: index_address_udt_transactions_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_address_udt_transactions_on_ckb_transaction_id ON public.address_udt_transactions USING btree (ckb_transaction_id);


--
-- Name: index_addresses_on_address_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_addresses_on_address_hash ON public.addresses USING hash (address_hash);


--
-- Name: index_addresses_on_is_depositor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_addresses_on_is_depositor ON public.addresses USING btree (is_depositor) WHERE (is_depositor = true);


--
-- Name: index_addresses_on_lock_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_addresses_on_lock_hash ON public.addresses USING hash (lock_hash);


--
-- Name: index_average_block_time_by_hour_on_hour; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_average_block_time_by_hour_on_hour ON public.average_block_time_by_hour USING btree (hour);


--
-- Name: index_block_propagation_delays_on_created_at_unixtimestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_block_propagation_delays_on_created_at_unixtimestamp ON public.block_propagation_delays USING btree (created_at_unixtimestamp);


--
-- Name: index_block_statistics_on_block_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_block_statistics_on_block_number ON public.block_statistics USING btree (block_number);


--
-- Name: index_block_time_statistics_on_stat_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_block_time_statistics_on_stat_timestamp ON public.block_time_statistics USING btree (stat_timestamp);


--
-- Name: index_block_transactions_on_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_block_transactions_on_block_id ON public.block_transactions USING btree (block_id);


--
-- Name: index_block_transactions_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_block_transactions_on_ckb_transaction_id ON public.block_transactions USING btree (ckb_transaction_id);


--
-- Name: index_blocks_on_block_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blocks_on_block_hash ON public.blocks USING hash (block_hash);


--
-- Name: index_blocks_on_block_size; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blocks_on_block_size ON public.blocks USING btree (block_size);


--
-- Name: index_blocks_on_block_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blocks_on_block_time ON public.blocks USING btree (block_time);


--
-- Name: index_blocks_on_epoch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blocks_on_epoch ON public.blocks USING btree (epoch);


--
-- Name: index_blocks_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blocks_on_number ON public.blocks USING btree (number);


--
-- Name: index_blocks_on_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blocks_on_timestamp ON public.blocks USING btree ("timestamp" DESC NULLS LAST);


--
-- Name: index_cell_dependencies_on_contract_cell_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_dependencies_on_contract_cell_id ON public.cell_dependencies USING btree (contract_cell_id);


--
-- Name: index_cell_dependencies_on_contract_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_dependencies_on_contract_id ON public.cell_dependencies USING btree (contract_id);


--
-- Name: index_cell_dependencies_on_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_dependencies_on_script_id ON public.cell_dependencies USING btree (script_id);


--
-- Name: index_cell_inputs_on_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_inputs_on_block_id ON public.cell_inputs USING btree (block_id);


--
-- Name: index_cell_inputs_on_ckb_transaction_id_and_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cell_inputs_on_ckb_transaction_id_and_index ON public.cell_inputs USING btree (ckb_transaction_id, index);


--
-- Name: index_cell_inputs_on_previous_cell_output_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_inputs_on_previous_cell_output_id ON public.cell_inputs USING btree (previous_cell_output_id);


--
-- Name: index_cell_inputs_on_previous_tx_hash_and_previous_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_inputs_on_previous_tx_hash_and_previous_index ON public.cell_inputs USING btree (previous_tx_hash, previous_index);


--
-- Name: index_cell_outputs_on_address_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_address_id_and_status ON public.cell_outputs USING btree (address_id, status);


--
-- Name: index_cell_outputs_on_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_block_id ON public.cell_outputs USING btree (block_id);


--
-- Name: index_cell_outputs_on_block_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_block_timestamp ON public.cell_outputs USING btree (block_timestamp);


--
-- Name: index_cell_outputs_on_cell_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_cell_type ON public.cell_outputs USING btree (cell_type);


--
-- Name: index_cell_outputs_on_ckb_transaction_id_and_cell_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cell_outputs_on_ckb_transaction_id_and_cell_index ON public.cell_outputs USING btree (ckb_transaction_id, cell_index);


--
-- Name: index_cell_outputs_on_consumed_block_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_consumed_block_timestamp ON public.cell_outputs USING btree (consumed_block_timestamp);


--
-- Name: index_cell_outputs_on_consumed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_consumed_by_id ON public.cell_outputs USING btree (consumed_by_id);


--
-- Name: index_cell_outputs_on_data_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_data_hash ON public.cell_outputs USING hash (data_hash);


--
-- Name: index_cell_outputs_on_lock_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_lock_script_id ON public.cell_outputs USING btree (lock_script_id);


--
-- Name: index_cell_outputs_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_status ON public.cell_outputs USING btree (status);


--
-- Name: index_cell_outputs_on_tx_hash_and_cell_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cell_outputs_on_tx_hash_and_cell_index ON public.cell_outputs USING btree (tx_hash, cell_index);


--
-- Name: index_cell_outputs_on_type_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_type_script_id ON public.cell_outputs USING btree (type_script_id);


--
-- Name: index_cell_outputs_on_type_script_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_type_script_id_and_id ON public.cell_outputs USING btree (type_script_id, id);


--
-- Name: index_contracts_on_code_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contracts_on_code_hash ON public.contracts USING btree (code_hash);


--
-- Name: index_contracts_on_deprecated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contracts_on_deprecated ON public.contracts USING btree (deprecated);


--
-- Name: index_contracts_on_hash_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contracts_on_hash_type ON public.contracts USING btree (hash_type);


--
-- Name: index_contracts_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contracts_on_name ON public.contracts USING btree (name);


--
-- Name: index_contracts_on_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contracts_on_role ON public.contracts USING btree (role);


--
-- Name: index_contracts_on_symbol; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contracts_on_symbol ON public.contracts USING btree (symbol);


--
-- Name: index_contracts_on_verified; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contracts_on_verified ON public.contracts USING btree (verified);


--
-- Name: index_daily_statistics_on_created_at_unixtimestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_daily_statistics_on_created_at_unixtimestamp ON public.daily_statistics USING btree (created_at_unixtimestamp);


--
-- Name: index_dao_events_on_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dao_events_on_block_id ON public.dao_events USING btree (block_id);


--
-- Name: index_dao_events_on_block_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dao_events_on_block_timestamp ON public.dao_events USING btree (block_timestamp);


--
-- Name: index_dao_events_on_status_and_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dao_events_on_status_and_event_type ON public.dao_events USING btree (status, event_type);


--
-- Name: index_deployed_cells_on_cell_output_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deployed_cells_on_cell_output_id ON public.deployed_cells USING btree (cell_output_id);


--
-- Name: index_deployed_cells_on_contract_id_and_cell_output_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deployed_cells_on_contract_id_and_cell_output_id ON public.deployed_cells USING btree (contract_id, cell_output_id);


--
-- Name: index_epoch_statistics_on_epoch_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_epoch_statistics_on_epoch_number ON public.epoch_statistics USING btree (epoch_number);


--
-- Name: index_forked_events_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forked_events_on_status ON public.forked_events USING btree (status);


--
-- Name: index_global_statistics_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_global_statistics_on_name ON public.global_statistics USING btree (name);


--
-- Name: index_header_dependencies_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_header_dependencies_on_ckb_transaction_id ON public.header_dependencies USING btree (ckb_transaction_id);


--
-- Name: index_header_dependencies_on_ckb_transaction_id_and_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_header_dependencies_on_ckb_transaction_id_and_index ON public.header_dependencies USING btree (ckb_transaction_id, index);


--
-- Name: index_lock_scripts_on_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lock_scripts_on_address_id ON public.lock_scripts USING btree (address_id);


--
-- Name: index_lock_scripts_on_cell_output_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lock_scripts_on_cell_output_id ON public.lock_scripts USING btree (cell_output_id);


--
-- Name: index_lock_scripts_on_code_hash_and_hash_type_and_args; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lock_scripts_on_code_hash_and_hash_type_and_args ON public.lock_scripts USING btree (code_hash, hash_type, args);


--
-- Name: index_lock_scripts_on_script_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lock_scripts_on_script_hash ON public.lock_scripts USING hash (script_hash);


--
-- Name: index_lock_scripts_on_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lock_scripts_on_script_id ON public.lock_scripts USING btree (script_id);


--
-- Name: index_mining_infos_on_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mining_infos_on_block_id ON public.mining_infos USING btree (block_id);


--
-- Name: index_mining_infos_on_block_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mining_infos_on_block_number ON public.mining_infos USING btree (block_number);


--
-- Name: index_nrc_factory_cells_on_code_hash_and_hash_type_and_args; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_nrc_factory_cells_on_code_hash_and_hash_type_and_args ON public.nrc_factory_cells USING btree (code_hash, hash_type, args);


--
-- Name: index_old_ckb_transactions_on_block_id_and_block_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_old_ckb_transactions_on_block_id_and_block_timestamp ON public.old_ckb_transactions USING btree (block_id, block_timestamp);


--
-- Name: index_old_ckb_transactions_on_block_timestamp_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_old_ckb_transactions_on_block_timestamp_and_id ON public.old_ckb_transactions USING btree (block_timestamp DESC NULLS LAST, id DESC);


--
-- Name: index_old_ckb_transactions_on_contained_address_ids_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_old_ckb_transactions_on_contained_address_ids_and_id ON public.old_ckb_transactions USING gin (contained_address_ids, id);


--
-- Name: index_old_ckb_transactions_on_contained_udt_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_old_ckb_transactions_on_contained_udt_ids ON public.old_ckb_transactions USING gin (contained_udt_ids);


--
-- Name: index_old_ckb_transactions_on_dao_address_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_old_ckb_transactions_on_dao_address_ids ON public.old_ckb_transactions USING gin (dao_address_ids);


--
-- Name: index_old_ckb_transactions_on_is_cellbase; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_old_ckb_transactions_on_is_cellbase ON public.old_ckb_transactions USING btree (is_cellbase);


--
-- Name: index_old_ckb_transactions_on_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_old_ckb_transactions_on_tags ON public.old_ckb_transactions USING gin (tags);


--
-- Name: index_old_ckb_transactions_on_tx_hash_and_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_old_ckb_transactions_on_tx_hash_and_block_id ON public.old_ckb_transactions USING btree (tx_hash, block_id);


--
-- Name: index_old_ckb_transactions_on_udt_address_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_old_ckb_transactions_on_udt_address_ids ON public.old_ckb_transactions USING gin (udt_address_ids);


--
-- Name: index_pool_transaction_entries_on_id_and_tx_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pool_transaction_entries_on_id_and_tx_status ON public.pool_transaction_entries USING btree (id, tx_status);


--
-- Name: index_pool_transaction_entries_on_tx_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pool_transaction_entries_on_tx_hash ON public.pool_transaction_entries USING hash (tx_hash);


--
-- Name: index_pool_transaction_entries_on_tx_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pool_transaction_entries_on_tx_status ON public.pool_transaction_entries USING btree (tx_status);


--
-- Name: index_reject_reasons_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reject_reasons_on_ckb_transaction_id ON public.reject_reasons USING btree (ckb_transaction_id);


--
-- Name: index_rolling_avg_block_time_on_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rolling_avg_block_time_on_timestamp ON public.rolling_avg_block_time USING btree ("timestamp");


--
-- Name: index_script_transactions_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_script_transactions_on_ckb_transaction_id ON public.script_transactions USING btree (ckb_transaction_id);


--
-- Name: index_script_transactions_on_ckb_transaction_id_and_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_script_transactions_on_ckb_transaction_id_and_script_id ON public.script_transactions USING btree (ckb_transaction_id, script_id);


--
-- Name: index_script_transactions_on_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_script_transactions_on_script_id ON public.script_transactions USING btree (script_id);


--
-- Name: index_scripts_on_contract_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scripts_on_contract_id ON public.scripts USING btree (contract_id);


--
-- Name: index_table_record_counts_on_table_name_and_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_table_record_counts_on_table_name_and_count ON public.table_record_counts USING btree (table_name, count);


--
-- Name: index_token_collections_on_cell_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_token_collections_on_cell_id ON public.token_collections USING btree (cell_id);


--
-- Name: index_token_collections_on_sn; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_token_collections_on_sn ON public.token_collections USING hash (sn);


--
-- Name: index_token_collections_on_type_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_token_collections_on_type_script_id ON public.token_collections USING btree (type_script_id);


--
-- Name: index_token_items_on_cell_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_token_items_on_cell_id ON public.token_items USING btree (cell_id);


--
-- Name: index_token_items_on_collection_id_and_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_token_items_on_collection_id_and_token_id ON public.token_items USING btree (collection_id, token_id);


--
-- Name: index_token_items_on_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_token_items_on_owner_id ON public.token_items USING btree (owner_id);


--
-- Name: index_token_items_on_type_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_token_items_on_type_script_id ON public.token_items USING btree (type_script_id);


--
-- Name: index_token_transfers_on_from_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_token_transfers_on_from_id ON public.token_transfers USING btree (from_id);


--
-- Name: index_token_transfers_on_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_token_transfers_on_item_id ON public.token_transfers USING btree (item_id);


--
-- Name: index_token_transfers_on_to_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_token_transfers_on_to_id ON public.token_transfers USING btree (to_id);


--
-- Name: index_token_transfers_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_token_transfers_on_transaction_id ON public.token_transfers USING btree (transaction_id);


--
-- Name: index_transaction_address_changes_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_address_changes_on_ckb_transaction_id ON public.transaction_address_changes USING btree (ckb_transaction_id);


--
-- Name: index_tx_propagation_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tx_propagation_timestamp ON public.transaction_propagation_delays USING btree (created_at_unixtimestamp);


--
-- Name: index_type_scripts_on_cell_output_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_type_scripts_on_cell_output_id ON public.type_scripts USING btree (cell_output_id);


--
-- Name: index_type_scripts_on_code_hash_and_hash_type_and_args; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_type_scripts_on_code_hash_and_hash_type_and_args ON public.type_scripts USING btree (code_hash, hash_type, args);


--
-- Name: index_type_scripts_on_script_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_type_scripts_on_script_hash ON public.type_scripts USING hash (script_hash);


--
-- Name: index_type_scripts_on_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_type_scripts_on_script_id ON public.type_scripts USING btree (script_id);


--
-- Name: index_udt_accounts_on_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_udt_accounts_on_address_id ON public.udt_accounts USING btree (address_id);


--
-- Name: index_udt_accounts_on_type_hash_and_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_udt_accounts_on_type_hash_and_address_id ON public.udt_accounts USING btree (type_hash, address_id);


--
-- Name: index_udt_accounts_on_udt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_udt_accounts_on_udt_id ON public.udt_accounts USING btree (udt_id);


--
-- Name: index_udt_transactions_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_udt_transactions_on_ckb_transaction_id ON public.udt_transactions USING btree (ckb_transaction_id);


--
-- Name: index_udt_transactions_on_udt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_udt_transactions_on_udt_id ON public.udt_transactions USING btree (udt_id);


--
-- Name: index_udts_on_type_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_udts_on_type_hash ON public.udts USING hash (type_hash);


--
-- Name: index_uncle_blocks_on_block_hash_and_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_uncle_blocks_on_block_hash_and_block_id ON public.uncle_blocks USING btree (block_hash, block_id);


--
-- Name: index_uncle_blocks_on_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uncle_blocks_on_block_id ON public.uncle_blocks USING btree (block_id);


--
-- Name: index_witnesses_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_witnesses_on_ckb_transaction_id ON public.witnesses USING btree (ckb_transaction_id);


--
-- Name: index_witnesses_on_ckb_transaction_id_and_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_witnesses_on_ckb_transaction_id_and_index ON public.witnesses USING btree (ckb_transaction_id, index);


--
-- Name: pk; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pk ON public.udt_transactions USING btree (udt_id, ckb_transaction_id);


--
-- Name: tx_address_changes_alt_pk; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tx_address_changes_alt_pk ON public.transaction_address_changes USING btree (address_id, ckb_transaction_id);


--
-- Name: ckb_transactions_committed_block_id_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ckb_txs_for_blocks ATTACH PARTITION public.ckb_transactions_committed_block_id_block_timestamp_idx;


--
-- Name: ckb_transactions_committed_block_timestamp_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ckb_txs_timestamp ATTACH PARTITION public.ckb_transactions_committed_block_timestamp_id_idx;


--
-- Name: ckb_transactions_committed_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ckb_transactions_pkey ATTACH PARTITION public.ckb_transactions_committed_pkey;


--
-- Name: ckb_transactions_committed_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_tags ATTACH PARTITION public.ckb_transactions_committed_tags_idx;


--
-- Name: ckb_transactions_committed_tx_hash_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_tx_hash ATTACH PARTITION public.ckb_transactions_committed_tx_hash_idx;


--
-- Name: ckb_transactions_committed_tx_status_tx_hash_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ckb_tx_uni_tx_hash ATTACH PARTITION public.ckb_transactions_committed_tx_status_tx_hash_key;


--
-- Name: ckb_transactions_pending_block_id_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ckb_txs_for_blocks ATTACH PARTITION public.ckb_transactions_pending_block_id_block_timestamp_idx;


--
-- Name: ckb_transactions_pending_block_timestamp_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ckb_txs_timestamp ATTACH PARTITION public.ckb_transactions_pending_block_timestamp_id_idx;


--
-- Name: ckb_transactions_pending_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ckb_transactions_pkey ATTACH PARTITION public.ckb_transactions_pending_pkey;


--
-- Name: ckb_transactions_pending_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_tags ATTACH PARTITION public.ckb_transactions_pending_tags_idx;


--
-- Name: ckb_transactions_pending_tx_hash_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_tx_hash ATTACH PARTITION public.ckb_transactions_pending_tx_hash_idx;


--
-- Name: ckb_transactions_pending_tx_status_tx_hash_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ckb_tx_uni_tx_hash ATTACH PARTITION public.ckb_transactions_pending_tx_status_tx_hash_key;


--
-- Name: ckb_transactions_proposed_block_id_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ckb_txs_for_blocks ATTACH PARTITION public.ckb_transactions_proposed_block_id_block_timestamp_idx;


--
-- Name: ckb_transactions_proposed_block_timestamp_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ckb_txs_timestamp ATTACH PARTITION public.ckb_transactions_proposed_block_timestamp_id_idx;


--
-- Name: ckb_transactions_proposed_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ckb_transactions_pkey ATTACH PARTITION public.ckb_transactions_proposed_pkey;


--
-- Name: ckb_transactions_proposed_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_tags ATTACH PARTITION public.ckb_transactions_proposed_tags_idx;


--
-- Name: ckb_transactions_proposed_tx_hash_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_tx_hash ATTACH PARTITION public.ckb_transactions_proposed_tx_hash_idx;


--
-- Name: ckb_transactions_proposed_tx_status_tx_hash_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ckb_tx_uni_tx_hash ATTACH PARTITION public.ckb_transactions_proposed_tx_status_tx_hash_key;


--
-- Name: ckb_transactions_rejected_block_id_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ckb_txs_for_blocks ATTACH PARTITION public.ckb_transactions_rejected_block_id_block_timestamp_idx;


--
-- Name: ckb_transactions_rejected_block_timestamp_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ckb_txs_timestamp ATTACH PARTITION public.ckb_transactions_rejected_block_timestamp_id_idx;


--
-- Name: ckb_transactions_rejected_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ckb_transactions_pkey ATTACH PARTITION public.ckb_transactions_rejected_pkey;


--
-- Name: ckb_transactions_rejected_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_tags ATTACH PARTITION public.ckb_transactions_rejected_tags_idx;


--
-- Name: ckb_transactions_rejected_tx_hash_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_tx_hash ATTACH PARTITION public.ckb_transactions_rejected_tx_hash_idx;


--
-- Name: ckb_transactions_rejected_tx_status_tx_hash_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ckb_tx_uni_tx_hash ATTACH PARTITION public.ckb_transactions_rejected_tx_status_tx_hash_key;


--
-- Name: ckb_transactions after_delete_update_ckb_transactions_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER after_delete_update_ckb_transactions_count AFTER DELETE ON public.ckb_transactions FOR EACH ROW EXECUTE FUNCTION public.decrease_ckb_transactions_count();


--
-- Name: old_ckb_transactions after_delete_update_ckb_transactions_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER after_delete_update_ckb_transactions_count AFTER DELETE ON public.old_ckb_transactions FOR EACH ROW EXECUTE FUNCTION public.decrease_ckb_transactions_count();


--
-- Name: ckb_transactions after_insert_update_ckb_transactions_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER after_insert_update_ckb_transactions_count AFTER INSERT ON public.ckb_transactions FOR EACH ROW EXECUTE FUNCTION public.increase_ckb_transactions_count();


--
-- Name: old_ckb_transactions after_insert_update_ckb_transactions_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER after_insert_update_ckb_transactions_count AFTER INSERT ON public.old_ckb_transactions FOR EACH ROW EXECUTE FUNCTION public.increase_ckb_transactions_count();


--
-- Name: ckb_transactions after_update_ckb_transactions_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER after_update_ckb_transactions_count AFTER UPDATE ON public.ckb_transactions FOR EACH ROW EXECUTE FUNCTION public.update_ckb_transactions_count();


--
-- Name: pool_transaction_entries insert_ckb_transactions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER insert_ckb_transactions AFTER INSERT ON public.pool_transaction_entries FOR EACH ROW EXECUTE FUNCTION public.insert_into_ckb_transactions();


--
-- Name: old_ckb_transactions sync_to_account_book; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_to_account_book AFTER INSERT OR UPDATE ON public.old_ckb_transactions FOR EACH ROW EXECUTE FUNCTION public.synx_tx_to_account_book();


--
-- Name: block_transactions fk_rails_a0eeb26f19; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.block_transactions
    ADD CONSTRAINT fk_rails_a0eeb26f19 FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: udt_transactions fk_rails_b9a9ee04fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udt_transactions
    ADD CONSTRAINT fk_rails_b9a9ee04fc FOREIGN KEY (udt_id) REFERENCES public.udts(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20190327073533'),
('20190327073646'),
('20190327073737'),
('20190327073848'),
('20190327073920'),
('20190327073948'),
('20190327074009'),
('20190327074053'),
('20190327074129'),
('20190327074238'),
('20190428084336'),
('20190428094733'),
('20190505080010'),
('20190507083006'),
('20190507085943'),
('20190520025819'),
('20190521045538'),
('20190521075501'),
('20190522092518'),
('20190522093025'),
('20190527105726'),
('20190528014728'),
('20190530090537'),
('20190531030940'),
('20190604062236'),
('20190606083952'),
('20190612034620'),
('20190617015612'),
('20190617015805'),
('20190618154208'),
('20190618154444'),
('20190625075829'),
('20190625093219'),
('20190625093335'),
('20190626085513'),
('20190628052742'),
('20190703102751'),
('20190705084121'),
('20190708060254'),
('20190711102928'),
('20190722051936'),
('20190724053202'),
('20190725014432'),
('20190731111218'),
('20190731111431'),
('20190731112207'),
('20190809023059'),
('20190810071407'),
('20190813074456'),
('20190816092434'),
('20190816092718'),
('20190816102847'),
('20190819090938'),
('20190823015148'),
('20190823031706'),
('20190824025831'),
('20190916094321'),
('20190929032339'),
('20190930025437'),
('20191004060003'),
('20191009075035'),
('20191009081603'),
('20191009083202'),
('20191108023656'),
('20191108111509'),
('20191108122048'),
('20191126225038'),
('20191127045149'),
('20191201023327'),
('20191201111810'),
('20191202080732'),
('20191202081157'),
('20191205065410'),
('20191206015942'),
('20191206042241'),
('20191208071607'),
('20191209054145'),
('20191213030520'),
('20191216080206'),
('20191219014039'),
('20191219020035'),
('20191225110229'),
('20191225131337'),
('20191225153746'),
('20191226084920'),
('20191230012431'),
('20200103051008'),
('20200110123617'),
('20200115020206'),
('20200121083529'),
('20200122060907'),
('20200226063458'),
('20200226072529'),
('20200302075922'),
('20200305132554'),
('20200326050752'),
('20200409151035'),
('20200413030841'),
('20200414065915'),
('20200414082343'),
('20200415022539'),
('20200416060532'),
('20200416090920'),
('20200417020812'),
('20200417092543'),
('20200417095215'),
('20200421013646'),
('20200423031220'),
('20200424084519'),
('20200427041823'),
('20200427073824'),
('20200427101449'),
('20200428070217'),
('20200428092757'),
('20200430110951'),
('20200430124336'),
('20200506043401'),
('20200509144539'),
('20200513032346'),
('20200525100826'),
('20200601121842'),
('20200618102442'),
('20200624022548'),
('20200628091022'),
('20200702035301'),
('20200703043629'),
('20200709100457'),
('20200714044614'),
('20200716174806'),
('20200729174146'),
('20200803152507'),
('20200805093044'),
('20200806060029'),
('20200806071500'),
('20200806081043'),
('20201029140549'),
('20201218065319'),
('20201224071647'),
('20201228095436'),
('20210129123835'),
('20210129124809'),
('20210131120306'),
('20210222102120'),
('20210225124705'),
('20210303023806'),
('20210304115516'),
('20210509040821'),
('20210716052833'),
('20210716053144'),
('20210810022442'),
('20210813081152'),
('20210819124921'),
('20210824133215'),
('20210824155634'),
('20211015090450'),
('20211015105234'),
('20211103012805'),
('20211223141618'),
('20211223141845'),
('20220216063204'),
('20220311140723'),
('20220311144809'),
('20220629011100'),
('20220629012700'),
('20220629142603'),
('20220705003300'),
('20220711181425'),
('20220711183054'),
('20220716080815'),
('20220718162023'),
('20220726180124'),
('20220727000610'),
('20220801080617'),
('20220803030716'),
('20220822155712'),
('20220830023203'),
('20220830163001'),
('20220904005610'),
('20220912154933'),
('20221009072146'),
('20221009073948'),
('20221009075753'),
('20221009080035'),
('20221009080306'),
('20221009080708'),
('20221009081118'),
('20221024021923'),
('20221030235723'),
('20221031085901'),
('20221106174818'),
('20221106182302'),
('20221108035020'),
('20221213075412'),
('20221227013538'),
('20221228102920'),
('20221230022643'),
('20230101045136'),
('20230104093413'),
('20230106111415'),
('20230114022237'),
('20230117035205'),
('20230128015428'),
('20230128015956'),
('20230128031939'),
('20230129165127'),
('20230206073806'),
('20230207112513'),
('20230208081700'),
('20230210124237'),
('20230211062045'),
('20230216084358'),
('20230217064540'),
('20230218154437'),
('20230220013604'),
('20230220060922'),
('20230228114330'),
('20230306142312'),
('20230307073134'),
('20230317081407'),
('20230319152819'),
('20230319160108'),
('20230319164714'),
('20230320062211'),
('20230320075334'),
('20230320151216'),
('20230320153418'),
('20230321122734'),
('20230328134010'),
('20230330112855'),
('20230330134854'),
('20230330135137'),
('20230330155253'),
('20230330165609'),
('20230331052851'),
('20230331060239'),
('20230331090020'),
('20230331151334'),
('20230331151335'),
('20230331151336'),
('20230401012010'),
('20230401033240'),
('20230402125000'),
('20230403052005'),
('20230403154742'),
('20230404072229'),
('20230404151647'),
('20230406003722'),
('20230406011556'),
('20230412070853'),
('20230415042814'),
('20230415150143'),
('20230425114436'),
('20230425162318'),
('20230426133543'),
('20230427025007'),
('20230504023535'),
('20230518061651'),
('20230526070328'),
('20230526085258'),
('20230526135653'),
('20230603124843'),
('20230622134109'),
('20230622143224'),
('20230622143339'),
('20230630112234');
