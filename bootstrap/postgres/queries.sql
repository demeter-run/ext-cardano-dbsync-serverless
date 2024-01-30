-- create pg bouncer role and user_search function - add to each database

CREATE ROLE pgbouncer WITH PASSWORD 'pgbounceruserpass';

CREATE OR REPLACE FUNCTION user_search(uname TEXT) RETURNS TABLE (usename name, passwd text) as
$$
  SELECT usename, passwd FROM pg_shadow WHERE usename=$1;
$$
LANGUAGE sql SECURITY DEFINER;

-- enable pg_stat_statements - add to each database

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- dbsync indexes

CREATE UNIQUE INDEX IF NOT EXISTS ada_pots_pkey ON public.ada_pots USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_ada_pots ON public.ada_pots USING btree (block_id);

  

CREATE INDEX IF NOT EXISTS bf_idx_block_hash_encoded ON public.block USING hash (encode((hash)::bytea, 'hex'::text));

  

CREATE UNIQUE INDEX IF NOT EXISTS block_pkey ON public.block USING btree (id);

  

CREATE INDEX IF NOT EXISTS idx_block_block_no ON public.block USING btree (block_no);

  

CREATE INDEX IF NOT EXISTS idx_block_epoch_no ON public.block USING btree (epoch_no);

  

CREATE INDEX IF NOT EXISTS idx_block_previous_id ON public.block USING btree (previous_id);

  

CREATE INDEX IF NOT EXISTS idx_block_slot_leader_id ON public.block USING btree (slot_leader_id);

  

CREATE INDEX IF NOT EXISTS idx_block_slot_no ON public.block USING btree (slot_no);

  

CREATE INDEX IF NOT EXISTS idx_block_time ON public.block USING btree ("time");

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_block ON public.block USING btree (hash);

  

CREATE INDEX IF NOT EXISTS bf_idx_datum_hash ON public.datum USING hash (encode((hash)::bytea, 'hex'::text));

  

CREATE UNIQUE INDEX IF NOT EXISTS datum_pkey ON public.datum USING btree (id);

  

