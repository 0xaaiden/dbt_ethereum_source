{{
    config(
        materialized='table',
        file_format='parquet',
        alias='busdswap_call_exchange',
        pre_hook={
            'sql': 'create or replace function curve_busdswap_exchange_calldecodeudf as "io.iftech.sparkudf.hive.Curve_BUSDSwap_exchange_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.14.jar";'
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
        curve_busdswap_exchange_calldecodeudf(unhex_input, unhex_output, '{"type": "function", "name": "exchange", "constant": false, "payable": false, "inputs": [{"name": "i", "type": "int128"}, {"name": "j", "type": "int128"}, {"name": "dx", "type": "uint256"}, {"name": "min_dy", "type": "uint256"}], "outputs": []}', 'exchange') as data
    from {{ ref('stg_traces') }}
    where to_address = lower("0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27") and address_hash = abs(hash(lower("0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27"))) % 10 and selector = "0x3df02124" and selector_hash = abs(hash("0x3df02124")) % 10

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

select /*+ REPARTITION(50) */ *
from final
