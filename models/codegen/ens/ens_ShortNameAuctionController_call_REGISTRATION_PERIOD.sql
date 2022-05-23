{{
    config(
        materialized='table',
        file_format='parquet',
        alias='shortnameauctioncontroller_call_registration_period',
        pre_hook={
            'sql': 'create or replace function ens_shortnameauctioncontroller_registration_period_calldecodeudf as "io.iftech.sparkudf.hive.Ens_ShortNameAuctionController_REGISTRATION_PERIOD_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.12.jar";'
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
        ens_shortnameauctioncontroller_registration_period_calldecodeudf(unhex_input, unhex_output, '{"type": "function", "name": "REGISTRATION_PERIOD", "constant": true, "payable": false, "stateMutability": "view", "inputs": [], "outputs": [{"name": "", "type": "uint256"}]}', 'REGISTRATION_PERIOD') as data
    from {{ ref('stg_traces') }}
    where to_address = lower("0x699C7F511C9e2182e89f29b3Bfb68bD327919D17") and address_hash = abs(hash(lower("0x699C7F511C9e2182e89f29b3Bfb68bD327919D17"))) % 10 and selector = "0xe0f54097" and selector_hash = abs(hash("0xe0f54097")) % 10

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
        data.output.output_0 as output_0
    from base
)

select /*+ REPARTITION(50) */ *
from final