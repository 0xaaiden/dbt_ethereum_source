{{
    config(
        materialized='table',
        file_format='parquet',
        alias='dusdswap_evt_tokenexchangeunderlying',
        pre_hook={
            'sql': 'create or replace function curve_dusdswap_tokenexchangeunderlying_eventdecodeudf as "io.iftech.sparkudf.hive.Curve_DUSDSwap_TokenExchangeUnderlying_EventDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.9.jar";'
        }
    )
}}

with base as (
    select
        block_number as evt_block_number,
        block_timestamp as evt_block_time,
        log_index as evt_index,
        transaction_hash as evt_tx_hash,
        address as contract_address,
        dt,
        curve_dusdswap_tokenexchangeunderlying_eventdecodeudf(unhex_data, topics_arr, '{"name": "TokenExchangeUnderlying", "inputs": [{"type": "address", "name": "buyer", "indexed": true}, {"type": "int128", "name": "sold_id", "indexed": false}, {"type": "uint256", "name": "tokens_sold", "indexed": false}, {"type": "int128", "name": "bought_id", "indexed": false}, {"type": "uint256", "name": "tokens_bought", "indexed": false}], "anonymous": false, "type": "event"}', 'TokenExchangeUnderlying') as data
    from {{ ref('stg_logs') }}
    where address = lower("0x8038C01A0390a8c547446a0b2c18fc9aEFEcc10c") and address_hash = abs(hash(lower("0x8038C01A0390a8c547446a0b2c18fc9aEFEcc10c"))) % 10 and selector = "0xd013ca23e77a65003c2c659c5442c00c805371b7fc1ebd4c206c41d1536bd90b" and selector_hash = abs(hash("0xd013ca23e77a65003c2c659c5442c00c805371b7fc1ebd4c206c41d1536bd90b")) % 10

    {% if is_incremental() %}
      and dt = '{{ var("dt") }}'
    {% endif %}
),

final as (
    select
        evt_block_number,
        evt_block_time,
        evt_index,
        evt_tx_hash,
        contract_address,
        dt,
        data.input.*
    from base
)

select /*+ REPARTITION(50) */ *
from final
