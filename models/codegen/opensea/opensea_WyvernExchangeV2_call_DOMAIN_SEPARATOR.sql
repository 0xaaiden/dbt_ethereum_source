{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by=['dt'],
        file_format='parquet',
        alias='wyvernexchangev2_call_domain_separator',
        pre_hook={
            'sql': 'create or replace function opensea_wyvernexchangev2_domain_separator_calldecodeudf as "io.iftech.sparkudf.hive.Opensea_WyvernExchangeV2_DOMAIN_SEPARATOR_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.0.jar";'
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
        opensea_wyvernexchangev2_domain_separator_calldecodeudf(unhex_input, unhex_output, '{"constant": true, "inputs": [], "name": "DOMAIN_SEPARATOR", "outputs": [{"name": "", "type": "bytes32"}], "payable": false, "stateMutability": "view", "type": "function"}', 'DOMAIN_SEPARATOR') as data
    from {{ ref('stg_ethereum__traces') }}
    where to_address = lower("0x7f268357A8c2552623316e2562D90e642bB538E5")
    and address_hash = abs(hash(lower("0x7f268357A8c2552623316e2562D90e642bB538E5"))) % 10
    and selector = "0x30783336"
    and selector_hash = abs(hash("0x30783336")) % 10

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
