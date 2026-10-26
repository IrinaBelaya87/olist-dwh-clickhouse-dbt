-- Деньги не бывают отрицательными: цена товара, доставка и платёж >= 0.
-- Тест возвращает строки-нарушители; если строк нет, тест пройден.
select 'order_items' as source_table, order_id, price as amount
from {{ ref('stg_order_items') }}
where price < 0 or freight_value < 0

union all

select 'order_payments' as source_table, order_id, payment_value as amount
from {{ ref('stg_order_payments') }}
where payment_value < 0
