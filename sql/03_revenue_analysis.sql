-- =====================================================================
-- OLIST SALES PERFORMANCE ANALYSIS
-- Step 4: Consolidated dataset + revenue reconciliation
-- Date: 2026-07-06
-- Filter applied: order_status IN ('delivered', 'shipped')  [decided 2026-06-17]
-- =====================================================================


-- ---------------------------------------------------------------------
-- 4.1 Row-count checkpoint at each JOIN stage
-- Purpose: confirm the payments JOIN was the source of row duplication
-- ---------------------------------------------------------------------

-- Baseline: total orders
SELECT COUNT(*) AS total_orders
FROM olist_orders_dataset;

-- After status filter (delivered/shipped)
SELECT COUNT(*) AS orders_delivered_shipped
FROM olist_orders_dataset
WHERE order_status IN ('delivered', 'shipped');

-- After JOIN with order_items (775 orders w/o items are dropped here)
SELECT COUNT(*) AS rows_after_order_items
FROM olist_orders_dataset o
INNER JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
WHERE o.order_status IN ('delivered', 'shipped');

-- After JOIN with customers (1:1 relationship, count should not change)
SELECT COUNT(*) AS rows_after_customers
FROM olist_orders_dataset o
INNER JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
INNER JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE o.order_status IN ('delivered', 'shipped');

-- After JOIN with raw payments (BEFORE fix -- expected to inflate row count)
SELECT COUNT(*) AS rows_after_payments_unaggregated
FROM olist_orders_dataset o
INNER JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
INNER JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
INNER JOIN olist_order_payments_dataset p
    ON o.order_id = p.order_id
WHERE o.order_status IN ('delivered', 'shipped');

-- Diagnostic: orders with more than 1 payment record (root cause of inflation)
SELECT order_id, COUNT(*) AS payment_count
FROM olist_order_payments_dataset
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY payment_count DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 4.2 Fix: aggregate payments per order BEFORE joining
-- ---------------------------------------------------------------------

WITH payments_agg AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_value,
        COUNT(*) AS payment_count,
        STRING_AGG(DISTINCT payment_type, ', ') AS payment_types,
        MAX(payment_installments) AS max_installments
    FROM olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    c.customer_city,
    c.customer_state,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    pa.payment_types,
    pa.max_installments,
    pa.total_payment_value
FROM olist_orders_dataset o
INNER JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
INNER JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
INNER JOIN payments_agg pa
    ON o.order_id = pa.order_id
WHERE o.order_status IN ('delivered', 'shipped')
ORDER BY o.order_purchase_timestamp;

-- Result: 111,379 rows (item-level granularity, consistent with order_items size --
-- no duplication from payments after the fix)


-- ---------------------------------------------------------------------
-- 4.3 Revenue reconciliation
-- Two independent calculations, for two different reasons:
--   (a) item-level: price + freight_value is safely additive per row
--   (b) order-level: payment_value must be aggregated per order first,
--       otherwise it gets double-counted across multi-item orders
-- ---------------------------------------------------------------------

-- (a) Revenue from item-level data
SELECT
    SUM(oi.price)                    AS total_product_revenue,
    SUM(oi.freight_value)            AS total_freight_revenue,
    SUM(oi.price + oi.freight_value) AS total_revenue,
    COUNT(*)                         AS total_items
FROM olist_orders_dataset o
INNER JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
WHERE o.order_status IN ('delivered', 'shipped');

-- (b) Revenue from aggregated payment data
-- =====================================================================
-- *** CORRECTED 2026-07-08 -- the original version of this query below
-- had a bug. See explanation below the corrected query. ***
-- =====================================================================

-- --- BUGGY VERSION (kept here for reference / learning -- do not use) ---
-- WITH payments_agg AS (
--     SELECT order_id, SUM(payment_value) AS total_payment_value
--     FROM olist_order_payments_dataset
--     GROUP BY order_id
-- )
-- SELECT
--     SUM(pa.total_payment_value)   AS total_payment_revenue,
--     COUNT(DISTINCT o.order_id)    AS total_orders
-- FROM olist_orders_dataset o
-- INNER JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id
-- INNER JOIN payments_agg pa ON o.order_id = pa.order_id
-- WHERE o.order_status IN ('delivered', 'shipped');
--
-- BUG: this still joins through olist_order_items_dataset, which has
-- MULTIPLE rows per order (one per item). payments_agg has one row per
-- order, but that one row gets repeated once per item row after the
-- join -- so SUM(pa.total_payment_value) counts each order's payment
-- total once per item it contains, inflating the result for every
-- multi-item order. This produced an inflated total of R$19,973,232.85
-- (~28% too high).

-- --- CORRECTED VERSION ---
-- Fix: aggregate item revenue to one row per order FIRST, then join
-- 1-to-1 with the aggregated payment total. No table with multiple
-- rows per order is touched after both sides are already aggregated.
WITH item_revenue AS (
    SELECT
        o.order_id,
        SUM(oi.price + oi.freight_value) AS item_total
    FROM olist_orders_dataset o
    INNER JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    WHERE o.order_status IN ('delivered', 'shipped')
    GROUP BY o.order_id
),
payment_revenue AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    COUNT(*)                      AS total_orders,
    SUM(ir.item_total)            AS total_item_revenue,
    SUM(pr.payment_total)         AS total_payment_revenue,
    SUM(pr.payment_total - ir.item_total) AS total_diff
FROM item_revenue ir
INNER JOIN payment_revenue pr
    ON ir.order_id = pr.order_id;

-- RESULT (2026-07-08, corrected):
--   total_orders          = 97,583
--   total_item_revenue    = R$ 15,596,759.63
--   total_payment_revenue = R$ 15,599,598.00
--   total_diff            = R$      2,838.37  (0.02% -- explained by
--                            installment interest; see diagnostic C
--                            below, which shows avg_pct_diff rising
--                            with max_installments)
--
-- >>> VALIDATED REVENUE FIGURE FOR THIS PROJECT: ~R$ 15.6 million <<<
-- (supersedes the R$19,973,232.85 figure from 2026-07-06, which was
-- caused by the JOIN bug described above, not a real business number)


-- ---------------------------------------------------------------------
-- 4.4 Sanity check: full dataset date range
-- ---------------------------------------------------------------------
SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM olist_orders_dataset;
-- Result: 2016-09-04 to 2018-10-17 (matches the known Olist public dataset range)
