-- grain: 1 строка = 1 товар (product_id)
select
    p.product_id as product_id,
    p.product_category_name as product_category_name,
    coalesce(t.product_category_name_english, 'unknown') as product_category_en,
    p.product_weight_g as product_weight_g,
    p.product_length_cm as product_length_cm,
    p.product_height_cm as product_height_cm,
    p.product_width_cm as product_width_cm
from {{ ref('stg_products') }} p
left join {{ ref('stg_product_category_name_translation') }} t
    on t.product_category_name = p.product_category_name
settings join_use_nulls = 1