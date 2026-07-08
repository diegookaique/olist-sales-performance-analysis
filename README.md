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

### 2026-07-08
 
- Started Phase 4 (geographic/demographic analysis): revenue and order volume by state, top 15 cities, revenue by macro-region (mapped via `CASE WHEN`), unique customers by state, and repeat vs. one-time customer segmentation
- **Data quality catch:** noticed a ~28% gap (R$4.37M) between item-level revenue (`price + freight_value`) and the payment-level total documented on 07-06 (R$19,973,232.85). Investigated via a per-order diagnostic instead of assuming the gap was installment interest
- **Root cause found:** the 07-06 revenue query joined the aggregated payment CTE against `order_items` (which has multiple rows per order) *after* aggregation, causing each order's payment total to be summed once per item it contains — inflating totals for every multi-item order
- **Fix:** aggregate item revenue to one row per order in its own CTE, then join 1-to-1 with the aggregated payment CTE, so no multi-row table is touched after both sides are already reduced to one row per order
- **Corrected result:** total item revenue R$15,596,759.63 vs. total payment revenue R$15,599,598.00 — a R$2,838.37 (0.02%) difference, consistent with installment interest (confirmed by a follow-up query showing the average % difference increases with `max_installments`)
- **Revenue figure superseded:** the validated total revenue for this project is now **~R$15.6 million**, replacing the R$19,973,232.85 figure recorded on 07-06, which was an artifact of the JOIN bug above, not a real business number
- Note for future self: always validate an aggregated total against an independent method before treating it as final — the 07-06 figure "looked" fine (right order of magnitude, round validation checks passed) but a second, differently-constructed query caught what row-count checks alone had missed

- **Phase 4 wrap-up — key insights:**
  - Revenue is heavily concentrated in the Southeast (69% of orders, R$10M+ of the ~R$15.6M total); São Paulo state alone (40,829 orders) outweighs the South, Northeast, Center-West, and North regions combined
  - Average order value is *inversely* related to market concentration: North has the highest AOV (R$223.37) with the lowest volume, while Southeast has the lowest AOV (R$150.46) with the highest volume — worth investigating in Phase 5 whether this is a freight-cost or product-mix effect
  - Repeat-purchase rate is low: 2,861 repeat customers vs. 91,538 one-time customers (~3%) — a concrete retention opportunity to call out in interviews
  - Regional revenue total (R$15,596,903.09, summed across the 5 regions) independently matches the corrected item-level total from the 07-08 bug fix (R$15,596,759.63) — cross-validates that Phase 4's queries were unaffected by the Phase 3 payment-join bug

## Current Status
 
✅ Phase 4 complete — consolidated dataset, corrected revenue baseline (~R$15.6M), and geographic/demographic analysis all validated; next: Phase 5, product and seller analysis
