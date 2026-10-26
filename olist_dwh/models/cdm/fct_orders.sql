-- grain: 1 строка = 1 заказ
with orders as (
    select order_id, customer_id, order_status, order_purchase_timestamp
    from {{ ref('stg_orders') }}
),

items as (
    -- до соединения: 1 строка на order_id
    select
        order_id,
        count() as items_count,
        sum(price) as items_price,
        sum(freight_value) as freight_value
    from {{ ref('stg_order_items') }}
    group by order_id
),

payments as (
    select order_id, sum(payment_value) as sum_payment_value
    from {{ ref('stg_order_payments') }}
    group by order_id

)

select
    -- явный алиас: order_id есть во всех трёх CTE, без него ClickHouse назовёт колонку "o.order_id"
    o.order_id as order_id,
    o.customer_id, o.order_status, o.order_purchase_timestamp,
    i.items_count, i.items_price, i.freight_value,
    p.sum_payment_value   
from orders o
left join items i on i.order_id = o.order_id
left join payments p on p.order_id = o.order_id
settings join_use_nulls = 1