CREATE INDEX IF NOT EXISTS idx_datum_tx_id ON public.datum USING btree (tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_datum ON public.datum USING btree (hash);

  

CREATE INDEX IF NOT EXISTS bf_idx_multi_asset_policy ON public.multi_asset USING hash (encode((policy)::bytea, 'hex'::text));

  

CREATE INDEX IF NOT EXISTS bf_idx_multi_asset_policy_name ON public.multi_asset USING hash (((encode((policy)::bytea, 'hex'::text) || encode((name)::bytea, 'hex'::text))));

  

CREATE INDEX IF NOT EXISTS idx_asset_id ON public.multi_asset USING btree ((((policy)::bytea || (name)::bytea)));

  

CREATE INDEX IF NOT EXISTS multi_asset_fingerprint ON public.multi_asset USING btree (fingerprint);

  

CREATE UNIQUE INDEX IF NOT EXISTS multi_asset_pkey ON public.multi_asset USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_multi_asset ON public.multi_asset USING btree (policy, name);

  

CREATE INDEX IF NOT EXISTS bf_idx_pool_hash_view ON public.pool_hash USING hash (view);

  

CREATE UNIQUE INDEX IF NOT EXISTS pool_hash_pkey ON public.pool_hash USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_pool_hash ON public.pool_hash USING btree (hash_raw);

  

CREATE INDEX IF NOT EXISTS bf_idx_redeemer_data_hash ON public.redeemer_data USING hash (encode((hash)::bytea, 'hex'::text));

  

CREATE UNIQUE INDEX IF NOT EXISTS redeemer_data_pkey ON public.redeemer_data USING btree (id);

  

CREATE INDEX IF NOT EXISTS redeemer_data_tx_id_idx ON public.redeemer_data USING btree (tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_redeemer_data ON public.redeemer_data USING btree (hash);

  

CREATE INDEX IF NOT EXISTS bf_idx_scripts_hash ON public.script USING hash (encode((hash)::bytea, 'hex'::text));

  

CREATE INDEX IF NOT EXISTS idx_script_tx_id ON public.script USING btree (tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS script_pkey ON public.script USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_script ON public.script USING btree (hash);

  

CREATE INDEX IF NOT EXISTS bf_idx_tx_hash ON public.tx USING hash (encode((hash)::bytea, 'hex'::text));

  

CREATE INDEX IF NOT EXISTS idx_tx_block_id ON public.tx USING btree (block_id);

  

CREATE INDEX IF NOT EXISTS idx_tx_valid_contract ON public.tx USING btree (valid_contract);

  

CREATE UNIQUE INDEX IF NOT EXISTS tx_pkey ON public.tx USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_tx ON public.tx USING btree (hash);

  

CREATE UNIQUE INDEX IF NOT EXISTS bf_u_idx_epoch_stake_epoch_and_id ON public.epoch_stake USING btree (epoch_no, id);

  

CREATE UNIQUE INDEX IF NOT EXISTS epoch_stake_pkey ON public.epoch_stake USING btree (id);

  

CREATE INDEX IF NOT EXISTS idx_epoch_stake_addr_id ON public.epoch_stake USING btree (addr_id);

  

CREATE INDEX IF NOT EXISTS idx_epoch_stake_epoch_no ON public.epoch_stake USING btree (epoch_no);

  

CREATE INDEX IF NOT EXISTS idx_epoch_stake_pool_id ON public.epoch_stake USING btree (pool_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_stake ON public.epoch_stake USING btree (epoch_no, addr_id, pool_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS collateral_tx_in_pkey ON public.collateral_tx_in USING btree (id);

  

CREATE INDEX IF NOT EXISTS idx_collateral_tx_in_tx_out_id ON public.collateral_tx_in USING btree (tx_out_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_col_txin ON public.collateral_tx_in USING btree (tx_in_id, tx_out_id, tx_out_index);

  

CREATE INDEX IF NOT EXISTS collateral_tx_out_inline_datum_id_idx ON public.collateral_tx_out USING btree (inline_datum_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS collateral_tx_out_pkey ON public.collateral_tx_out USING btree (id);

  

CREATE INDEX IF NOT EXISTS collateral_tx_out_reference_script_id_idx ON public.collateral_tx_out USING btree (reference_script_id);

  

CREATE INDEX IF NOT EXISTS collateral_tx_out_stake_address_id_idx ON public.collateral_tx_out USING btree (stake_address_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_col_txout ON public.collateral_tx_out USING btree (tx_id, index);

  

CREATE UNIQUE INDEX IF NOT EXISTS delegation_pkey ON public.delegation USING btree (id);

  

CREATE INDEX IF NOT EXISTS idx_delegation_active_epoch_no ON public.delegation USING btree (active_epoch_no);

  

CREATE INDEX IF NOT EXISTS idx_delegation_addr_id ON public.delegation USING btree (addr_id);

  

CREATE INDEX IF NOT EXISTS idx_delegation_pool_hash_id ON public.delegation USING btree (pool_hash_id);

  

CREATE INDEX IF NOT EXISTS idx_delegation_redeemer_id ON public.delegation USING btree (redeemer_id);

  

CREATE INDEX IF NOT EXISTS idx_delegation_tx_id ON public.delegation USING btree (tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_delegation ON public.delegation USING btree (tx_id, cert_index);

  

CREATE UNIQUE INDEX IF NOT EXISTS delisted_pool_pkey ON public.delisted_pool USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_delisted_pool ON public.delisted_pool USING btree (hash_raw);

  

CREATE UNIQUE INDEX IF NOT EXISTS epoch_pkey ON public.epoch USING btree (id);

  

CREATE INDEX IF NOT EXISTS idx_epoch_no ON public.epoch USING btree (no);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_epoch ON public.epoch USING btree (no);

  

CREATE UNIQUE INDEX IF NOT EXISTS epoch_sync_time_pkey ON public.epoch_sync_time USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_epoch_sync_time ON public.epoch_sync_time USING btree (no);

  

CREATE UNIQUE INDEX IF NOT EXISTS extra_key_witness_pkey ON public.extra_key_witness USING btree (id);

  

CREATE INDEX IF NOT EXISTS idx_extra_key_witness_tx_id ON public.extra_key_witness USING btree (tx_id);

  

CREATE INDEX IF NOT EXISTS idx_ma_tx_mint_tx_id ON public.ma_tx_mint USING btree (tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS ma_tx_mint_pkey ON public.ma_tx_mint USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_ma_tx_mint ON public.ma_tx_mint USING btree (ident, tx_id);

  

CREATE INDEX IF NOT EXISTS idx_param_proposal_cost_model_id ON public.param_proposal USING btree (cost_model_id);

  

CREATE INDEX IF NOT EXISTS idx_param_proposal_registered_tx_id ON public.param_proposal USING btree (registered_tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS param_proposal_pkey ON public.param_proposal USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_param_proposal ON public.param_proposal USING btree (key, registered_tx_id);

  

CREATE INDEX IF NOT EXISTS idx_pool_metadata_ref_registered_tx_id ON public.pool_metadata_ref USING btree (registered_tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS pool_metadata_ref_pkey ON public.pool_metadata_ref USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_pool_metadata_ref ON public.pool_metadata_ref USING btree (pool_id, url, hash);

  

CREATE INDEX IF NOT EXISTS idx_pool_offline_data_pmr_id ON public.pool_offline_data USING btree (pmr_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS pool_offline_data_pkey ON public.pool_offline_data USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_pool_offline_data ON public.pool_offline_data USING btree (pool_id, hash);

  

CREATE INDEX IF NOT EXISTS idx_pool_offline_fetch_error_pmr_id ON public.pool_offline_fetch_error USING btree (pmr_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS pool_offline_fetch_error_pkey ON public.pool_offline_fetch_error USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_pool_offline_fetch_error ON public.pool_offline_fetch_error USING btree (pool_id, fetch_time, retry_count);

  

CREATE INDEX IF NOT EXISTS idx_pool_relay_update_id ON public.pool_relay USING btree (update_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS pool_relay_pkey ON public.pool_relay USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_pool_relay ON public.pool_relay USING btree (update_id, ipv4, ipv6, dns_name);

  

CREATE INDEX IF NOT EXISTS idx_pool_retire_announced_tx_id ON public.pool_retire USING btree (announced_tx_id);

  

CREATE INDEX IF NOT EXISTS idx_pool_retire_hash_id ON public.pool_retire USING btree (hash_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS pool_retire_pkey ON public.pool_retire USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_pool_retiring ON public.pool_retire USING btree (announced_tx_id, cert_index);

  

CREATE INDEX IF NOT EXISTS idx_pool_update_active_epoch_no ON public.pool_update USING btree (active_epoch_no);

  

CREATE INDEX IF NOT EXISTS idx_pool_update_hash_id ON public.pool_update USING btree (hash_id);

  

CREATE INDEX IF NOT EXISTS idx_pool_update_meta_id ON public.pool_update USING btree (meta_id);

  

CREATE INDEX IF NOT EXISTS idx_pool_update_registered_tx_id ON public.pool_update USING btree (registered_tx_id);

  

CREATE INDEX IF NOT EXISTS idx_pool_update_reward_addr ON public.pool_update USING btree (reward_addr_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS pool_update_pkey ON public.pool_update USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_pool_update ON public.pool_update USING btree (registered_tx_id, cert_index);

  

CREATE INDEX IF NOT EXISTS idx_reserve_addr_id ON public.reserve USING btree (addr_id);

  

CREATE INDEX IF NOT EXISTS idx_reserve_tx_id ON public.reserve USING btree (tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS reserve_pkey ON public.reserve USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_reserves ON public.reserve USING btree (addr_id, tx_id, cert_index);

  

CREATE INDEX IF NOT EXISTS idx_reserved_pool_ticker_pool_hash ON public.reserved_pool_ticker USING btree (pool_hash);

  

CREATE UNIQUE INDEX IF NOT EXISTS reserved_pool_ticker_pkey ON public.reserved_pool_ticker USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_reserved_pool_ticker ON public.reserved_pool_ticker USING btree (name);

  

CREATE INDEX IF NOT EXISTS idx_reward_addr_id ON public.reward USING btree (addr_id);

  

CREATE INDEX IF NOT EXISTS idx_reward_earned_epoch ON public.reward USING btree (earned_epoch);

  

CREATE INDEX IF NOT EXISTS idx_reward_pool_id ON public.reward USING btree (pool_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS reward_pkey ON public.reward USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_reward ON public.reward USING btree (addr_id, type, earned_epoch, pool_id);

  

CREATE INDEX IF NOT EXISTS idx_slot_leader_pool_hash_id ON public.slot_leader USING btree (pool_hash_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS slot_leader_pkey ON public.slot_leader USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_slot_leader ON public.slot_leader USING btree (hash);

  

CREATE INDEX IF NOT EXISTS idx_stake_address_hash_raw ON public.stake_address USING btree (hash_raw);

  

CREATE INDEX IF NOT EXISTS idx_stake_address_view ON public.stake_address USING hash (view);

  

CREATE UNIQUE INDEX IF NOT EXISTS stake_address_pkey ON public.stake_address USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_stake_address ON public.stake_address USING btree (hash_raw);

  

CREATE INDEX IF NOT EXISTS idx_stake_deregistration_addr_id ON public.stake_deregistration USING btree (addr_id);

  

CREATE INDEX IF NOT EXISTS idx_stake_deregistration_redeemer_id ON public.stake_deregistration USING btree (redeemer_id);

  

CREATE INDEX IF NOT EXISTS idx_stake_deregistration_tx_id ON public.stake_deregistration USING btree (tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS stake_deregistration_pkey ON public.stake_deregistration USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_stake_deregistration ON public.stake_deregistration USING btree (tx_id, cert_index);

  

CREATE INDEX IF NOT EXISTS idx_stake_registration_addr_id ON public.stake_registration USING btree (addr_id);

  

CREATE INDEX IF NOT EXISTS idx_stake_registration_tx_id ON public.stake_registration USING btree (tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS stake_registration_pkey ON public.stake_registration USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_stake_registration ON public.stake_registration USING btree (tx_id, cert_index);

  

CREATE INDEX IF NOT EXISTS idx_treasury_addr_id ON public.treasury USING btree (addr_id);

  

CREATE INDEX IF NOT EXISTS idx_treasury_tx_id ON public.treasury USING btree (tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS treasury_pkey ON public.treasury USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_treasury ON public.treasury USING btree (addr_id, tx_id, cert_index);

  

CREATE INDEX IF NOT EXISTS idx_tx_in_redeemer_id ON public.tx_in USING btree (redeemer_id);

  

CREATE INDEX IF NOT EXISTS idx_tx_in_source_tx ON public.tx_in USING btree (tx_in_id);

  

CREATE INDEX IF NOT EXISTS idx_tx_in_tx_in_id ON public.tx_in USING btree (tx_in_id);

  

CREATE INDEX IF NOT EXISTS idx_tx_in_tx_out_id ON public.tx_in USING btree (tx_out_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS tx_in_pkey ON public.tx_in USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_txin ON public.tx_in USING btree (tx_out_id, tx_out_index);

  

CREATE INDEX IF NOT EXISTS idx_tx_metadata_json_prefix ON public.tx_metadata USING btree ("substring"((json)::text, 2, 38) text_pattern_ops);

  

CREATE INDEX IF NOT EXISTS idx_tx_metadata_tx_id ON public.tx_metadata USING btree (tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS tx_metadata_pkey ON public.tx_metadata USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_tx_metadata ON public.tx_metadata USING btree (key, tx_id);

  

CREATE INDEX IF NOT EXISTS idx_withdrawal_addr_id ON public.withdrawal USING btree (addr_id);

  

CREATE INDEX IF NOT EXISTS idx_withdrawal_redeemer_id ON public.withdrawal USING btree (redeemer_id);

  

CREATE INDEX IF NOT EXISTS idx_withdrawal_tx_id ON public.withdrawal USING btree (tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_withdrawal ON public.withdrawal USING btree (addr_id, tx_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS withdrawal_pkey ON public.withdrawal USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS meta_pkey ON public.meta USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_meta ON public.meta USING btree (start_time);

  

CREATE UNIQUE INDEX IF NOT EXISTS pool_owner_pkey ON public.pool_owner USING btree (id);

  

CREATE INDEX IF NOT EXISTS pool_owner_pool_update_id_idx ON public.pool_owner USING btree (pool_update_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_pool_owner ON public.pool_owner USING btree (addr_id, pool_update_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS pot_transfer_pkey ON public.pot_transfer USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_pot_transfer ON public.pot_transfer USING btree (tx_id, cert_index);

  

CREATE UNIQUE INDEX IF NOT EXISTS redeemer_pkey ON public.redeemer USING btree (id);

  

CREATE INDEX IF NOT EXISTS redeemer_redeemer_data_id_idx ON public.redeemer USING btree (redeemer_data_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_redeemer ON public.redeemer USING btree (tx_id, purpose, index);

  

CREATE UNIQUE INDEX IF NOT EXISTS reference_tx_in_pkey ON public.reference_tx_in USING btree (id);

  

CREATE INDEX IF NOT EXISTS reference_tx_in_tx_out_id_idx ON public.reference_tx_in USING btree (tx_out_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_ref_txin ON public.reference_tx_in USING btree (tx_in_id, tx_out_id, tx_out_index);

  

CREATE UNIQUE INDEX IF NOT EXISTS schema_version_pkey ON public.schema_version USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS epoch_param_pkey ON public.epoch_param USING btree (id);

  

CREATE INDEX IF NOT EXISTS idx_epoch_param_block_id ON public.epoch_param USING btree (block_id);

  

CREATE INDEX IF NOT EXISTS idx_epoch_param_cost_model_id ON public.epoch_param USING btree (cost_model_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_epoch_param ON public.epoch_param USING btree (epoch_no, block_id);

  

CREATE INDEX IF NOT EXISTS idx_tx_out_address ON public.tx_out USING hash (address);

  

CREATE INDEX IF NOT EXISTS idx_tx_out_payment_cred ON public.tx_out USING btree (payment_cred);

  

CREATE INDEX IF NOT EXISTS idx_tx_out_stake_address_id ON public.tx_out USING btree (stake_address_id);

  

CREATE INDEX IF NOT EXISTS idx_tx_out_tx_id ON public.tx_out USING btree (tx_id);

  

CREATE INDEX IF NOT EXISTS tx_out_inline_datum_id_idx ON public.tx_out USING btree (inline_datum_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS tx_out_pkey ON public.tx_out USING btree (id);

  

CREATE INDEX IF NOT EXISTS tx_out_reference_script_id_idx ON public.tx_out USING btree (reference_script_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_txout ON public.tx_out USING btree (tx_id, index);

  

CREATE INDEX IF NOT EXISTS idx_ident ON public.ma_tx_out USING btree (ident);

  

CREATE INDEX IF NOT EXISTS idx_ma_tx_out_tx_out_id ON public.ma_tx_out USING btree (tx_out_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS ma_tx_out_pkey ON public.ma_tx_out USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_ma_tx_out ON public.ma_tx_out USING btree (ident, tx_out_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS epoch_param_pkey ON public.epoch_param USING btree (id);

  

CREATE INDEX IF NOT EXISTS idx_epoch_param_block_id ON public.epoch_param USING btree (block_id);

  

CREATE INDEX IF NOT EXISTS idx_epoch_param_cost_model_id ON public.epoch_param USING btree (cost_model_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_epoch_param ON public.epoch_param USING btree (epoch_no, block_id);

  

CREATE UNIQUE INDEX IF NOT EXISTS cost_model_pkey ON public.cost_model USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_cost_model ON public.cost_model USING btree (hash);

  

CREATE UNIQUE INDEX IF NOT EXISTS cost_model_pkey ON public.cost_model USING btree (id);

  

CREATE UNIQUE INDEX IF NOT EXISTS unique_cost_model ON public.cost_model USING btree (hash);



CREATE INDEX IF NOT EXISTS ma_tx_out_ident_index ON public.ma_tx_out (ident desc);