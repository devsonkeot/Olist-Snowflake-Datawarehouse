-- Create a dedicated virtual warehouse (compute) for this project
CREATE WAREHOUSE IF NOT EXISTS DW_PROJECT_WH
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

USE WAREHOUSE DW_PROJECT_WH;

-- Create the database for this project
CREATE DATABASE IF NOT EXISTS ECOMMERCE_DW;
USE DATABASE ECOMMERCE_DW;

-- Two schemas: one for raw landing data, one for the modeled warehouse
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS ANALYTICS;




USE SCHEMA RAW;

CREATE OR REPLACE TABLE RAW_ORDERS (
    order_id STRING,
    customer_id STRING,
    order_status STRING,
    order_purchase_timestamp TIMESTAMP_NTZ,
    order_approved_at TIMESTAMP_NTZ,
    order_delivered_carrier_date TIMESTAMP_NTZ,
    order_delivered_customer_date TIMESTAMP_NTZ,
    order_estimated_delivery_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE RAW_ORDER_ITEMS (
    order_id STRING,
    order_item_id INT,
    product_id STRING,
    seller_id STRING,
    shipping_limit_date TIMESTAMP_NTZ,
    price FLOAT,
    freight_value FLOAT
);

CREATE OR REPLACE TABLE RAW_CUSTOMERS (
    customer_id STRING,
    customer_unique_id STRING,
    customer_zip_code_prefix STRING,
    customer_city STRING,
    customer_state STRING
);

CREATE OR REPLACE TABLE RAW_PRODUCTS (
    product_id STRING,
    product_category_name STRING,
    product_name_lenght FLOAT,
    product_description_lenght FLOAT,
    product_photos_qty FLOAT,
    product_weight_g FLOAT,
    product_length_cm FLOAT,
    product_height_cm FLOAT,
    product_width_cm FLOAT
);

CREATE OR REPLACE TABLE RAW_SELLERS (
    seller_id STRING,
    seller_zip_code_prefix STRING,
    seller_city STRING,
    seller_state STRING
);

CREATE OR REPLACE TABLE RAW_PAYMENTS (
    order_id STRING,
    payment_sequential INT,
    payment_type STRING,
    payment_installments INT,
    payment_value FLOAT
);

CREATE OR REPLACE TABLE RAW_REVIEWS (
    review_id STRING,
    order_id STRING,
    review_score INT,
    review_comment_title STRING,
    review_comment_message STRING,
    review_creation_date TIMESTAMP_NTZ,
    review_answer_timestamp TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE RAW_CATEGORY_TRANSLATION (
    product_category_name STRING,
    product_category_name_english STRING
);






-- CREATING DIMENSION TABLES

USE SCHEMA ANALYTICS;

-- DIM_CUSTOMER
CREATE OR REPLACE TABLE DIM_CUSTOMER AS
SELECT DISTINCT
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix
FROM RAW.RAW_CUSTOMERS;

-- DIM_PRODUCT (joined with category translation for English names)
CREATE OR REPLACE TABLE DIM_PRODUCT AS
SELECT DISTINCT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS product_category,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM RAW.RAW_PRODUCTS p
LEFT JOIN RAW.RAW_CATEGORY_TRANSLATION t
    ON p.product_category_name = t.product_category_name;

-- DIM_SELLER
CREATE OR REPLACE TABLE DIM_SELLER AS
SELECT DISTINCT
    seller_id,
    seller_city,
    seller_state
FROM RAW.RAW_SELLERS;

-- DIM_PAYMENT_TYPE
CREATE OR REPLACE TABLE DIM_PAYMENT_TYPE AS
SELECT DISTINCT
    payment_type
FROM RAW.RAW_PAYMENTS;

-- DIM_DATE: built from min/max order dates using a date generator
CREATE OR REPLACE TABLE DIM_DATE AS
WITH date_spine AS (
    SELECT DATEADD(day, SEQ4(), '2016-01-01'::DATE) AS calendar_date
    FROM TABLE(GENERATOR(ROWCOUNT => 2000))  -- covers ~5.5 years
)
SELECT
    calendar_date AS date_key,
    YEAR(calendar_date) AS year,
    QUARTER(calendar_date) AS quarter,
    MONTH(calendar_date) AS month,
    MONTHNAME(calendar_date) AS month_name,
    DAY(calendar_date) AS day,
    DAYOFWEEK(calendar_date) AS day_of_week,
    DAYNAME(calendar_date) AS day_name,
    CASE WHEN DAYOFWEEK(calendar_date) IN (0,6) THEN TRUE ELSE FALSE END AS is_weekend
FROM date_spine;




--CREATING FACT TABLE

CREATE OR REPLACE TABLE FACT_ORDER_ITEMS AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    o.customer_id,
    DATE(o.order_purchase_timestamp) AS order_date,
    o.order_status,
    pay.payment_type,
    oi.price,
    oi.freight_value,
    pay.payment_value,
    pay.payment_installments,
    DATEDIFF(day, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_days_actual,
    DATEDIFF(day, o.order_purchase_timestamp, o.order_estimated_delivery_date) AS delivery_days_estimated,
    DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date) AS delivery_delay_days,
    r.review_score
FROM RAW.RAW_ORDER_ITEMS oi
JOIN RAW.RAW_ORDERS o
    ON oi.order_id = o.order_id
LEFT JOIN RAW.RAW_PAYMENTS pay
    ON oi.order_id = pay.order_id
    AND pay.payment_sequential = 1  
LEFT JOIN RAW.RAW_REVIEWS r
    ON oi.order_id = r.order_id;




    SELECT COUNT(*) FROM FACT_ORDER_ITEMS;
SELECT COUNT(*) FROM FACT_ORDER_ITEMS WHERE order_id IS NULL;  
SELECT * FROM FACT_ORDER_ITEMS LIMIT 20;




--INSIGHTS 

-- 1. Monthly revenue trend
SELECT
    DATE_TRUNC('month', order_date) AS month,
    ROUND(SUM(price), 2) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders
FROM FACT_ORDER_ITEMS
GROUP BY 1
ORDER BY 1;

-- 2. Top 10 product categories by revenue
SELECT
    dp.product_category,
    ROUND(SUM(f.price), 2) AS total_revenue,
    COUNT(*) AS items_sold
FROM FACT_ORDER_ITEMS f
JOIN DIM_PRODUCT dp ON f.product_id = dp.product_id
GROUP BY 1
ORDER BY total_revenue DESC
LIMIT 10;

-- 3. Average delivery delay by customer state
SELECT
    dc.customer_state,
    ROUND(AVG(f.delivery_delay_days), 1) AS avg_delay_days,
    COUNT(*) AS order_count
FROM FACT_ORDER_ITEMS f
JOIN DIM_CUSTOMER dc ON f.customer_id = dc.customer_id
WHERE f.delivery_delay_days IS NOT NULL
GROUP BY 1
ORDER BY avg_delay_days DESC;

-- 4. Revenue contribution by payment type
SELECT
    payment_type,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(100 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 1) AS pct_of_total
FROM FACT_ORDER_ITEMS
GROUP BY 1
ORDER BY total_payment_value DESC;

-- 5. Average review score by product category
SELECT
    dp.product_category,
    ROUND(AVG(f.review_score), 2) AS avg_review_score,
    COUNT(*) AS review_count
FROM FACT_ORDER_ITEMS f
JOIN DIM_PRODUCT dp ON f.product_id = dp.product_id
WHERE f.review_score IS NOT NULL
GROUP BY 1
HAVING COUNT(*) > 50  -- exclude tiny categories
ORDER BY avg_review_score DESC
LIMIT 10;

-- 6. Repeat customer rate
WITH customer_orders AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS order_count
    FROM FACT_ORDER_ITEMS
    GROUP BY 1
)
SELECT
    ROUND(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_customer_pct
FROM customer_orders;

-- 7. Top sellers by revenue and order volume
SELECT
    ds.seller_id,
    ds.seller_state,
    ROUND(SUM(f.price), 2) AS total_revenue,
    COUNT(DISTINCT f.order_id) AS total_orders
FROM FACT_ORDER_ITEMS f
JOIN DIM_SELLER ds ON f.seller_id = ds.seller_id
GROUP BY 1, 2
ORDER BY total_revenue DESC
LIMIT 10;

-- 8. Revenue by day of week (using DIM_DATE)
SELECT
    dd.day_name,
    ROUND(SUM(f.price), 2) AS total_revenue
FROM FACT_ORDER_ITEMS f
JOIN DIM_DATE dd ON f.order_date = dd.date_key
GROUP BY 1, dd.day_of_week
ORDER BY dd.day_of_week;
