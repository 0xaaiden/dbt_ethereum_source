{{
    config(
        materialized='table',
        file_format='parquet',
        alias='linkusdswap_evt_rampa',
        pre_hook={
            'sql': 'create or replace function curve_linkusdswap_rampa_eventdecodeudf as "io.iftech.sparkudf.hive.Curve_LinkUSDSwap_RampA_EventDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.2.jar";'
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
        curve_linkusdswap_rampa_eventdecodeudf(unhex_data, topics_arr, '{"name": "RampA", "inputs": [{"type": "uint256", "name": "old_A", "indexed": false}, {"type": "uint256", "name": "new_A", "indexed": false}, {"type": "uint256", "name": "initial_time", "indexed": false}, {"type": "uint256", "name": "future_time", "indexed": false}], "anonymous": false, "type": "event"}', 'RampA') as data
    from {{ ref('stg_logs') }}
    where address = lower("0xe7a24ef0c5e95ffb0f6684b813a78f2a3ad7d171")
    and address_hash = abs(hash(lower("0xe7a24ef0c5e95ffb0f6684b813a78f2a3ad7d171"))) % 10
    and selector = "0xa2b71ec6df949300b59aab36b55e189697b750119dd349fcfa8c0f779e83c254"
    and selector_hash = abs(hash("0xa2b71ec6df949300b59aab36b55e189697b750119dd349fcfa8c0f779e83c254")) % 10

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

select /* REPARTITION(1) */ *
from final