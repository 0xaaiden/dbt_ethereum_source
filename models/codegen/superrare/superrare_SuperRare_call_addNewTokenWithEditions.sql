{{
    config(
        materialized='table',
        file_format='parquet',
        alias='superrare_call_addnewtokenwitheditions',
        pre_hook={
            'sql': 'create or replace function superrare_superrare_addnewtokenwitheditions_calldecodeudf as "io.iftech.sparkudf.hive.Superrare_SuperRare_addNewTokenWithEditions_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.1.jar";'
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
        superrare_superrare_addnewtokenwitheditions_calldecodeudf(unhex_input, unhex_output, '{"constant": false, "inputs": [{"name": "_uri", "type": "string"}, {"name": "_editions", "type": "uint256"}, {"name": "_salePrice", "type": "uint256"}], "name": "addNewTokenWithEditions", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function"}', 'addNewTokenWithEditions') as data
    from {{ ref('stg_ethereum__traces') }}
    where to_address = lower("0x41A322b28D0fF354040e2CbC676F0320d8c8850d")
    and address_hash = abs(hash(lower("0x41A322b28D0fF354040e2CbC676F0320d8c8850d"))) % 10
    and selector = "0x30783031"
    and selector_hash = abs(hash("0x30783031")) % 10

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
