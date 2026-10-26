-- grain: 1 строка = 1 месяц покупки; только доставленные заказы
select
    toStartOfMonth(o.order_purchase_timestamp) as month,
    uniqExact(c.customer_unique_id) as buyers,
    count() as orders,
    sum(o.items_count) as items,
    sum(o.items_price) as revenue,
    toFloat64(orders)/buyers as orders_per_buyer,
    toFloat64(items)/orders as items_per_order,
    toFloat64(revenue)/items as avg_item_price,
    toFloat64(revenue)/orders as aov     
from {{ ref('fct_orders') }} o
join {{ ref('stg_customers') }} c on c.customer_id = o.customer_id
where o.order_status = 'delivered'
group by month
order by month