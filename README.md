# Olist-Snowflake-Datawarehouse
End-to-end data warehouse built on Snowflake from 100K+ row e-commerce dataset. Star schema design, ETL, and analytical SQL queries.

## Overview
Built a Snowflake cloud data warehouse from Olist's Brazilian e-commerce dataset, transforming 8 raw CSV files into a structured analytics layer using a star schema. Wrote SQL-based ETL pipelines and 8 business-focused analytical queries to surface insights across revenue, delivery performance, and customer behaviour.

**Skills demonstrated:**
• Data warehouse architecture and star schema design
• SQL-based ETL (COPY INTO, CTAS transformations)
• Snowflake cloud platform (warehouse, schemas, staging)
• Analytical SQL and business intelligence

## Star Schema Architecture
**Fact Table:**
• FACT_ORDER_ITEMS — 112,650 rows, one per order line item
• Measures: price, freight_value, payment_value, delivery_delay_days, review_score
• Foreign keys: product_id, customer_id, seller_id, order_date, payment_type
 
**Dimension Tables:**
• DIM_CUSTOMER — 99,441 customers (city, state)
• DIM_PRODUCT — 32,951 products (category, weight, dimensions)
• DIM_SELLER — 3,095 sellers (city, state)
• DIM_DATE — Calendar table 2016–2021 (year, quarter, month, day name, weekend flag)
• DIM_PAYMENT_TYPE — 5 payment methods

## Key Business Insights
From 8 analytical SQL queries run against the warehouse:
 
• 1. Monthly Revenue Trend: Peak revenue in November 2017 driven by Black Friday sales; consistent YoY growth across 2016–2018
• 2. Top Product Category: Health & Beauty generated the highest revenue, followed by Watches & Gifts and Bed/Bath/Table
• 3. Delivery Performance: Average delivery delay of 12 days; northern states (RR, AP, AM) showed the highest delays averaging 20+ days
• 4. Payment Methods: Credit card accounted for 73.9% of total payment value; boleto (bank slip) was second at 19.0%
• 5. Product Ratings: Security & Services had the highest avg review score (4.1/5); fashion clothing had the lowest (3.6/5)
• 6. Repeat Customer Rate: 3.0% of customers made 2 or more purchases — low repeat rate typical of marketplace platforms
• 7. Top Seller: Top seller generated R$229,000 in revenue across 2,033 orders from São Paulo state
• 8. Day-of-Week Pattern: Monday and Tuesday showed highest order volumes; weekends had 23% lower revenue than weekdays


## Tools Used
• Snowflake — Cloud data warehouse platform
• SQL — ETL transformations and analytics
• GitHub — Version control and documentation


## Project Structure
Olist-Snowflake-Datawarehouse/
├── README.md
└── sql/
   ├── 01_setup.sql
   ├── 02_raw_tables.sql
   ├── 03_load_data.sql
   ├── 04_dimensions.sql
   ├── 05_fact_table.sql
   └── 06_queries.sql

## Author
**Devson Keot** — BSc Data Science & Analytics Student
📧 devsonkeot@gmail.com
🔗 LinkedIn: https://linkedin.com/in/devsonkeot
🐙 GitHub: https://github.com/devsonkeot
