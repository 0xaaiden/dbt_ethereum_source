{{
    config(
        materialized='table',
        file_format='parquet',
        alias='openseaensresolver_call_setabi',
        pre_hook={
            'sql': 'create or replace function opensea_openseaensresolver_setabi_calldecodeudf as "io.iftech.sparkudf.hive.Opensea_OpenSeaENSResolver_setABI_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.9.jar";'
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
        opensea_openseaensresolver_setabi_calldecodeudf(unhex_input, unhex_output, '{"constant": false, "inputs": [{"name": "node", "type": "bytes32"}, {"name": "contentType", "type": "uint256"}, {"name": "data", "type": "bytes"}], "name": "setABI", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function"}', 'setABI') as data
    from {{ ref('stg_traces') }}
    where to_address = lower("0x9c4e9cce4780062942a7fe34fa2fa7316c872956") and address_hash = abs(hash(lower("0x9c4e9cce4780062942a7fe34fa2fa7316c872956"))) % 10 and selector = "0x623195b0" and selector_hash = abs(hash("0x623195b0")) % 10

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
