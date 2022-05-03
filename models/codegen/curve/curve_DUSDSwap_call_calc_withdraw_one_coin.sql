{{
    config(
        materialized='table',
        file_format='parquet',
        alias='dusdswap_call_calc_withdraw_one_coin',
        pre_hook={
            'sql': 'create or replace function curve_dusdswap_calc_withdraw_one_coin_calldecodeudf as "io.iftech.sparkudf.hive.Curve_DUSDSwap_calc_withdraw_one_coin_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.5.jar";'
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
        curve_dusdswap_calc_withdraw_one_coin_calldecodeudf(unhex_input, unhex_output, '{"name": "calc_withdraw_one_coin", "outputs": [{"type": "uint256", "name": ""}], "inputs": [{"type": "uint256", "name": "_token_amount"}, {"type": "int128", "name": "i"}], "stateMutability": "view", "type": "function", "gas": 4389}', 'calc_withdraw_one_coin') as data
    from {{ ref('stg_traces') }}
    where to_address = lower("0x8038C01A0390a8c547446a0b2c18fc9aEFEcc10c")
    and address_hash = abs(hash(lower("0x8038C01A0390a8c547446a0b2c18fc9aEFEcc10c"))) % 10
    and selector = "0xcc2b27d7"
    and selector_hash = abs(hash("0xcc2b27d7")) % 10

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

select /*+ REPARTITION(1) */ *
from final
