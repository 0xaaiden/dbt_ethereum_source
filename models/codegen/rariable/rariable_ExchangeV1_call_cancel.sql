{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by=['dt'],
        file_format='parquet',
        alias='exchangev1_call_cancel',
        pre_hook={
            'sql': 'create or replace function rariable_exchangev1_cancel_calldecodeudf as "io.iftech.sparkudf.hive.Rariable_ExchangeV1_cancel_CallDecodeUDF" using jar "s3a://blockchain-dbt/dist/jars/blockchain-dbt-udf-0.1.0.jar";'
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
        rariable_exchangev1_cancel_calldecodeudf(unhex_input, unhex_output, '{"constant": false, "inputs": [{"components": [{"internalType": "address", "name": "owner", "type": "address"}, {"internalType": "uint256", "name": "salt", "type": "uint256"}, {"components": [{"internalType": "address", "name": "token", "type": "address"}, {"internalType": "uint256", "name": "tokenId", "type": "uint256"}, {"internalType": "enum ExchangeDomainV1.AssetType", "name": "assetType", "type": "uint8"}], "internalType": "struct ExchangeDomainV1.Asset", "name": "sellAsset", "type": "tuple"}, {"components": [{"internalType": "address", "name": "token", "type": "address"}, {"internalType": "uint256", "name": "tokenId", "type": "uint256"}, {"internalType": "enum ExchangeDomainV1.AssetType", "name": "assetType", "type": "uint8"}], "internalType": "struct ExchangeDomainV1.Asset", "name": "buyAsset", "type": "tuple"}], "internalType": "struct ExchangeDomainV1.OrderKey", "name": "key", "type": "tuple"}], "name": "cancel", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function"}', 'cancel') as data
    from {{ ref('stg_ethereum__traces') }}
    where to_address = lower("0xcd4EC7b66fbc029C116BA9Ffb3e59351c20B5B06")
    and address_hash = abs(hash(lower("0xcd4EC7b66fbc029C116BA9Ffb3e59351c20B5B06"))) % 10
    and selector = "0x30786361"
    and selector_hash = abs(hash("0x30786361")) % 10

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
