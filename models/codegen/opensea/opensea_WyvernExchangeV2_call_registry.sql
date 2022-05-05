{{
    config(
        materialized='table',
        file_format='parquet',
        alias='wyvernexchangev2_call_registry',
        pre_hook={
            'sql': 'create or replace function opensea_wyvernexchangev2_registry_calldecodeudf as "io.iftech.sparkudf.hive.Opensea_WyvernExchangeV2_registry_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.8.jar";'
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
        opensea_wyvernexchangev2_registry_calldecodeudf(unhex_input, unhex_output, '{"constant": true, "inputs": [], "name": "registry", "outputs": [{"name": "", "type": "address"}], "payable": false, "stateMutability": "view", "type": "function"}', 'registry') as data
    from {{ ref('stg_traces') }}
    where to_address = lower("0x7f268357A8c2552623316e2562D90e642bB538E5") and address_hash = abs(hash(lower("0x7f268357A8c2552623316e2562D90e642bB538E5"))) % 10 and selector = "0x7b103999" and selector_hash = abs(hash("0x7b103999")) % 10

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
