-- ============================================
-- 02_data_quality_checks.sql
-- Data quality checks across the Olist dataset
-- ============================================

-- 1. Null check on critical columns in orders
SELECT 
    COUNT(*) AS total_orders,
    COUNT(*) - COUNT(order_approved_at) AS null_approved_at,
    COUNT(*) - COUNT(order_delivered_carrier_date) AS null_delivered_carrier,
    COUNT(*) - COUNT(order_delivered_customer_date) AS null_delivered_customer,
    COUNT(*) - COUNT(order_estimated_delivery_date) AS null_estimated_delivery
FROM olist_orders_dataset;

-- 2. Order status distribution
SELECT 
    order_status, 
    COUNT(*) AS total,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY total DESC;

-- 3. Null check on order_items (price, freight_value)
SELECT 
    COUNT(*) AS total_items,
    COUNT(*) - COUNT(price) AS null_price,
    COUNT(*) - COUNT(freight_value) AS null_freight,
    SUM(CASE WHEN price <= 0 THEN 1 ELSE 0 END) AS zero_or_negative_price
FROM olist_order_items_dataset;

-- 4. Null check on payments
SELECT 
    COUNT(*) AS total_payments,
    COUNT(*) - COUNT(payment_value) AS null_payment_value,
    SUM(CASE WHEN payment_value <= 0 THEN 1 ELSE 0 END) AS zero_or_negative_payment
FROM olist_order_payments_dataset;

-- 5. Date logic check: delivered before purchased (should be 0 or near 0)
SELECT COUNT(*) AS inconsistent_delivery_dates
FROM olist_orders_dataset
WHERE order_delivered_customer_date < order_purchase_timestamp;

-- 6. Date logic check: approved before purchased (should be 0 or near 0)
SELECT COUNT(*) AS inconsistent_approval_dates
FROM olist_orders_dataset
WHERE order_approved_at < order_purchase_timestamp;

-- 7. Duplicate check: order_id appearing more than once in orders (should be 0, it's the PK)
SELECT order_id, COUNT(*) 
FROM olist_orders_dataset
GROUP BY order_id
HAVING COUNT(*) > 1;
