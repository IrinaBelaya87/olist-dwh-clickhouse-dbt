-- grain: 1 строка = 1 человек (customer_unique_id)
select
    c.customer_unique_id as customer_unique_id,
    count() as orders_count,
    min(o.order_purchase_timestamp) as first_order_at,
    max(o.order_purchase_timestamp) as last_order_at,
    -- город и штат из последнего заказа:
    argMax(c.customer_city, o.order_purchase_timestamp) as customer_city,
    argMax(c.customer_state, o.order_purchase_timestamp) as customer_state
from {{ ref('stg_customers') }} c
join {{ ref('fct_orders') }} o on o.customer_id = c.customer_id
group by c.customer_unique_id