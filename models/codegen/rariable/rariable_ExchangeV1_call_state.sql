{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by=['dt'],
        file_format='parquet',
        pre_hook={
            'sql': 'create or replace function rariable_exchangev1_state_calldecodeudf as "io.iftech.sparkudf.hive.Rariable_ExchangeV1_state_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf.jar";'
        }
    )
}}

with base as (
    select
        status==1 as call_success,
        block_number as call_block_number,
        block_timestamp as call_block_time,
        trace_address as call_trace_address,
        transaction_hash as call_tx_hash,
        to_address as contract_address,
        dt,
        rariable_exchangev1_state_calldecodeudf(unhex_input, unhex_output, '{"constant": true, "inputs": [], "name": "state", "outputs": [{"internalType": "contract ExchangeStateV1", "name": "", "type": "address"}], "payable": false, "stateMutability": "view", "type": "function"}', 'state') as data
    from {{ ref('stg_ethereum__traces') }}
    where to_address = lower("0xcd4EC7b66fbc029C116BA9Ffb3e59351c20B5B06")
    and address_hash = abs(hash(lower("0xcd4EC7b66fbc029C116BA9Ffb3e59351c20B5B06"))) % 10
    and selector = "0x30786331"
    and selector_hash = abs(hash("0x30786331")) % 10

    {% if is_incremental() %}
      and dt = '{{ var("dt") }}'
    {% endif %}
),

final as (
    select
        call_success,
        call_block_number,
        call_block_time,
        call_trace_address,
        call_tx_hash,
        contract_address,
        dt,
        data.input.*,
        data.output.*
    from base
)

select /* REPARTITION(dt) */ *
from final