{{ config(materialized='table') }}

SELECT
    p.product_name,
    p.product_sku,
    p.product_color,
    ps.subcategory_name,
    pc.category_name,
    to_hex(md5(to_utf8(cast(p.product_key AS VARCHAR)))) AS product_key
FROM {{ ref("stg_products") }} AS p
LEFT JOIN {{ ref("stg_product_subcategories") }} AS ps
    ON p.product_subcategory_key = ps.product_subcategory_key
LEFT JOIN {{ ref("stg_product_categories") }} AS pc
    ON ps.product_category_key = pc.product_category_key
