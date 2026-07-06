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
 
- Fixed the import of the `olist_order_items_dataset` table (it was empty due to a failed initial import)
- Completed schema mapping for all 5 tables (columns and data types)
- Identified relationship keys: orders ↔ customers (`customer_id`), orders ↔ order_items (`order_id`), order_items ↔ sellers (`seller_id`), orders ↔ payments (`order_id`)
- Integrity check: 775 orders (≈0.8%) with no matching item in `order_items` — decided to exclude them from revenue analysis (handled naturally via `INNER JOIN`)
### 2026-06-17 (cont.)
 
- Ran data quality checks across all 5 tables
- Order status distribution: 97.02% delivered, remainder split across shipped, canceled, unavailable, invoiced, processing, created, and approved
- Null values in order date columns are explained by order status (e.g., orders never delivered have null delivery dates) — not a data error
- `order_items` has no null values or invalid prices (clean dataset)
- 9 payments (0.009%) with zero/negative value — edge cases, likely discounts, low materiality
- No logical date inconsistencies found (no delivery before purchase, no approval before purchase)
- Decision: revenue analysis will be filtered to `order_status IN ('delivered', 'shipped')`, excluding canceled/unavailable orders
### 2026-07-06
 
- Built the main consolidated JOIN (`orders` → `order_items` → `customers` → `payments`), applying the `delivered`/`shipped` filter defined on 06-17
- **Data quality finding:** joining `order_payments_dataset` directly caused row duplication — some orders have up to 29 separate payment records (installments, vouchers, mixed payment methods), which would have inflated any revenue metric by counting the same order multiple times
- **Fix:** aggregated payments per order first (`SUM(payment_value)`, `STRING_AGG(payment_type)`) in a CTE before joining, so each order contributes a single payment total
- Verified row counts at each JOIN stage to confirm no unintended duplication after the fix; final dataset has 111,379 rows at item-level granularity (one row per order item, consistent with the size of `order_items`)
- **Revenue reconciliation:** calculated total revenue two ways — (1) `SUM(price + freight_value)` at item level, and (2) `SUM(total_payment_value)` at order level using the aggregated CTE — both approaches are needed because summing raw payment values at item-level granularity would double-count orders with multiple items
- Result: **R$19,973,232.85** in total revenue across **97,583 unique orders** (avg. order value ≈ R$204.66), for the full dataset (Sep/2016–Oct/2018, no date filter applied)
- **Discrepancy found and resolved:** this figure differs from an earlier informal estimate of "R$2M+" cited before this session. Investigated potential causes (date filtering, order status filtering, sampling) and ruled them out — the earlier number was most likely calculated before the 06-17 fix to the `order_items` import (i.e., on an incomplete table). The R$19.9M figure is the validated result from the complete, corrected dataset and is now the reference figure for this project going forward



## Current Status

🚧 In Progress
