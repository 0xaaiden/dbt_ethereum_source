{{
    config(
        materialized='table',
        file_format='parquet',
        alias='linkusdswap_evt_newfee',
        pre_hook={
            'sql': 'create or replace function curve_linkusdswap_newfee_eventdecodeudf as "io.iftech.sparkudf.hive.Curve_LinkUSDSwap_NewFee_EventDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.8.jar";'
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
        curve_linkusdswap_newfee_eventdecodeudf(unhex_data, topics_arr, '{"name": "NewFee", "inputs": [{"type": "uint256", "name": "fee", "indexed": false}, {"type": "uint256", "name": "admin_fee", "indexed": false}], "anonymous": false, "type": "event"}', 'NewFee') as data
    from {{ ref('stg_logs') }}
    where address = lower("0xe7a24ef0c5e95ffb0f6684b813a78f2a3ad7d171") and address_hash = abs(hash(lower("0xe7a24ef0c5e95ffb0f6684b813a78f2a3ad7d171"))) % 10 and selector = "0xbe12859b636aed607d5230b2cc2711f68d70e51060e6cca1f575ef5d2fcc95d1" and selector_hash = abs(hash("0xbe12859b636aed607d5230b2cc2711f68d70e51060e6cca1f575ef5d2fcc95d1")) % 10

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
