-- Слой raw: загрузка CSV Olist в ClickHouse.
-- Загрузка идемпотентна: TRUNCATE перед INSERT, повторный запуск даёт тот же результат.
-- Запуск: docker exec -i ch clickhouse-client --user admin --password dev --multiquery < sql/01_raw.sql

CREATE DATABASE IF NOT EXISTS raw;
CREATE DATABASE IF NOT EXISTS stg;
CREATE DATABASE IF NOT EXISTS cdm;
CREATE DATABASE IF NOT EXISTS marts;

-- ---------------------------------------------------------------
-- raw.orders (ожидается 99 441 строка, order_id уникален)
-- Nullable только у дат, которые бывают пустыми у недоставленных заказов.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.orders
(
    order_id                       String,
    customer_id                    String,
    order_status                   String,
    order_purchase_timestamp       DateTime,
    order_approved_at              Nullable(DateTime),
    order_delivered_carrier_date   Nullable(DateTime),
    order_delivered_customer_date  Nullable(DateTime),
    order_estimated_delivery_date  DateTime
)
ENGINE = MergeTree
ORDER BY order_id;

TRUNCATE TABLE raw.orders;
INSERT INTO raw.orders SELECT * FROM file('olist/olist_orders_dataset.csv', CSVWithNames);

-- ---------------------------------------------------------------
-- raw.order_items (ожидается 112 650 строк)
-- Строка = товар в заказе; деньги в Decimal(10, 2), пустых значений нет.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.order_items
(
    order_id             String,
    order_item_id        Int64,
    product_id           String,
    seller_id            String,
    shipping_limit_date  DateTime,
    price                Decimal(10, 2),
    freight_value        Decimal(10, 2)
)
ENGINE = MergeTree
ORDER BY (order_id, order_item_id);

TRUNCATE TABLE raw.order_items;
INSERT INTO raw.order_items SELECT * FROM file('olist/olist_order_items_dataset.csv', CSVWithNames);

-- ---------------------------------------------------------------
-- raw.customers (ожидается 99 441 строка; 96 096 уникальных customer_unique_id)
-- customer_id выдаётся на каждый заказ, customer_unique_id обозначает человека.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.customers
(
    customer_id                String,
    customer_unique_id         String,
    customer_zip_code_prefix   String,
    customer_city              String,
    customer_state             String
)
ENGINE = MergeTree
ORDER BY customer_id;

TRUNCATE TABLE raw.customers;
INSERT INTO raw.customers SELECT * FROM file('olist/olist_customers_dataset.csv', CSVWithNames);

-- ---------------------------------------------------------------
-- raw.order_payments (ожидается 103 886 строк, 99 440 уникальных заказов)
-- Строка = платёж; на заказ бывает несколько платежей (карта + ваучер),
-- поэтому ключ (order_id, payment_sequential). Пустых значений нет.
-- Известная аномалия: у одного доставленного заказа
-- (bfbd0f9bdef84302105ad712db648a6c) платежей нет.
-- Поиск: LEFT ANTI JOIN, а не LEFT JOIN ... IS NULL: без join_use_nulls = 1
-- ClickHouse подставляет в несовпавшие строки '' вместо NULL.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.order_payments
(
    order_id              String,
    payment_sequential    Int64,
    payment_type          String,
    payment_installments  Int64,
    payment_value         Decimal(10, 2)
)
ENGINE = MergeTree
ORDER BY (order_id, payment_sequential);

TRUNCATE TABLE raw.order_payments;
INSERT INTO raw.order_payments SELECT * FROM file('olist/olist_order_payments_dataset.csv', CSVWithNames);

-- ---------------------------------------------------------------
-- raw.sellers (ожидается 3 095 строк, seller_id уникален)
-- Пустых значений нет; все seller_id из order_items есть в справочнике.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.sellers
(
    seller_id               String,
    seller_zip_code_prefix  String,
    seller_city             String,
    seller_state            String
)
ENGINE = MergeTree
ORDER BY seller_id;

TRUNCATE TABLE raw.sellers;
INSERT INTO raw.sellers SELECT * FROM file('olist/olist_sellers_dataset.csv', CSVWithNames);

-- ---------------------------------------------------------------
-- raw.products (ожидается 32 951 строка, product_id уникален)
-- Nullable: у 610 товаров нет категории, названия, описания и фото (одни и те же
-- товары), у 2 товаров нет габаритов. Все product_id из order_items есть в справочнике.
-- Опечатки в именах колонок (lenght) сохранены как в источнике; исправляем в stg.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.products
(
    product_id                  String,
    product_category_name       Nullable(String),
    product_name_lenght         Nullable(Int64),
    product_description_lenght  Nullable(Int64),
    product_photos_qty          Nullable(Int64),
    product_weight_g            Nullable(Int64),
    product_length_cm           Nullable(Int64),
    product_height_cm           Nullable(Int64),
    product_width_cm            Nullable(Int64)
)
ENGINE = MergeTree
ORDER BY product_id;

TRUNCATE TABLE raw.products;
INSERT INTO raw.products SELECT * FROM file('olist/olist_products_dataset.csv', CSVWithNames);

-- ---------------------------------------------------------------
-- raw.product_category_name_translation (ожидается 71 строка, категория уникальна)
-- Файл называется без префикса olist_ и без _dataset.
-- Известная неполнота: у двух категорий из products нет перевода
-- (pc_gamer, portateis_cozinha_e_preparadores_de_alimentos); закрываем в stg.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.product_category_name_translation
(
    product_category_name          String,
    product_category_name_english  String
)
ENGINE = MergeTree
ORDER BY product_category_name;

TRUNCATE TABLE raw.product_category_name_translation;
INSERT INTO raw.product_category_name_translation SELECT * FROM file('olist/product_category_name_translation.csv', CSVWithNames);

-- ---------------------------------------------------------------
-- Контрольные проверки после загрузки
-- ---------------------------------------------------------------
SELECT 'orders'         AS tbl, count() AS rows, uniqExact(order_id)    AS uniq_key FROM raw.orders
UNION ALL
SELECT 'order_items'    AS tbl, count() AS rows, uniqExact(order_id)    AS uniq_key FROM raw.order_items
UNION ALL
SELECT 'customers'      AS tbl, count() AS rows, uniqExact(customer_id) AS uniq_key FROM raw.customers
UNION ALL
SELECT 'order_payments' AS tbl, count() AS rows, uniqExact(order_id)    AS uniq_key FROM raw.order_payments
UNION ALL
SELECT 'sellers'        AS tbl, count() AS rows, uniqExact(seller_id)   AS uniq_key FROM raw.sellers
UNION ALL
SELECT 'products'       AS tbl, count() AS rows, uniqExact(product_id)  AS uniq_key FROM raw.products
UNION ALL
SELECT 'category_translation' AS tbl, count() AS rows, uniqExact(product_category_name) AS uniq_key FROM raw.product_category_name_translation;

-- Заказы без платежей (ожидается 1 строка, статус delivered)
SELECT o.order_id, o.order_status
FROM raw.orders o
LEFT ANTI JOIN raw.order_payments p ON p.order_id = o.order_id;
