--- Select latest epoch parameters
select 
        * 
    from 
        epoch_param ep 
    order by 
        ep.epoch_no desc 
    limit 1;

--- Select assets by policy and apply filters by metadata
with asset as (
    select 
        ma_tx_mint.tx_id,
        encode(multi_asset.name, 'escape') as name,
        encode(multi_asset.policy, 'hex') as policy,
        multi_asset.fingerprint
    from
        multi_asset
    inner join 
        ma_tx_mint on
        ma_tx_mint.ident = multi_asset.id
    where
        multi_asset.policy = '\x8f80ebfaf62a8c33ae2adf047572604c74db8bc1daba2b43f9a65635'
    ),metadata as (
    select
        tx_metadata.tx_id,
        tx_metadata.json as metadata
    from
        tx_metadata
    where
        tx_metadata.tx_id in (select tx_id from asset)
    )
    select
        *,
        count(*) over () as count
    from
        asset
    inner join metadata on
        asset.tx_id = metadata.tx_id
    where
        jsonb_path_query_array(metadata.metadata,'$.*.*.type') ?| array['Orc']
	order by 
        asset.name asc
	limit 20 offset 0;

--- Select total assets by policy from stake address
select 
        sum(ma_tx_out.quantity) as quantity,
        encode(multi_asset.policy, 'hex') as policy
    from 
        utxo_view 
    inner join
        stake_address on stake_address.id = utxo_view.stake_address_id 
    inner join
        ma_tx_out on ma_tx_out.tx_out_id = utxo_view.id 
    inner join
        multi_asset on multi_asset.id = ma_tx_out.ident
    where
    	stake_address."view" = 'stake1u90nkx5yw6qkpas3kxa0wcql93axph8fetw20l0j2ntszucgg4rr2'
    	and
    	multi_asset.policy = '\xb7761c472eef3b6e0505441efaf940892bb59c01be96070b0a0a89b3'
    group by multi_asset.policy;

--- Select all assets from a stake address
select
        ma_tx_out.tx_out_id,
        ma_tx_out.quantity,
        encode(multi_asset.name, 'escape') as name,
        encode(multi_asset.policy, 'hex') as policy,
        multi_asset.fingerprint,
        tx_metadata.json as metadata,
        count(*) over () as count
    from
        utxo_view
    inner join
        stake_address on stake_address.id = utxo_view.stake_address_id 
    inner join
        ma_tx_out on ma_tx_out.tx_out_id = utxo_view.id
    inner join
        multi_asset on multi_asset.id = ma_tx_out.ident
    inner join
        ma_tx_mint on ma_tx_mint.ident = multi_asset.id
    inner join
        tx_metadata on tx_metadata.tx_id = ma_tx_mint.tx_id
    where 
		stake_address.view = 'stake1u90nkx5yw6qkpas3kxa0wcql93axph8fetw20l0j2ntszucgg4rr2'
	order by 
        multi_asset.name asc
	limit 20 offset 1;

--- Select all utxos from a stake address
select 
        tx_out.id,
        tx.hash,
        tx_out.index,
        tx_out.address,
        tx_out.value
    from
        tx_out
    left join
        tx_in on tx_out.tx_id = tx_in.tx_out_id and tx_out.index::smallint = tx_in.tx_out_index::smallint 
    left join
        tx on tx.id = tx_out.tx_id 
    left join
        block on tx.block_id = block.id 
    inner join
        stake_address on stake_address.id = tx_out.stake_address_id
    where
        tx_in.tx_in_id is null and
        block.epoch_no is not null and
        stake_address.view = 'stake1u90nkx5yw6qkpas3kxa0wcql93axph8fetw20l0j2ntszucgg4rr2';

--- Select slot number of the most recent block
select 
        slot_no 
    from
        block
    where
        block_no is not null
    order by
        block_no desc 
    limit 1;

--- Select current valid pools
select 
        *
    from
        pool_update
    where
        registered_tx_id in (select max(registered_tx_id) from pool_update group by hash_id)
        and 
        not exists(
            select 
                *
            from
                pool_retire
            where
                pool_retire.hash_id = pool_update.hash_id
                and
                pool_retire.retiring_epoch <= (select max (epoch_no) from block)
        );

--- Select the stake address for a given Shelley address
select 
        stake_address.id as stake_address_id, 
        tx_out.address, 
        stake_address.view as stake_address
	from 
        tx_out 
    inner join 
        stake_address on tx_out.stake_address_id = stake_address.id
	where 
        address = 'addr1q8u4wgd8qplhxpt4xm2l8yagy5ng7veurwrns2ysh03zuh2l8vdgga5pvrmprvd67asp7tr6vrwwnjku5l7ly4xhq9esr9h59t';

--- Select transaction outputs for specified transaction hash
select 
        tx_out.* 
    from
        tx_out
    inner join
        tx on tx_out.tx_id = tx.id
    where 
        tx.hash = '\xabd21556d9bb817d436e33a5fa32619702633dc809e707a5297566e9d74d57c1';