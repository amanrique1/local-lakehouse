{{ config(materialized='table') }}

SELECT DISTINCT
    country,
    continent,
    to_hex(md5(to_utf8(country))) AS country_key
FROM {{ ref("stg_territories") }}
