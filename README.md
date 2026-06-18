# Olist Sales Performance Analysis

## About the Project

This project aims to analyze sales performance data from a Brazilian marketplace using PostgreSQL.

The objective is to generate business insights related to customers, sellers, orders, and revenue while developing SQL skills applicable to Data Analyst positions.

## Dataset

Brazilian E-Commerce Public Dataset by Olist.

## Technologies

- PostgreSQL
- SQL
- Git
- GitHub

## Project Structure

```text
data/
sql/
screenshots/
docs/
```

## Learning Log

### 2026-06-16

- Created PostgreSQL database
- Imported Olist datasets
- Explored tables using SELECT and LIMIT
- Identified key business entities

### 2026-06-17

- Fixed import of `olist_order_items_dataset` table (was empty due to initial import failure)
- Mapped complete schema for all 5 tables (columns and data types)
- Identified relationship keys: orders ↔ customers (customer_id), orders ↔ order_items (order_id), order_items ↔ sellers (seller_id), orders ↔ payments (order_id)
- Integrity check: 775 orders (≈0.8%) with no associated item in order_items — need to decide handling (likely exclusion) for revenue analyses

### 2026-06-17 (cont.)

- Ran data quality checks across all 5 tables
- Order status distribution: 97.02% delivered, remainder split across shipped, canceled, unavailable, invoiced, processing, created, and approved
- Null values in order date columns are explained by order status (e.g. orders never delivered have null delivery dates) — not a data error
- order_items has zero nulls and zero invalid prices (clean dataset)
- 9 payments (0.009%) with zero/negative value — minor, likely discount edge cases
- No logical date inconsistencies found (no deliveries before purchase, no approvals before purchase)
- Decision: revenue analyses will filter to order_status = 'delivered' (and possibly 'shipped'), excluding canceled/unavailable orders


## Current Status

🚧 In Progress
