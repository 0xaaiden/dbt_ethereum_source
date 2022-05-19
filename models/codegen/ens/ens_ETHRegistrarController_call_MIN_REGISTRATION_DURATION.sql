{{
    config(
        materialized='table',
        file_format='parquet',
        alias='ethregistrarcontroller_call_min_registration_duration',
        pre_hook={
            'sql': 'create or replace function ens_ethregistrarcontroller_min_registration_duration_calldecodeudf as "io.iftech.sparkudf.hive.Ens_ETHRegistrarController_MIN_REGISTRATION_DURATION_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.12.jar";'
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
        ens_ethregistrarcontroller_min_registration_duration_calldecodeudf(unhex_input, unhex_output, '{"type": "function", "name": "MIN_REGISTRATION_DURATION", "constant": true, "payable": false, "stateMutability": "view", "inputs": [], "outputs": [{"name": "", "type": "uint256"}]}', 'MIN_REGISTRATION_DURATION') as data
    from {{ ref('stg_traces') }}
    where to_address = lower("0xF0AD5cAd05e10572EfcEB849f6Ff0c68f9700455") and address_hash = abs(hash(lower("0xF0AD5cAd05e10572EfcEB849f6Ff0c68f9700455"))) % 10 and selector = "0x8a95b09f" and selector_hash = abs(hash("0x8a95b09f")) % 10

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
