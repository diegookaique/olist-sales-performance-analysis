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
WITH payments_agg AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_value
    FROM olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    SUM(pa.total_payment_value)   AS total_payment_revenue,
    COUNT(DISTINCT o.order_id)    AS total_orders
FROM olist_orders_dataset o
INNER JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
INNER JOIN payments_agg pa
    ON o.order_id = pa.order_id
WHERE o.order_status IN ('delivered', 'shipped');

-- RESULT (2026-07-06):
--   total_payment_revenue = R$ 19,973,232.85
--   total_orders           = 97,583
--   avg order value        ≈ R$ 204.66
--
-- NOTE ON DISCREPANCY: an earlier informal estimate cited "R$2M+" for this
-- project before the 2026-06-17 fix to the order_items import. Date range
-- was checked (2016-09-04 to 2018-10-17 -- full dataset, no filter applied)
-- and ruled out as the cause. The R$19.9M figure above is the validated
-- total from the complete, corrected dataset and is the reference figure
-- going forward.


-- ---------------------------------------------------------------------
-- 4.4 Sanity check: full dataset date range
-- ---------------------------------------------------------------------
SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM olist_orders_dataset;
-- Result: 2016-09-04 to 2018-10-17 (matches the known Olist public dataset range)
