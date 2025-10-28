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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_books; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_books (
    id bigint NOT NULL,
    address_id bigint,
    ckb_transaction_id bigint,
    income numeric(30,0),
    block_number bigint,
    tx_index integer
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
    lock_script_id bigint,
    balance_occupied numeric(30,0) DEFAULT 0.0,
    last_updated_block_number bigint
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
    cycles bigint,
    difficulty numeric(78,0)
);


--
-- Name: COLUMN blocks.ckb_node_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.blocks.ckb_node_version IS 'ckb node version, e.g. 0.105.1';


--
-- Name: average_block_time_by_hour; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.average_block_time_by_hour AS
 SELECT ("timestamp" / 3600000) AS hour,
    avg(block_time) AS avg_block_time_per_hour
   FROM public.blocks
  GROUP BY ("timestamp" / 3600000)
  WITH NO DATA;


--
-- Name: bitcoin_address_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bitcoin_address_mappings (
    id bigint NOT NULL,
    bitcoin_address_id bigint,
    ckb_address_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bitcoin_address_mappings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bitcoin_address_mappings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bitcoin_address_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bitcoin_address_mappings_id_seq OWNED BY public.bitcoin_address_mappings.id;


--
-- Name: bitcoin_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bitcoin_addresses (
    id bigint NOT NULL,
    address_hash bytea NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bitcoin_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bitcoin_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bitcoin_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bitcoin_addresses_id_seq OWNED BY public.bitcoin_addresses.id;


--
-- Name: bitcoin_annotations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bitcoin_annotations (
    id bigint NOT NULL,
    ckb_transaction_id bigint,
    leap_direction integer,
    transfer_step integer,
    tags character varying[] DEFAULT '{}'::character varying[],
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bitcoin_annotations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bitcoin_annotations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bitcoin_annotations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bitcoin_annotations_id_seq OWNED BY public.bitcoin_annotations.id;


--
-- Name: bitcoin_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bitcoin_statistics (
    id bigint NOT NULL,
    "timestamp" bigint,
    transactions_count integer DEFAULT 0,
    addresses_count integer DEFAULT 0
);


--
-- Name: bitcoin_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bitcoin_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bitcoin_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bitcoin_statistics_id_seq OWNED BY public.bitcoin_statistics.id;


--
-- Name: bitcoin_time_locks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bitcoin_time_locks (
    id bigint NOT NULL,
    bitcoin_transaction_id bigint,
    ckb_transaction_id bigint,
    cell_output_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bitcoin_time_locks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bitcoin_time_locks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bitcoin_time_locks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bitcoin_time_locks_id_seq OWNED BY public.bitcoin_time_locks.id;


--
-- Name: bitcoin_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bitcoin_transactions (
    id bigint NOT NULL,
    txid bytea,
    tx_hash bytea,
    "time" bigint,
    block_hash bytea,
    block_height bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bitcoin_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bitcoin_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bitcoin_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bitcoin_transactions_id_seq OWNED BY public.bitcoin_transactions.id;


--
-- Name: bitcoin_transfers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bitcoin_transfers (
    id bigint NOT NULL,
    bitcoin_transaction_id bigint,
    ckb_transaction_id bigint,
    cell_output_id bigint,
    lock_type integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bitcoin_transfers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bitcoin_transfers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bitcoin_transfers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bitcoin_transfers_id_seq OWNED BY public.bitcoin_transfers.id;


--
-- Name: bitcoin_vins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bitcoin_vins (
    id bigint NOT NULL,
    previous_bitcoin_vout_id bigint,
    ckb_transaction_id bigint,
    cell_input_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bitcoin_vins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bitcoin_vins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bitcoin_vins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bitcoin_vins_id_seq OWNED BY public.bitcoin_vins.id;


--
-- Name: bitcoin_vouts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bitcoin_vouts (
    id bigint NOT NULL,
    bitcoin_transaction_id bigint,
    bitcoin_address_id bigint,
    data bytea,
    index integer,
    asm text,
    op_return boolean DEFAULT false,
    ckb_transaction_id bigint,
    cell_output_id bigint,
    address_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    status integer DEFAULT 0,
    consumed_by_id bigint
);


--
-- Name: bitcoin_vouts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bitcoin_vouts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bitcoin_vouts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bitcoin_vouts_id_seq OWNED BY public.bitcoin_vouts.id;


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
-- Name: btc_account_books; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.btc_account_books (
    id bigint NOT NULL,
    ckb_transaction_id bigint,
    bitcoin_address_id bigint
);


--
-- Name: btc_account_books_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.btc_account_books_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: btc_account_books_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.btc_account_books_id_seq OWNED BY public.btc_account_books.id;


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
    ckb_transaction_id bigint NOT NULL,
    dep_type integer,
    contract_cell_id bigint NOT NULL,
    block_number bigint,
    tx_index integer,
    contract_analyzed boolean DEFAULT false,
    is_used boolean DEFAULT true
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
-- Name: cell_deps_out_points; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cell_deps_out_points (
    id bigint NOT NULL,
    tx_hash bytea,
    cell_index integer,
    deployed_cell_output_id bigint,
    contract_cell_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: cell_deps_out_points_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cell_deps_out_points_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cell_deps_out_points_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cell_deps_out_points_id_seq OWNED BY public.cell_deps_out_points.id;


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
    block_id bigint,
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
    ckb_transaction_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
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
)
PARTITION BY LIST (status);


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
-- Name: cell_outputs_dead; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cell_outputs_dead (
    id bigint DEFAULT nextval('public.cell_outputs_id_seq'::regclass) NOT NULL,
    capacity numeric(64,2),
    ckb_transaction_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
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
-- Name: cell_outputs_live; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cell_outputs_live (
    id bigint DEFAULT nextval('public.cell_outputs_id_seq'::regclass) NOT NULL,
    capacity numeric(64,2),
    ckb_transaction_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
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
-- Name: cell_outputs_pending; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cell_outputs_pending (
    id bigint DEFAULT nextval('public.cell_outputs_id_seq'::regclass) NOT NULL,
    capacity numeric(64,2),
    ckb_transaction_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
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
-- Name: cell_outputs_rejected; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cell_outputs_rejected (
    id bigint DEFAULT nextval('public.cell_outputs_id_seq'::regclass) NOT NULL,
    capacity numeric(64,2),
    ckb_transaction_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
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
    confirmation_time bigint,
    tx_index integer
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
    confirmation_time bigint,
    tx_index integer
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
    confirmation_time bigint,
    tx_index integer
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
    confirmation_time bigint,
    tx_index integer
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
    confirmation_time bigint,
    tx_index integer
);


--
-- Name: contracts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contracts (
    id bigint NOT NULL,
    hash_type character varying,
    deployed_args character varying,
    name character varying,
    description character varying,
    verified boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deprecated boolean,
    ckb_transactions_count numeric(30,0) DEFAULT 0.0,
    referring_cells_count numeric(30,0) DEFAULT 0.0,
    total_referring_cells_capacity numeric(30,0) DEFAULT 0.0,
    addresses_count integer,
    h24_ckb_transactions_count integer,
    type_hash bytea,
    data_hash bytea,
    deployed_cell_output_id bigint,
    is_type_script boolean,
    is_lock_script boolean,
    rfc character varying,
    source_url character varying,
    dep_type integer,
    website character varying,
    deployed_block_timestamp numeric(20,0),
    contract_cell_id bigint,
    is_primary boolean,
    is_zero_lock boolean
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
    locked_capacity numeric(30,0),
    ckb_hodl_wave jsonb,
    holder_count integer,
    knowledge_size numeric(30,0),
    activity_address_contract_distribution jsonb
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
    depositors_count integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    unclaimed_compensation numeric(30,0)
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
    block_timestamp numeric(30,0),
    consumed_transaction_id bigint,
    cell_index integer,
    consumed_block_timestamp numeric(20,0),
    cell_output_id bigint
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
    max_tx_cycles bigint
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
-- Name: fiber_account_books; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fiber_account_books (
    id bigint NOT NULL,
    fiber_graph_channel_id bigint,
    ckb_transaction_id bigint,
    address_id bigint
);


--
-- Name: fiber_account_books_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fiber_account_books_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fiber_account_books_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fiber_account_books_id_seq OWNED BY public.fiber_account_books.id;


--
-- Name: fiber_channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fiber_channels (
    id bigint NOT NULL,
    peer_id character varying,
    channel_id character varying,
    state_name character varying,
    state_flags character varying[] DEFAULT '{}'::character varying[],
    local_balance numeric(64,2) DEFAULT 0.0,
    offered_tlc_balance numeric(64,2) DEFAULT 0.0,
    remote_balance numeric(64,2) DEFAULT 0.0,
    received_tlc_balance numeric(64,2) DEFAULT 0.0,
    shutdown_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    fiber_peer_id integer
);


--
-- Name: fiber_channels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fiber_channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fiber_channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fiber_channels_id_seq OWNED BY public.fiber_channels.id;


--
-- Name: fiber_graph_channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fiber_graph_channels (
    id bigint NOT NULL,
    channel_outpoint character varying,
    node1 character varying,
    node2 character varying,
    created_timestamp bigint,
    capacity numeric(64,2) DEFAULT 0.0,
    chain_hash character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    udt_id bigint,
    open_transaction_id bigint,
    closed_transaction_id bigint,
    last_updated_timestamp_of_node1 bigint,
    last_updated_timestamp_of_node2 bigint,
    fee_rate_of_node1 numeric(30,0) DEFAULT 0.0,
    fee_rate_of_node2 numeric(30,0) DEFAULT 0.0,
    deleted_at timestamp(6) without time zone,
    cell_output_id bigint,
    address_id bigint,
    update_info_of_node1 jsonb DEFAULT '{}'::jsonb,
    update_info_of_node2 jsonb DEFAULT '{}'::jsonb
);


--
-- Name: fiber_graph_channels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fiber_graph_channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fiber_graph_channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fiber_graph_channels_id_seq OWNED BY public.fiber_graph_channels.id;


--
-- Name: fiber_graph_nodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fiber_graph_nodes (
    id bigint NOT NULL,
    node_name character varying,
    node_id character varying,
    addresses character varying[] DEFAULT '{}'::character varying[],
    "timestamp" bigint,
    chain_hash character varying,
    auto_accept_min_ckb_funding_amount numeric(30,0),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    peer_id character varying,
    deleted_at timestamp(6) without time zone
);


--
-- Name: fiber_graph_nodes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fiber_graph_nodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fiber_graph_nodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fiber_graph_nodes_id_seq OWNED BY public.fiber_graph_nodes.id;


--
-- Name: fiber_peers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fiber_peers (
    id bigint NOT NULL,
    name character varying,
    peer_id character varying,
    rpc_listening_addr character varying[] DEFAULT '{}'::character varying[],
    first_channel_opened_at timestamp(6) without time zone,
    last_channel_updated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    node_id character varying,
    chain_hash character varying
);


--
-- Name: fiber_peers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fiber_peers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fiber_peers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fiber_peers_id_seq OWNED BY public.fiber_peers.id;


--
-- Name: fiber_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fiber_statistics (
    id bigint NOT NULL,
    total_nodes integer,
    total_channels integer,
    total_capacity bigint,
    mean_value_locked bigint,
    mean_fee_rate integer,
    medium_value_locked bigint,
    medium_fee_rate integer,
    created_at_unixtimestamp integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    total_liquidity jsonb
);


--
-- Name: fiber_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fiber_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fiber_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fiber_statistics_id_seq OWNED BY public.fiber_statistics.id;


--
-- Name: fiber_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fiber_transactions (
    id bigint NOT NULL,
    fiber_peer_id integer,
    fiber_channel_id integer,
    ckb_transaction_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: fiber_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fiber_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fiber_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fiber_transactions_id_seq OWNED BY public.fiber_transactions.id;


--
-- Name: fiber_udt_cfg_infos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fiber_udt_cfg_infos (
    id bigint NOT NULL,
    fiber_graph_node_id bigint,
    udt_id bigint,
    auto_accept_amount numeric(64,2) DEFAULT 0.0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone
);


--
-- Name: fiber_udt_cfg_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fiber_udt_cfg_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fiber_udt_cfg_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fiber_udt_cfg_infos_id_seq OWNED BY public.fiber_udt_cfg_infos.id;


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
    cycles bigint,
    difficulty numeric(78,0)
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
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    hash_type character varying,
    script_hash character varying
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
-- Name: omiga_inscription_infos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.omiga_inscription_infos (
    id bigint NOT NULL,
    code_hash bytea,
    hash_type character varying,
    args character varying,
    "decimal" numeric,
    name character varying,
    symbol character varying,
    udt_hash character varying,
    expected_supply numeric,
    mint_limit numeric,
    mint_status integer,
    udt_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    type_hash bytea,
    pre_udt_hash bytea,
    is_repeated_symbol boolean DEFAULT false
);


--
-- Name: omiga_inscription_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.omiga_inscription_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: omiga_inscription_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.omiga_inscription_infos_id_seq OWNED BY public.omiga_inscription_infos.id;


--
-- Name: portfolios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.portfolios (
    id bigint NOT NULL,
    user_id bigint,
    address_id bigint
);


--
-- Name: portfolios_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.portfolios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: portfolios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.portfolios_id_seq OWNED BY public.portfolios.id;


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
-- Name: rgbpp_assets_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rgbpp_assets_statistics (
    id bigint NOT NULL,
    indicator integer NOT NULL,
    value numeric(40,0) DEFAULT 0.0,
    network integer DEFAULT 0,
    created_at_unixtimestamp integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: rgbpp_assets_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rgbpp_assets_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rgbpp_assets_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rgbpp_assets_statistics_id_seq OWNED BY public.rgbpp_assets_statistics.id;


--
-- Name: rgbpp_hourly_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rgbpp_hourly_statistics (
    id bigint NOT NULL,
    xudt_count integer DEFAULT 0,
    dob_count integer DEFAULT 0,
    created_at_unixtimestamp integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: rgbpp_hourly_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rgbpp_hourly_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rgbpp_hourly_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rgbpp_hourly_statistics_id_seq OWNED BY public.rgbpp_hourly_statistics.id;


--
-- Name: rolling_avg_block_time; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.rolling_avg_block_time AS
 SELECT (hour * 3600) AS "timestamp",
    avg(avg_block_time_per_hour) OVER (ORDER BY hour ROWS BETWEEN 24 PRECEDING AND CURRENT ROW) AS avg_block_time_daily,
    avg(avg_block_time_per_hour) OVER (ORDER BY hour ROWS BETWEEN (7 * 24) PRECEDING AND CURRENT ROW) AS avg_block_time_weekly
   FROM public.average_block_time_by_hour
  WITH NO DATA;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: ssri_contracts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ssri_contracts (
    id bigint NOT NULL,
    contract_id bigint,
    methods character varying[] DEFAULT '{}'::character varying[],
    is_udt boolean,
    code_hash bytea,
    hash_type character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ssri_contracts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ssri_contracts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ssri_contracts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ssri_contracts_id_seq OWNED BY public.ssri_contracts.id;


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
    sn character varying,
    h24_ckb_transactions_count bigint DEFAULT 0,
    tags character varying[] DEFAULT '{}'::character varying[],
    block_timestamp bigint
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
-- Name: type_scripts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.type_scripts (
    id bigint NOT NULL,
    args character varying,
    code_hash bytea,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    hash_type character varying,
    script_hash character varying
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
-- Name: udt_holder_allocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.udt_holder_allocations (
    id bigint NOT NULL,
    udt_id bigint NOT NULL,
    contract_id bigint,
    ckb_holder_count integer DEFAULT 0 NOT NULL,
    btc_holder_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: udt_holder_allocations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.udt_holder_allocations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: udt_holder_allocations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.udt_holder_allocations_id_seq OWNED BY public.udt_holder_allocations.id;


--
-- Name: udt_hourly_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.udt_hourly_statistics (
    id bigint NOT NULL,
    udt_id bigint NOT NULL,
    ckb_transactions_count integer DEFAULT 0,
    amount numeric(40,0) DEFAULT 0.0,
    holders_count integer DEFAULT 0,
    created_at_unixtimestamp integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: udt_hourly_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.udt_hourly_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: udt_hourly_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.udt_hourly_statistics_id_seq OWNED BY public.udt_hourly_statistics.id;


--
-- Name: udt_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.udt_transactions (
    udt_id bigint,
    ckb_transaction_id bigint
);


--
-- Name: udt_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.udt_verifications (
    id bigint NOT NULL,
    token integer,
    sent_at timestamp(6) without time zone,
    last_ip inet,
    udt_id bigint,
    udt_type_hash integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: udt_verifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.udt_verifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: udt_verifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.udt_verifications_id_seq OWNED BY public.udt_verifications.id;


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
    h24_ckb_transactions_count bigint DEFAULT 0,
    email character varying
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
    compact_target numeric(20,0),
    difficulty numeric(78,0)
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
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    uuid character varying(36),
    identifier character varying,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


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
-- Name: xudt_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.xudt_tags (
    id bigint NOT NULL,
    udt_id integer,
    udt_type_hash character varying,
    tags character varying[] DEFAULT '{}'::character varying[],
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: xudt_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.xudt_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: xudt_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.xudt_tags_id_seq OWNED BY public.xudt_tags.id;


--
-- Name: cell_outputs_dead; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_outputs ATTACH PARTITION public.cell_outputs_dead FOR VALUES IN ('1');


--
-- Name: cell_outputs_live; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_outputs ATTACH PARTITION public.cell_outputs_live FOR VALUES IN ('0');


--
-- Name: cell_outputs_pending; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_outputs ATTACH PARTITION public.cell_outputs_pending FOR VALUES IN ('2');


--
-- Name: cell_outputs_rejected; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_outputs ATTACH PARTITION public.cell_outputs_rejected FOR VALUES IN ('3');


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
-- Name: addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses ALTER COLUMN id SET DEFAULT nextval('public.addresses_id_seq'::regclass);


--
-- Name: bitcoin_address_mappings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_address_mappings ALTER COLUMN id SET DEFAULT nextval('public.bitcoin_address_mappings_id_seq'::regclass);


--
-- Name: bitcoin_addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_addresses ALTER COLUMN id SET DEFAULT nextval('public.bitcoin_addresses_id_seq'::regclass);


--
-- Name: bitcoin_annotations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_annotations ALTER COLUMN id SET DEFAULT nextval('public.bitcoin_annotations_id_seq'::regclass);


--
-- Name: bitcoin_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_statistics ALTER COLUMN id SET DEFAULT nextval('public.bitcoin_statistics_id_seq'::regclass);


--
-- Name: bitcoin_time_locks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_time_locks ALTER COLUMN id SET DEFAULT nextval('public.bitcoin_time_locks_id_seq'::regclass);


--
-- Name: bitcoin_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_transactions ALTER COLUMN id SET DEFAULT nextval('public.bitcoin_transactions_id_seq'::regclass);


--
-- Name: bitcoin_transfers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_transfers ALTER COLUMN id SET DEFAULT nextval('public.bitcoin_transfers_id_seq'::regclass);


--
-- Name: bitcoin_vins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_vins ALTER COLUMN id SET DEFAULT nextval('public.bitcoin_vins_id_seq'::regclass);


--
-- Name: bitcoin_vouts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_vouts ALTER COLUMN id SET DEFAULT nextval('public.bitcoin_vouts_id_seq'::regclass);


--
-- Name: block_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.block_statistics ALTER COLUMN id SET DEFAULT nextval('public.block_statistics_id_seq'::regclass);


--
-- Name: blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks ALTER COLUMN id SET DEFAULT nextval('public.blocks_id_seq'::regclass);


--
-- Name: btc_account_books id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.btc_account_books ALTER COLUMN id SET DEFAULT nextval('public.btc_account_books_id_seq'::regclass);


--
-- Name: cell_data cell_output_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_data ALTER COLUMN cell_output_id SET DEFAULT nextval('public.cell_data_cell_output_id_seq'::regclass);


--
-- Name: cell_dependencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_dependencies ALTER COLUMN id SET DEFAULT nextval('public.cell_dependencies_id_seq'::regclass);


--
-- Name: cell_deps_out_points id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_deps_out_points ALTER COLUMN id SET DEFAULT nextval('public.cell_deps_out_points_id_seq'::regclass);


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
-- Name: epoch_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_statistics ALTER COLUMN id SET DEFAULT nextval('public.epoch_statistics_id_seq'::regclass);


--
-- Name: fiber_account_books id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_account_books ALTER COLUMN id SET DEFAULT nextval('public.fiber_account_books_id_seq'::regclass);


--
-- Name: fiber_channels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_channels ALTER COLUMN id SET DEFAULT nextval('public.fiber_channels_id_seq'::regclass);


--
-- Name: fiber_graph_channels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_graph_channels ALTER COLUMN id SET DEFAULT nextval('public.fiber_graph_channels_id_seq'::regclass);


--
-- Name: fiber_graph_nodes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_graph_nodes ALTER COLUMN id SET DEFAULT nextval('public.fiber_graph_nodes_id_seq'::regclass);


--
-- Name: fiber_peers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_peers ALTER COLUMN id SET DEFAULT nextval('public.fiber_peers_id_seq'::regclass);


--
-- Name: fiber_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_statistics ALTER COLUMN id SET DEFAULT nextval('public.fiber_statistics_id_seq'::regclass);


--
-- Name: fiber_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_transactions ALTER COLUMN id SET DEFAULT nextval('public.fiber_transactions_id_seq'::regclass);


--
-- Name: fiber_udt_cfg_infos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_udt_cfg_infos ALTER COLUMN id SET DEFAULT nextval('public.fiber_udt_cfg_infos_id_seq'::regclass);


--
-- Name: forked_blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forked_blocks ALTER COLUMN id SET DEFAULT nextval('public.forked_blocks_id_seq'::regclass);


--
-- Name: forked_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forked_events ALTER COLUMN id SET DEFAULT nextval('public.forked_events_id_seq'::regclass);


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
-- Name: omiga_inscription_infos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.omiga_inscription_infos ALTER COLUMN id SET DEFAULT nextval('public.omiga_inscription_infos_id_seq'::regclass);


--
-- Name: portfolios id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.portfolios ALTER COLUMN id SET DEFAULT nextval('public.portfolios_id_seq'::regclass);


--
-- Name: reject_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reject_reasons ALTER COLUMN id SET DEFAULT nextval('public.reject_reasons_id_seq'::regclass);


--
-- Name: rgbpp_assets_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rgbpp_assets_statistics ALTER COLUMN id SET DEFAULT nextval('public.rgbpp_assets_statistics_id_seq'::regclass);


--
-- Name: rgbpp_hourly_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rgbpp_hourly_statistics ALTER COLUMN id SET DEFAULT nextval('public.rgbpp_hourly_statistics_id_seq'::regclass);


--
-- Name: ssri_contracts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssri_contracts ALTER COLUMN id SET DEFAULT nextval('public.ssri_contracts_id_seq'::regclass);


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
-- Name: type_scripts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.type_scripts ALTER COLUMN id SET DEFAULT nextval('public.type_scripts_id_seq'::regclass);


--
-- Name: udt_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udt_accounts ALTER COLUMN id SET DEFAULT nextval('public.udt_accounts_id_seq'::regclass);


--
-- Name: udt_holder_allocations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udt_holder_allocations ALTER COLUMN id SET DEFAULT nextval('public.udt_holder_allocations_id_seq'::regclass);


--
-- Name: udt_hourly_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udt_hourly_statistics ALTER COLUMN id SET DEFAULT nextval('public.udt_hourly_statistics_id_seq'::regclass);


--
-- Name: udt_verifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udt_verifications ALTER COLUMN id SET DEFAULT nextval('public.udt_verifications_id_seq'::regclass);


--
-- Name: udts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udts ALTER COLUMN id SET DEFAULT nextval('public.udts_id_seq'::regclass);


--
-- Name: uncle_blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uncle_blocks ALTER COLUMN id SET DEFAULT nextval('public.uncle_blocks_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: witnesses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.witnesses ALTER COLUMN id SET DEFAULT nextval('public.witnesses_id_seq'::regclass);


--
-- Name: xudt_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.xudt_tags ALTER COLUMN id SET DEFAULT nextval('public.xudt_tags_id_seq'::regclass);


--
-- Name: account_books account_books_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_books
    ADD CONSTRAINT account_books_pkey PRIMARY KEY (id);


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
-- Name: bitcoin_address_mappings bitcoin_address_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_address_mappings
    ADD CONSTRAINT bitcoin_address_mappings_pkey PRIMARY KEY (id);


--
-- Name: bitcoin_addresses bitcoin_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_addresses
    ADD CONSTRAINT bitcoin_addresses_pkey PRIMARY KEY (id);


--
-- Name: bitcoin_annotations bitcoin_annotations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_annotations
    ADD CONSTRAINT bitcoin_annotations_pkey PRIMARY KEY (id);


--
-- Name: bitcoin_statistics bitcoin_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_statistics
    ADD CONSTRAINT bitcoin_statistics_pkey PRIMARY KEY (id);


--
-- Name: bitcoin_time_locks bitcoin_time_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_time_locks
    ADD CONSTRAINT bitcoin_time_locks_pkey PRIMARY KEY (id);


--
-- Name: bitcoin_transactions bitcoin_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_transactions
    ADD CONSTRAINT bitcoin_transactions_pkey PRIMARY KEY (id);


--
-- Name: bitcoin_transfers bitcoin_transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_transfers
    ADD CONSTRAINT bitcoin_transfers_pkey PRIMARY KEY (id);


--
-- Name: bitcoin_vins bitcoin_vins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_vins
    ADD CONSTRAINT bitcoin_vins_pkey PRIMARY KEY (id);


--
-- Name: bitcoin_vouts bitcoin_vouts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitcoin_vouts
    ADD CONSTRAINT bitcoin_vouts_pkey PRIMARY KEY (id);


--
-- Name: block_statistics block_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.block_statistics
    ADD CONSTRAINT block_statistics_pkey PRIMARY KEY (id);


--
-- Name: blocks blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (id);


--
-- Name: btc_account_books btc_account_books_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.btc_account_books
    ADD CONSTRAINT btc_account_books_pkey PRIMARY KEY (id);


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
-- Name: cell_deps_out_points cell_deps_out_points_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_deps_out_points
    ADD CONSTRAINT cell_deps_out_points_pkey PRIMARY KEY (id);


--
-- Name: cell_inputs cell_inputs_pkey_new; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_inputs
    ADD CONSTRAINT cell_inputs_pkey_new PRIMARY KEY (id);


--
-- Name: cell_outputs cell_outputs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_outputs
    ADD CONSTRAINT cell_outputs_pkey PRIMARY KEY (id, status);


--
-- Name: cell_outputs_dead cell_outputs_dead_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_outputs_dead
    ADD CONSTRAINT cell_outputs_dead_pkey PRIMARY KEY (id, status);


--
-- Name: cell_outputs_live cell_outputs_live_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_outputs_live
    ADD CONSTRAINT cell_outputs_live_pkey PRIMARY KEY (id, status);


--
-- Name: cell_outputs_pending cell_outputs_pending_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_outputs_pending
    ADD CONSTRAINT cell_outputs_pending_pkey PRIMARY KEY (id, status);


--
-- Name: cell_outputs_rejected cell_outputs_rejected_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_outputs_rejected
    ADD CONSTRAINT cell_outputs_rejected_pkey PRIMARY KEY (id, status);


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
-- Name: epoch_statistics epoch_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_statistics
    ADD CONSTRAINT epoch_statistics_pkey PRIMARY KEY (id);


--
-- Name: fiber_account_books fiber_account_books_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_account_books
    ADD CONSTRAINT fiber_account_books_pkey PRIMARY KEY (id);


--
-- Name: fiber_channels fiber_channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_channels
    ADD CONSTRAINT fiber_channels_pkey PRIMARY KEY (id);


--
-- Name: fiber_graph_channels fiber_graph_channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_graph_channels
    ADD CONSTRAINT fiber_graph_channels_pkey PRIMARY KEY (id);


--
-- Name: fiber_graph_nodes fiber_graph_nodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_graph_nodes
    ADD CONSTRAINT fiber_graph_nodes_pkey PRIMARY KEY (id);


--
-- Name: fiber_peers fiber_peers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_peers
    ADD CONSTRAINT fiber_peers_pkey PRIMARY KEY (id);


--
-- Name: fiber_statistics fiber_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_statistics
    ADD CONSTRAINT fiber_statistics_pkey PRIMARY KEY (id);


--
-- Name: fiber_transactions fiber_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_transactions
    ADD CONSTRAINT fiber_transactions_pkey PRIMARY KEY (id);


--
-- Name: fiber_udt_cfg_infos fiber_udt_cfg_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiber_udt_cfg_infos
    ADD CONSTRAINT fiber_udt_cfg_infos_pkey PRIMARY KEY (id);


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
-- Name: omiga_inscription_infos omiga_inscription_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.omiga_inscription_infos
    ADD CONSTRAINT omiga_inscription_infos_pkey PRIMARY KEY (id);


--
-- Name: portfolios portfolios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.portfolios
    ADD CONSTRAINT portfolios_pkey PRIMARY KEY (id);


--
-- Name: reject_reasons reject_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reject_reasons
    ADD CONSTRAINT reject_reasons_pkey PRIMARY KEY (id);


--
-- Name: rgbpp_assets_statistics rgbpp_assets_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rgbpp_assets_statistics
    ADD CONSTRAINT rgbpp_assets_statistics_pkey PRIMARY KEY (id);


--
-- Name: rgbpp_hourly_statistics rgbpp_hourly_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rgbpp_hourly_statistics
    ADD CONSTRAINT rgbpp_hourly_statistics_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: ssri_contracts ssri_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssri_contracts
    ADD CONSTRAINT ssri_contracts_pkey PRIMARY KEY (id);


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
-- Name: udt_holder_allocations udt_holder_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udt_holder_allocations
    ADD CONSTRAINT udt_holder_allocations_pkey PRIMARY KEY (id);


--
-- Name: udt_hourly_statistics udt_hourly_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udt_hourly_statistics
    ADD CONSTRAINT udt_hourly_statistics_pkey PRIMARY KEY (id);


--
-- Name: udt_verifications udt_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udt_verifications
    ADD CONSTRAINT udt_verifications_pkey PRIMARY KEY (id);


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
-- Name: udts unique_type_hash; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.udts
    ADD CONSTRAINT unique_type_hash UNIQUE (type_hash);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: witnesses witnesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.witnesses
    ADD CONSTRAINT witnesses_pkey PRIMARY KEY (id);


--
-- Name: xudt_tags xudt_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.xudt_tags
    ADD CONSTRAINT xudt_tags_pkey PRIMARY KEY (id);


--
-- Name: address_udt_tx_alt_pk; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX address_udt_tx_alt_pk ON public.address_udt_transactions USING btree (address_id, ckb_transaction_id);


--
-- Name: index_cell_outputs_on_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_address_id ON ONLY public.cell_outputs USING btree (address_id);


--
-- Name: cell_outputs_dead_address_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_dead_address_id_idx ON public.cell_outputs_dead USING btree (address_id);


--
-- Name: index_cell_outputs_on_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_block_id ON ONLY public.cell_outputs USING btree (block_id);


--
-- Name: cell_outputs_dead_block_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_dead_block_id_idx ON public.cell_outputs_dead USING btree (block_id);


--
-- Name: index_cell_outputs_on_block_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_block_timestamp ON ONLY public.cell_outputs USING btree (block_timestamp);


--
-- Name: cell_outputs_dead_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_dead_block_timestamp_idx ON public.cell_outputs_dead USING btree (block_timestamp);


--
-- Name: index_cell_outputs_on_tx_id_and_cell_index_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cell_outputs_on_tx_id_and_cell_index_and_status ON ONLY public.cell_outputs USING btree (ckb_transaction_id, cell_index, status);


--
-- Name: cell_outputs_dead_ckb_transaction_id_cell_index_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cell_outputs_dead_ckb_transaction_id_cell_index_status_idx ON public.cell_outputs_dead USING btree (ckb_transaction_id, cell_index, status);


--
-- Name: index_cell_outputs_on_consumed_block_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_consumed_block_timestamp ON ONLY public.cell_outputs USING btree (consumed_block_timestamp);


--
-- Name: cell_outputs_dead_consumed_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_dead_consumed_block_timestamp_idx ON public.cell_outputs_dead USING btree (consumed_block_timestamp);


--
-- Name: index_cell_outputs_on_consumed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_consumed_by_id ON ONLY public.cell_outputs USING btree (consumed_by_id);


--
-- Name: cell_outputs_dead_consumed_by_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_dead_consumed_by_id_idx ON public.cell_outputs_dead USING btree (consumed_by_id);


--
-- Name: index_cell_outputs_on_lock_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_lock_script_id ON ONLY public.cell_outputs USING btree (lock_script_id);


--
-- Name: cell_outputs_dead_lock_script_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_dead_lock_script_id_idx ON public.cell_outputs_dead USING btree (lock_script_id);


--
-- Name: index_cell_outputs_on_tx_hash_and_cell_index_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cell_outputs_on_tx_hash_and_cell_index_and_status ON ONLY public.cell_outputs USING btree (tx_hash, cell_index, status);


--
-- Name: cell_outputs_dead_tx_hash_cell_index_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cell_outputs_dead_tx_hash_cell_index_status_idx ON public.cell_outputs_dead USING btree (tx_hash, cell_index, status);


--
-- Name: index_cell_outputs_on_type_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_outputs_on_type_script_id ON ONLY public.cell_outputs USING btree (type_script_id);


--
-- Name: cell_outputs_dead_type_script_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_dead_type_script_id_idx ON public.cell_outputs_dead USING btree (type_script_id);


--
-- Name: cell_outputs_live_address_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_live_address_id_idx ON public.cell_outputs_live USING btree (address_id);


--
-- Name: cell_outputs_live_block_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_live_block_id_idx ON public.cell_outputs_live USING btree (block_id);


--
-- Name: cell_outputs_live_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_live_block_timestamp_idx ON public.cell_outputs_live USING btree (block_timestamp);


--
-- Name: cell_outputs_live_ckb_transaction_id_cell_index_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cell_outputs_live_ckb_transaction_id_cell_index_status_idx ON public.cell_outputs_live USING btree (ckb_transaction_id, cell_index, status);


--
-- Name: cell_outputs_live_consumed_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_live_consumed_block_timestamp_idx ON public.cell_outputs_live USING btree (consumed_block_timestamp);


--
-- Name: cell_outputs_live_consumed_by_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_live_consumed_by_id_idx ON public.cell_outputs_live USING btree (consumed_by_id);


--
-- Name: cell_outputs_live_lock_script_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_live_lock_script_id_idx ON public.cell_outputs_live USING btree (lock_script_id);


--
-- Name: cell_outputs_live_tx_hash_cell_index_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cell_outputs_live_tx_hash_cell_index_status_idx ON public.cell_outputs_live USING btree (tx_hash, cell_index, status);


--
-- Name: cell_outputs_live_type_script_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_live_type_script_id_idx ON public.cell_outputs_live USING btree (type_script_id);


--
-- Name: cell_outputs_pending_address_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_pending_address_id_idx ON public.cell_outputs_pending USING btree (address_id);


--
-- Name: cell_outputs_pending_block_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_pending_block_id_idx ON public.cell_outputs_pending USING btree (block_id);


--
-- Name: cell_outputs_pending_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_pending_block_timestamp_idx ON public.cell_outputs_pending USING btree (block_timestamp);


--
-- Name: cell_outputs_pending_ckb_transaction_id_cell_index_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cell_outputs_pending_ckb_transaction_id_cell_index_status_idx ON public.cell_outputs_pending USING btree (ckb_transaction_id, cell_index, status);


--
-- Name: cell_outputs_pending_consumed_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_pending_consumed_block_timestamp_idx ON public.cell_outputs_pending USING btree (consumed_block_timestamp);


--
-- Name: cell_outputs_pending_consumed_by_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_pending_consumed_by_id_idx ON public.cell_outputs_pending USING btree (consumed_by_id);


--
-- Name: cell_outputs_pending_lock_script_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_pending_lock_script_id_idx ON public.cell_outputs_pending USING btree (lock_script_id);


--
-- Name: cell_outputs_pending_tx_hash_cell_index_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cell_outputs_pending_tx_hash_cell_index_status_idx ON public.cell_outputs_pending USING btree (tx_hash, cell_index, status);


--
-- Name: cell_outputs_pending_type_script_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_pending_type_script_id_idx ON public.cell_outputs_pending USING btree (type_script_id);


--
-- Name: cell_outputs_rejected_address_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_rejected_address_id_idx ON public.cell_outputs_rejected USING btree (address_id);


--
-- Name: cell_outputs_rejected_block_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_rejected_block_id_idx ON public.cell_outputs_rejected USING btree (block_id);


--
-- Name: cell_outputs_rejected_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_rejected_block_timestamp_idx ON public.cell_outputs_rejected USING btree (block_timestamp);


--
-- Name: cell_outputs_rejected_ckb_transaction_id_cell_index_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cell_outputs_rejected_ckb_transaction_id_cell_index_status_idx ON public.cell_outputs_rejected USING btree (ckb_transaction_id, cell_index, status);


--
-- Name: cell_outputs_rejected_consumed_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_rejected_consumed_block_timestamp_idx ON public.cell_outputs_rejected USING btree (consumed_block_timestamp);


--
-- Name: cell_outputs_rejected_consumed_by_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_rejected_consumed_by_id_idx ON public.cell_outputs_rejected USING btree (consumed_by_id);


--
-- Name: cell_outputs_rejected_lock_script_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_rejected_lock_script_id_idx ON public.cell_outputs_rejected USING btree (lock_script_id);


--
-- Name: cell_outputs_rejected_tx_hash_cell_index_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cell_outputs_rejected_tx_hash_cell_index_status_idx ON public.cell_outputs_rejected USING btree (tx_hash, cell_index, status);


--
-- Name: cell_outputs_rejected_type_script_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cell_outputs_rejected_type_script_id_idx ON public.cell_outputs_rejected USING btree (type_script_id);


--
-- Name: idx_ckb_txs_for_blocks; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ckb_txs_for_blocks ON ONLY public.ckb_transactions USING btree (block_id, block_timestamp);


--
-- Name: ckb_transactions_committed_block_id_block_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_committed_block_id_block_timestamp_idx ON public.ckb_transactions_committed USING btree (block_id, block_timestamp);


--
-- Name: index_ckb_transactions_on_block_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ckb_transactions_on_block_number ON ONLY public.ckb_transactions USING btree (block_number);


--
-- Name: ckb_transactions_committed_block_number_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_committed_block_number_idx ON public.ckb_transactions_committed USING btree (block_number);


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
-- Name: ckb_transactions_pending_block_number_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_pending_block_number_idx ON public.ckb_transactions_pending USING btree (block_number);


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
-- Name: ckb_transactions_proposed_block_number_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_proposed_block_number_idx ON public.ckb_transactions_proposed USING btree (block_number);


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
-- Name: ckb_transactions_rejected_block_number_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ckb_transactions_rejected_block_number_idx ON public.ckb_transactions_rejected USING btree (block_number);


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
-- Name: idx_cell_inputs_on_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cell_inputs_on_block_id ON public.cell_inputs USING btree (block_id);


--
-- Name: idx_cell_inputs_on_previous_cell_output_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cell_inputs_on_previous_cell_output_id ON public.cell_inputs USING btree (previous_cell_output_id);


--
-- Name: idx_cell_inputs_on_previous_tx_hash_and_previous_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cell_inputs_on_previous_tx_hash_and_previous_index ON public.cell_inputs USING btree (previous_tx_hash, previous_index);


--
-- Name: index_account_books_on_address_id_and_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_account_books_on_address_id_and_ckb_transaction_id ON public.account_books USING btree (address_id, ckb_transaction_id);


--
-- Name: index_account_books_on_block_number_and_tx_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_books_on_block_number_and_tx_index ON public.account_books USING btree (block_number, tx_index);


--
-- Name: index_account_books_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_books_on_ckb_transaction_id ON public.account_books USING btree (ckb_transaction_id);


--
-- Name: index_address_udt_transactions_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_address_udt_transactions_on_ckb_transaction_id ON public.address_udt_transactions USING btree (ckb_transaction_id);


--
-- Name: index_addresses_on_address_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_addresses_on_address_hash ON public.addresses USING hash (address_hash);


--
-- Name: index_addresses_on_balance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_addresses_on_balance ON public.addresses USING btree (balance);


--
-- Name: index_addresses_on_block_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_addresses_on_block_timestamp ON public.addresses USING btree (block_timestamp);


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
-- Name: index_bitcoin_addresses_on_mapping; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bitcoin_addresses_on_mapping ON public.bitcoin_address_mappings USING btree (bitcoin_address_id, ckb_address_id);


--
-- Name: index_bitcoin_annotations_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bitcoin_annotations_on_ckb_transaction_id ON public.bitcoin_annotations USING btree (ckb_transaction_id);


--
-- Name: index_bitcoin_statistics_on_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bitcoin_statistics_on_timestamp ON public.bitcoin_statistics USING btree ("timestamp");


--
-- Name: index_bitcoin_time_locks_on_cell; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bitcoin_time_locks_on_cell ON public.bitcoin_time_locks USING btree (bitcoin_transaction_id, cell_output_id);


--
-- Name: index_bitcoin_transactions_on_txid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bitcoin_transactions_on_txid ON public.bitcoin_transactions USING btree (txid);


--
-- Name: index_bitcoin_transfers_on_bitcoin_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bitcoin_transfers_on_bitcoin_transaction_id ON public.bitcoin_transfers USING btree (bitcoin_transaction_id);


--
-- Name: index_bitcoin_transfers_on_cell_output_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bitcoin_transfers_on_cell_output_id ON public.bitcoin_transfers USING btree (cell_output_id);


--
-- Name: index_bitcoin_transfers_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bitcoin_transfers_on_ckb_transaction_id ON public.bitcoin_transfers USING btree (ckb_transaction_id);


--
-- Name: index_bitcoin_vins_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bitcoin_vins_on_ckb_transaction_id ON public.bitcoin_vins USING btree (ckb_transaction_id);


--
-- Name: index_bitcoin_vins_on_ckb_transaction_id_and_cell_input_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bitcoin_vins_on_ckb_transaction_id_and_cell_input_id ON public.bitcoin_vins USING btree (ckb_transaction_id, cell_input_id);


--
-- Name: index_bitcoin_vouts_on_bitcoin_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bitcoin_vouts_on_bitcoin_address_id ON public.bitcoin_vouts USING btree (bitcoin_address_id);


--
-- Name: index_bitcoin_vouts_on_cell_output_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bitcoin_vouts_on_cell_output_id ON public.bitcoin_vouts USING btree (cell_output_id);


--
-- Name: index_bitcoin_vouts_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bitcoin_vouts_on_ckb_transaction_id ON public.bitcoin_vouts USING btree (ckb_transaction_id);


--
-- Name: index_bitcoin_vouts_on_consumed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bitcoin_vouts_on_consumed_by_id ON public.bitcoin_vouts USING btree (consumed_by_id);


--
-- Name: index_bitcoin_vouts_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bitcoin_vouts_on_status ON public.bitcoin_vouts USING btree (status);


--
-- Name: index_block_statistics_on_block_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_block_statistics_on_block_number ON public.block_statistics USING btree (block_number);


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
-- Name: index_btc_account_books_on_bitcoin_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_btc_account_books_on_bitcoin_address_id ON public.btc_account_books USING btree (bitcoin_address_id);


--
-- Name: index_cell_dependencies_on_block_number_and_tx_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_dependencies_on_block_number_and_tx_index ON public.cell_dependencies USING btree (block_number, tx_index);


--
-- Name: index_cell_dependencies_on_contract_analyzed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cell_dependencies_on_contract_analyzed ON public.cell_dependencies USING btree (contract_analyzed);


--
-- Name: index_cell_dependencies_on_tx_id_and_cell_id_and_dep_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cell_dependencies_on_tx_id_and_cell_id_and_dep_type ON public.cell_dependencies USING btree (ckb_transaction_id, contract_cell_id, dep_type);


--
-- Name: index_cell_deps_out_points_on_contract_cell_id_deployed_cell_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cell_deps_out_points_on_contract_cell_id_deployed_cell_id ON public.cell_deps_out_points USING btree (contract_cell_id, deployed_cell_output_id);


--
-- Name: index_cell_inputs_on_ckb_transaction_id_and_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cell_inputs_on_ckb_transaction_id_and_index ON public.cell_inputs USING btree (ckb_transaction_id, index);


--
-- Name: index_contracts_on_deployed_cell_output_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_contracts_on_deployed_cell_output_id ON public.contracts USING btree (deployed_cell_output_id);


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
-- Name: index_dao_events_on_block_id_tx_id_and_index_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dao_events_on_block_id_tx_id_and_index_and_type ON public.dao_events USING btree (block_id, ckb_transaction_id, cell_index, event_type);


--
-- Name: index_dao_events_on_block_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dao_events_on_block_timestamp ON public.dao_events USING btree (block_timestamp);


--
-- Name: index_dao_events_on_status_and_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dao_events_on_status_and_event_type ON public.dao_events USING btree (status, event_type);


--
-- Name: index_epoch_statistics_on_epoch_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_epoch_statistics_on_epoch_number ON public.epoch_statistics USING btree (epoch_number);


--
-- Name: index_fiber_account_books_on_address_id_and_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_fiber_account_books_on_address_id_and_ckb_transaction_id ON public.fiber_account_books USING btree (address_id, ckb_transaction_id);


--
-- Name: index_fiber_account_books_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fiber_account_books_on_ckb_transaction_id ON public.fiber_account_books USING btree (ckb_transaction_id);


--
-- Name: index_fiber_channels_on_fiber_peer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fiber_channels_on_fiber_peer_id ON public.fiber_channels USING btree (fiber_peer_id);


--
-- Name: index_fiber_channels_on_peer_id_and_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_fiber_channels_on_peer_id_and_channel_id ON public.fiber_channels USING btree (peer_id, channel_id);


--
-- Name: index_fiber_graph_channels_on_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fiber_graph_channels_on_address_id ON public.fiber_graph_channels USING btree (address_id);


--
-- Name: index_fiber_graph_channels_on_channel_outpoint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_fiber_graph_channels_on_channel_outpoint ON public.fiber_graph_channels USING btree (channel_outpoint);


--
-- Name: index_fiber_graph_channels_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fiber_graph_channels_on_deleted_at ON public.fiber_graph_channels USING btree (deleted_at);


--
-- Name: index_fiber_graph_nodes_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fiber_graph_nodes_on_deleted_at ON public.fiber_graph_nodes USING btree (deleted_at);


--
-- Name: index_fiber_graph_nodes_on_node_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_fiber_graph_nodes_on_node_id ON public.fiber_graph_nodes USING btree (node_id);


--
-- Name: index_fiber_peers_on_peer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_fiber_peers_on_peer_id ON public.fiber_peers USING btree (peer_id);


--
-- Name: index_fiber_statistics_on_created_at_unixtimestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_fiber_statistics_on_created_at_unixtimestamp ON public.fiber_statistics USING btree (created_at_unixtimestamp);


--
-- Name: index_fiber_udt_cfg_infos_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fiber_udt_cfg_infos_on_deleted_at ON public.fiber_udt_cfg_infos USING btree (deleted_at);


--
-- Name: index_fiber_udt_cfg_infos_on_fiber_graph_node_id_and_udt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_fiber_udt_cfg_infos_on_fiber_graph_node_id_and_udt_id ON public.fiber_udt_cfg_infos USING btree (fiber_graph_node_id, udt_id);


--
-- Name: index_forked_events_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forked_events_on_status ON public.forked_events USING btree (status);


--
-- Name: index_header_dependencies_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_header_dependencies_on_ckb_transaction_id ON public.header_dependencies USING btree (ckb_transaction_id);


--
-- Name: index_header_dependencies_on_ckb_transaction_id_and_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_header_dependencies_on_ckb_transaction_id_and_index ON public.header_dependencies USING btree (ckb_transaction_id, index);


--
-- Name: index_lock_scripts_on_code_hash_and_hash_type_and_args; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lock_scripts_on_code_hash_and_hash_type_and_args ON public.lock_scripts USING btree (code_hash, hash_type, args);


--
-- Name: index_lock_scripts_on_script_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_lock_scripts_on_script_hash ON public.lock_scripts USING btree (script_hash);


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
-- Name: index_omiga_inscription_infos_on_udt_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_omiga_inscription_infos_on_udt_hash ON public.omiga_inscription_infos USING btree (udt_hash);


--
-- Name: index_on_cell_dependencies_contract_cell_block_tx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_on_cell_dependencies_contract_cell_block_tx ON public.cell_dependencies USING btree (contract_cell_id, block_number DESC, tx_index DESC);


--
-- Name: index_on_indicator_and_network_and_created_at_unixtimestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_on_indicator_and_network_and_created_at_unixtimestamp ON public.rgbpp_assets_statistics USING btree (indicator, network, created_at_unixtimestamp);


--
-- Name: index_on_udt_id_and_unixtimestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_on_udt_id_and_unixtimestamp ON public.udt_hourly_statistics USING btree (udt_id, created_at_unixtimestamp);


--
-- Name: index_portfolios_on_user_id_and_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_portfolios_on_user_id_and_address_id ON public.portfolios USING btree (user_id, address_id);


--
-- Name: index_reject_reasons_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reject_reasons_on_ckb_transaction_id ON public.reject_reasons USING btree (ckb_transaction_id);


--
-- Name: index_rgbpp_hourly_statistics_on_created_at_unixtimestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rgbpp_hourly_statistics_on_created_at_unixtimestamp ON public.rgbpp_hourly_statistics USING btree (created_at_unixtimestamp);


--
-- Name: index_rolling_avg_block_time_on_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rolling_avg_block_time_on_timestamp ON public.rolling_avg_block_time USING btree ("timestamp");


--
-- Name: index_ssri_contracts_on_contract_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ssri_contracts_on_contract_id ON public.ssri_contracts USING btree (contract_id);


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
-- Name: index_type_scripts_on_code_hash_and_hash_type_and_args; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_type_scripts_on_code_hash_and_hash_type_and_args ON public.type_scripts USING btree (code_hash, hash_type, args);


--
-- Name: index_type_scripts_on_script_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_type_scripts_on_script_hash ON public.type_scripts USING btree (script_hash);


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
-- Name: index_udt_holder_allocations_on_udt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_udt_holder_allocations_on_udt_id ON public.udt_holder_allocations USING btree (udt_id);


--
-- Name: index_udt_transactions_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_udt_transactions_on_ckb_transaction_id ON public.udt_transactions USING btree (ckb_transaction_id);


--
-- Name: index_udt_transactions_on_udt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_udt_transactions_on_udt_id ON public.udt_transactions USING btree (udt_id);


--
-- Name: index_udt_verifications_on_udt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_udt_verifications_on_udt_id ON public.udt_verifications USING btree (udt_id);


--
-- Name: index_udt_verifications_on_udt_type_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_udt_verifications_on_udt_type_hash ON public.udt_verifications USING btree (udt_type_hash);


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
-- Name: index_users_on_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_identifier ON public.users USING btree (identifier);


--
-- Name: index_users_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_uuid ON public.users USING btree (uuid);


--
-- Name: index_vouts_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_vouts_uniqueness ON public.bitcoin_vouts USING btree (bitcoin_transaction_id, index, cell_output_id);


--
-- Name: index_witnesses_on_ckb_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_witnesses_on_ckb_transaction_id ON public.witnesses USING btree (ckb_transaction_id);


--
-- Name: index_witnesses_on_ckb_transaction_id_and_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_witnesses_on_ckb_transaction_id_and_index ON public.witnesses USING btree (ckb_transaction_id, index);


--
-- Name: index_xudt_tags_on_udt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_xudt_tags_on_udt_id ON public.xudt_tags USING btree (udt_id);


--
-- Name: pk; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pk ON public.udt_transactions USING btree (udt_id, ckb_transaction_id);


--
-- Name: cell_outputs_dead_address_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_address_id ATTACH PARTITION public.cell_outputs_dead_address_id_idx;


--
-- Name: cell_outputs_dead_block_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_block_id ATTACH PARTITION public.cell_outputs_dead_block_id_idx;


--
-- Name: cell_outputs_dead_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_block_timestamp ATTACH PARTITION public.cell_outputs_dead_block_timestamp_idx;


--
-- Name: cell_outputs_dead_ckb_transaction_id_cell_index_status_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_tx_id_and_cell_index_and_status ATTACH PARTITION public.cell_outputs_dead_ckb_transaction_id_cell_index_status_idx;


--
-- Name: cell_outputs_dead_consumed_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_consumed_block_timestamp ATTACH PARTITION public.cell_outputs_dead_consumed_block_timestamp_idx;


--
-- Name: cell_outputs_dead_consumed_by_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_consumed_by_id ATTACH PARTITION public.cell_outputs_dead_consumed_by_id_idx;


--
-- Name: cell_outputs_dead_lock_script_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_lock_script_id ATTACH PARTITION public.cell_outputs_dead_lock_script_id_idx;


--
-- Name: cell_outputs_dead_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.cell_outputs_pkey ATTACH PARTITION public.cell_outputs_dead_pkey;


--
-- Name: cell_outputs_dead_tx_hash_cell_index_status_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_tx_hash_and_cell_index_and_status ATTACH PARTITION public.cell_outputs_dead_tx_hash_cell_index_status_idx;


--
-- Name: cell_outputs_dead_type_script_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_type_script_id ATTACH PARTITION public.cell_outputs_dead_type_script_id_idx;


--
-- Name: cell_outputs_live_address_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_address_id ATTACH PARTITION public.cell_outputs_live_address_id_idx;


--
-- Name: cell_outputs_live_block_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_block_id ATTACH PARTITION public.cell_outputs_live_block_id_idx;


--
-- Name: cell_outputs_live_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_block_timestamp ATTACH PARTITION public.cell_outputs_live_block_timestamp_idx;


--
-- Name: cell_outputs_live_ckb_transaction_id_cell_index_status_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_tx_id_and_cell_index_and_status ATTACH PARTITION public.cell_outputs_live_ckb_transaction_id_cell_index_status_idx;


--
-- Name: cell_outputs_live_consumed_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_consumed_block_timestamp ATTACH PARTITION public.cell_outputs_live_consumed_block_timestamp_idx;


--
-- Name: cell_outputs_live_consumed_by_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_consumed_by_id ATTACH PARTITION public.cell_outputs_live_consumed_by_id_idx;


--
-- Name: cell_outputs_live_lock_script_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_lock_script_id ATTACH PARTITION public.cell_outputs_live_lock_script_id_idx;


--
-- Name: cell_outputs_live_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.cell_outputs_pkey ATTACH PARTITION public.cell_outputs_live_pkey;


--
-- Name: cell_outputs_live_tx_hash_cell_index_status_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_tx_hash_and_cell_index_and_status ATTACH PARTITION public.cell_outputs_live_tx_hash_cell_index_status_idx;


--
-- Name: cell_outputs_live_type_script_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_type_script_id ATTACH PARTITION public.cell_outputs_live_type_script_id_idx;


--
-- Name: cell_outputs_pending_address_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_address_id ATTACH PARTITION public.cell_outputs_pending_address_id_idx;


--
-- Name: cell_outputs_pending_block_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_block_id ATTACH PARTITION public.cell_outputs_pending_block_id_idx;


--
-- Name: cell_outputs_pending_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_block_timestamp ATTACH PARTITION public.cell_outputs_pending_block_timestamp_idx;


--
-- Name: cell_outputs_pending_ckb_transaction_id_cell_index_status_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_tx_id_and_cell_index_and_status ATTACH PARTITION public.cell_outputs_pending_ckb_transaction_id_cell_index_status_idx;


--
-- Name: cell_outputs_pending_consumed_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_consumed_block_timestamp ATTACH PARTITION public.cell_outputs_pending_consumed_block_timestamp_idx;


--
-- Name: cell_outputs_pending_consumed_by_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_consumed_by_id ATTACH PARTITION public.cell_outputs_pending_consumed_by_id_idx;


--
-- Name: cell_outputs_pending_lock_script_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_lock_script_id ATTACH PARTITION public.cell_outputs_pending_lock_script_id_idx;


--
-- Name: cell_outputs_pending_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.cell_outputs_pkey ATTACH PARTITION public.cell_outputs_pending_pkey;


--
-- Name: cell_outputs_pending_tx_hash_cell_index_status_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_tx_hash_and_cell_index_and_status ATTACH PARTITION public.cell_outputs_pending_tx_hash_cell_index_status_idx;


--
-- Name: cell_outputs_pending_type_script_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_type_script_id ATTACH PARTITION public.cell_outputs_pending_type_script_id_idx;


--
-- Name: cell_outputs_rejected_address_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_address_id ATTACH PARTITION public.cell_outputs_rejected_address_id_idx;


--
-- Name: cell_outputs_rejected_block_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_block_id ATTACH PARTITION public.cell_outputs_rejected_block_id_idx;


--
-- Name: cell_outputs_rejected_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_block_timestamp ATTACH PARTITION public.cell_outputs_rejected_block_timestamp_idx;


--
-- Name: cell_outputs_rejected_ckb_transaction_id_cell_index_status_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_tx_id_and_cell_index_and_status ATTACH PARTITION public.cell_outputs_rejected_ckb_transaction_id_cell_index_status_idx;


--
-- Name: cell_outputs_rejected_consumed_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_consumed_block_timestamp ATTACH PARTITION public.cell_outputs_rejected_consumed_block_timestamp_idx;


--
-- Name: cell_outputs_rejected_consumed_by_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_consumed_by_id ATTACH PARTITION public.cell_outputs_rejected_consumed_by_id_idx;


--
-- Name: cell_outputs_rejected_lock_script_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_lock_script_id ATTACH PARTITION public.cell_outputs_rejected_lock_script_id_idx;


--
-- Name: cell_outputs_rejected_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.cell_outputs_pkey ATTACH PARTITION public.cell_outputs_rejected_pkey;


--
-- Name: cell_outputs_rejected_tx_hash_cell_index_status_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_tx_hash_and_cell_index_and_status ATTACH PARTITION public.cell_outputs_rejected_tx_hash_cell_index_status_idx;


--
-- Name: cell_outputs_rejected_type_script_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_cell_outputs_on_type_script_id ATTACH PARTITION public.cell_outputs_rejected_type_script_id_idx;


--
-- Name: ckb_transactions_committed_block_id_block_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ckb_txs_for_blocks ATTACH PARTITION public.ckb_transactions_committed_block_id_block_timestamp_idx;


--
-- Name: ckb_transactions_committed_block_number_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_block_number ATTACH PARTITION public.ckb_transactions_committed_block_number_idx;


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
-- Name: ckb_transactions_pending_block_number_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_block_number ATTACH PARTITION public.ckb_transactions_pending_block_number_idx;


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
-- Name: ckb_transactions_proposed_block_number_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_block_number ATTACH PARTITION public.ckb_transactions_proposed_block_number_idx;


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
-- Name: ckb_transactions_rejected_block_number_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_ckb_transactions_on_block_number ATTACH PARTITION public.ckb_transactions_rejected_block_number_idx;


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
('20230630112234'),
('20230711040233'),
('20230802015907'),
('20230808020637'),
('20230829061910'),
('20230913091025'),
('20230914120928'),
('20230918033957'),
('20231017023456'),
('20231017024100'),
('20231017074221'),
('20231218082938'),
('20240107100346'),
('20240118103947'),
('20240119131328'),
('20240205023511'),
('20240205024238'),
('20240228072407'),
('20240228102716'),
('20240301025505'),
('20240305100337'),
('20240311143030'),
('20240312050057'),
('20240313075641'),
('20240315015432'),
('20240330023445'),
('20240407100517'),
('20240408024145'),
('20240408065818'),
('20240408075718'),
('20240408082159'),
('20240415080556'),
('20240428085020'),
('20240429102325'),
('20240507041552'),
('20240509074313'),
('20240513055849'),
('20240620083123'),
('20240625032839'),
('20240704092919'),
('20240709131020'),
('20240709131132'),
('20240709131713'),
('20240709142013'),
('20240822024448'),
('20240823071323'),
('20240823071420'),
('20240902025657'),
('20240904043807'),
('20240918024407'),
('20240918024415'),
('20240918033146'),
('20240920094807'),
('20240924065539'),
('20241009081935'),
('20241012014906'),
('20241023055256'),
('20241023063536'),
('20241030023309'),
('20241105070340'),
('20241105070619'),
('20241106062022'),
('20241114074433'),
('20241119014652'),
('20241121073245'),
('20241125100650'),
('20241129000339'),
('20241129032447'),
('20241202072604'),
('20241205023729'),
('20241212022531'),
('20241213053309'),
('20241218085721'),
('20241223023654'),
('20241223060331'),
('20241225045757'),
('20241231022644'),
('20250103072945'),
('20250108053433'),
('20250126022459'),
('20250218062041'),
('20250311084903'),
('20250318021630'),
('20250402032340'),
('20250403090946'),
('20250408020030'),
('20250415063535'),
('20250418085300'),
('20250423042854'),
('20250423104930'),
('20250427105936'),
('20250429170657'),
('20250508112010'),
('20250513034909'),
('20250617013030'),
('20250617051653'),
('20250625024348'),
('20250708075759'),
('20250708082522'),
('20250715021620'),
('20250715022751'),
('20250715024716'),
('20250715024926'),
('20250715025723'),
('20250715034316'),
('20250715035736'),
('20250715043211'),
('20250826022054'),
('20250827065749'),
('20250930015526'),
('20251011011714'),
('20251013082609'),
('20251027053353'),
('20251027054232');


