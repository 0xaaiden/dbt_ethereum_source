{{
    config(
        materialized='table',
        file_format='parquet',
        alias='ensregistrywithfallback_call_isapprovedforall',
        pre_hook={
            'sql': 'create or replace function ens_ensregistrywithfallback_isapprovedforall_calldecodeudf as "io.iftech.sparkudf.hive.Ens_ENSRegistryWithFallback_isApprovedForAll_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.12.jar";'
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
        ens_ensregistrywithfallback_isapprovedforall_calldecodeudf(unhex_input, unhex_output, '{"type": "function", "name": "isApprovedForAll", "constant": true, "payable": false, "stateMutability": "view", "inputs": [{"name": "owner", "type": "address"}, {"name": "operator", "type": "address"}], "outputs": [{"name": "", "type": "bool"}]}', 'isApprovedForAll') as data
    from {{ ref('stg_traces') }}
    where to_address = lower("0x314159265dd8dbb310642f98f50c066173c1259b") and address_hash = abs(hash(lower("0x314159265dd8dbb310642f98f50c066173c1259b"))) % 10 and selector = "0xe985e9c5" and selector_hash = abs(hash("0xe985e9c5")) % 10

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
        data.input.owner as owner, data.input.operator as operator, data.output.output_0 as output_0
    from base
)

select /*+ REPARTITION(50) */ *
from final
