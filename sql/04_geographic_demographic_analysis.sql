-- =====================================================================
-- OLIST SALES PERFORMANCE ANALYSIS
-- Phase 4: Geographic and demographic analysis
-- Filter applied: order_status IN ('delivered', 'shipped')
-- =====================================================================


-- ---------------------------------------------------------------------
-- 4.1 Revenue and order volume by state
-- ---------------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id)                          AS total_orders,
    SUM(oi.price + oi.freight_value)                     AS total_revenue,
    ROUND(
        SUM(oi.price + oi.freight_value)
        / COUNT(DISTINCT o.order_id), 2
    )                                                     AS avg_order_value
FROM olist_orders_dataset o
INNER JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
INNER JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE o.order_status IN ('delivered', 'shipped')
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


-- ---------------------------------------------------------------------
-- 4.2 Top 15 cities by revenue
-- ---------------------------------------------------------------------
SELECT
    c.customer_city,
    c.customer_state,
    COUNT(DISTINCT o.order_id)       AS total_orders,
    SUM(oi.price + oi.freight_value) AS total_revenue
FROM olist_orders_dataset o
INNER JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
INNER JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE o.order_status IN ('delivered', 'shipped')
GROUP BY c.customer_city, c.customer_state
ORDER BY total_revenue DESC
LIMIT 15;


-- ---------------------------------------------------------------------
-- 4.3 Revenue and orders by macro-region
-- (Brazil's 5 official regions, mapped from state via CASE WHEN)
-- ---------------------------------------------------------------------
SELECT
    CASE
        WHEN c.customer_state IN ('AC','AP','AM','PA','RO','RR','TO') THEN 'Norte'
        WHEN c.customer_state IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE') THEN 'Nordeste'
        WHEN c.customer_state IN ('DF','GO','MT','MS') THEN 'Centro-Oeste'
        WHEN c.customer_state IN ('ES','MG','RJ','SP') THEN 'Sudeste'
        WHEN c.customer_state IN ('PR','RS','SC') THEN 'Sul'
    END AS region,
    COUNT(DISTINCT o.order_id)       AS total_orders,
    SUM(oi.price + oi.freight_value) AS total_revenue,
    ROUND(
        SUM(oi.price + oi.freight_value)
        / COUNT(DISTINCT o.order_id), 2
    ) AS avg_order_value
FROM olist_orders_dataset o
INNER JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
INNER JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE o.order_status IN ('delivered', 'shipped')
GROUP BY region
ORDER BY total_revenue DESC;


-- ---------------------------------------------------------------------
-- 4.4 Unique customers by state
-- IMPORTANT: uses customer_unique_id, NOT customer_id.
-- customer_id is generated per order; customer_unique_id identifies
-- the actual person. Using customer_id here would count repeat
-- customers multiple times.
-- ---------------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers
FROM olist_orders_dataset o
INNER JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE o.order_status IN ('delivered', 'shipped')
GROUP BY c.customer_state
ORDER BY unique_customers DESC;


-- ---------------------------------------------------------------------
-- 4.6 Unique customers by macro-region (rollup of 4.4, using same
-- region mapping as 4.3)
-- ---------------------------------------------------------------------
SELECT
    CASE
        WHEN c.customer_state IN ('AC','AP','AM','PA','RO','RR','TO') THEN 'Norte'
        WHEN c.customer_state IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE') THEN 'Nordeste'
        WHEN c.customer_state IN ('DF','GO','MT','MS') THEN 'Centro-Oeste'
        WHEN c.customer_state IN ('ES','MG','RJ','SP') THEN 'Sudeste'
        WHEN c.customer_state IN ('PR','RS','SC') THEN 'Sul'
    END AS region,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers
FROM olist_orders_dataset o
INNER JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE o.order_status IN ('delivered', 'shipped')
GROUP BY region
ORDER BY unique_customers DESC;

-- ---------------------------------------------------------------------
-- 4.5 Repeat customers vs one-time customers
-- Uses customer_unique_id to detect customers with more than 1 order
-- ---------------------------------------------------------------------
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count
FROM olist_orders_dataset o
INNER JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE o.order_status IN ('delivered', 'shipped')
GROUP BY c.customer_unique_id
HAVING COUNT(DISTINCT o.order_id) > 1
ORDER BY order_count DESC;

-- Summary version: how many customers fall into each bucket
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM olist_orders_dataset o
    INNER JOIN olist_customers_dataset c
        ON o.customer_id = c.customer_id
    WHERE o.order_status IN ('delivered', 'shipped')
    GROUP BY c.customer_unique_id
)
SELECT
    CASE WHEN order_count = 1 THEN 'One-time customer' ELSE 'Repeat customer' END AS customer_type,
    COUNT(*) AS num_customers
FROM customer_orders
GROUP BY customer_type;
