{{
    config(
        materialized='table',
        file_format='parquet',
        alias='wyvernexchangev1_call_guardedarrayreplace',
        pre_hook={
            'sql': 'create or replace function opensea_wyvernexchangev1_guardedarrayreplace_calldecodeudf as "io.iftech.sparkudf.hive.Opensea_WyvernExchangeV1_guardedArrayReplace_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.14.jar";'
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
        opensea_wyvernexchangev1_guardedarrayreplace_calldecodeudf(unhex_input, unhex_output, '{"type": "function", "name": "guardedArrayReplace", "constant": true, "payable": false, "stateMutability": "pure", "inputs": [{"name": "array", "type": "bytes"}, {"name": "desired", "type": "bytes"}, {"name": "mask", "type": "bytes"}], "outputs": [{"name": "", "type": "bytes"}]}', 'guardedArrayReplace') as data
    from {{ ref('stg_traces') }}
    where to_address = lower("0x7Be8076f4EA4A4AD08075C2508e481d6C946D12b") and address_hash = abs(hash(lower("0x7Be8076f4EA4A4AD08075C2508e481d6C946D12b"))) % 10 and selector = "0x239e83df" and selector_hash = abs(hash("0x239e83df")) % 10

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
        data.input.array as array, data.input.desired as desired, data.input.mask as mask, data.output.output_0 as output_0
    from base
)

select /*+ REPARTITION(50) */ *
from final
