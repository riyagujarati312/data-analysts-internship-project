-- ============================================================
-- Afficionado Coffee Roasters — SQL Query Collection
-- Converted from Python/pandas (Google Colab notebook)
-- ============================================================


-- ============================================================
-- 1. DATA EXPLORATION
-- ============================================================

-- Preview first 5 rows
SELECT *
FROM transactions
LIMIT 5;

-- Row count and column overview
SELECT COUNT(*) AS total_rows
FROM transactions;


-- ============================================================
-- 2. DATA CLEANING
-- ============================================================

-- Check for missing (NULL) values per column
SELECT
    SUM(CASE WHEN transaction_id    IS NULL THEN 1 ELSE 0 END) AS transaction_id_nulls,
    SUM(CASE WHEN year              IS NULL THEN 1 ELSE 0 END) AS year_nulls,
    SUM(CASE WHEN transaction_time  IS NULL THEN 1 ELSE 0 END) AS transaction_time_nulls,
    SUM(CASE WHEN transaction_qty   IS NULL THEN 1 ELSE 0 END) AS transaction_qty_nulls,
    SUM(CASE WHEN store_id          IS NULL THEN 1 ELSE 0 END) AS store_id_nulls,
    SUM(CASE WHEN store_location    IS NULL THEN 1 ELSE 0 END) AS store_location_nulls,
    SUM(CASE WHEN product_id        IS NULL THEN 1 ELSE 0 END) AS product_id_nulls,
    SUM(CASE WHEN unit_price        IS NULL THEN 1 ELSE 0 END) AS unit_price_nulls,
    SUM(CASE WHEN product_category  IS NULL THEN 1 ELSE 0 END) AS product_category_nulls,
    SUM(CASE WHEN product_type      IS NULL THEN 1 ELSE 0 END) AS product_type_nulls,
    SUM(CASE WHEN product_detail    IS NULL THEN 1 ELSE 0 END) AS product_detail_nulls
FROM transactions;

-- Check for duplicate rows
SELECT COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_rows
FROM transactions;

-- Verify each product_id maps to exactly one product_detail
SELECT
    product_id,
    COUNT(DISTINCT product_detail) AS unique_product_details
FROM transactions
GROUP BY product_id
ORDER BY unique_product_details DESC;

-- Validate transaction quantities (flag invalid rows <= 0)
SELECT *
FROM transactions
WHERE transaction_qty <= 0;

-- Descriptive stats for transaction_qty (valid rows only)
SELECT
    COUNT(transaction_qty)                          AS count,
    AVG(transaction_qty)                            AS mean,
    MIN(transaction_qty)                            AS min,
    MAX(transaction_qty)                            AS max,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY transaction_qty) AS pct_25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY transaction_qty) AS pct_50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY transaction_qty) AS pct_75
FROM transactions
WHERE transaction_qty > 0;

-- Validate unit prices (flag invalid rows <= 0)
SELECT *
FROM transactions
WHERE unit_price <= 0;

-- Descriptive stats for unit_price (valid rows only)
SELECT
    COUNT(unit_price)                               AS count,
    ROUND(AVG(unit_price), 6)                       AS mean,
    MIN(unit_price)                                 AS min,
    MAX(unit_price)                                 AS max,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY unit_price) AS pct_25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY unit_price) AS pct_50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY unit_price) AS pct_75
FROM transactions
WHERE unit_price > 0;


-- ============================================================
-- 3. REVENUE COMPUTATION
-- (revenue = transaction_qty * unit_price, valid rows only)
-- ============================================================

-- Revenue by product (product_detail)
SELECT
    product_detail,
    ROUND(SUM(transaction_qty * unit_price), 2) AS total_revenue
FROM transactions
WHERE transaction_qty > 0
  AND unit_price > 0
GROUP BY product_detail
ORDER BY total_revenue DESC;

-- Revenue by product type
SELECT
    product_type,
    ROUND(SUM(transaction_qty * unit_price), 2) AS total_revenue
FROM transactions
WHERE transaction_qty > 0
  AND unit_price > 0
GROUP BY product_type
ORDER BY total_revenue DESC;

-- Top 15 product types by revenue
SELECT
    product_type,
    ROUND(SUM(transaction_qty * unit_price), 2) AS total_revenue
FROM transactions
WHERE transaction_qty > 0
  AND unit_price > 0
GROUP BY product_type
ORDER BY total_revenue DESC
LIMIT 15;

-- Revenue by product category
SELECT
    product_category,
    ROUND(SUM(transaction_qty * unit_price), 2) AS total_revenue
FROM transactions
WHERE transaction_qty > 0
  AND unit_price > 0
GROUP BY product_category
ORDER BY total_revenue DESC;


-- ============================================================
-- 4. PRODUCT POPULARITY ANALYSIS
-- ============================================================

-- Total units sold per product
SELECT
    product_detail,
    SUM(transaction_qty) AS units_sold
FROM transactions
WHERE transaction_qty > 0
GROUP BY product_detail
ORDER BY units_sold DESC;

-- Top 10 products by units sold
SELECT
    product_detail,
    SUM(transaction_qty)                                                    AS units_sold,
    DENSE_RANK() OVER (ORDER BY SUM(transaction_qty) DESC)                  AS volume_rank
FROM transactions
WHERE transaction_qty > 0
GROUP BY product_detail
ORDER BY units_sold DESC
LIMIT 10;

-- Bottom 10 products by units sold
SELECT
    product_detail,
    SUM(transaction_qty)                                                    AS units_sold,
    DENSE_RANK() OVER (ORDER BY SUM(transaction_qty) DESC)                  AS volume_rank
FROM transactions
WHERE transaction_qty > 0
GROUP BY product_detail
ORDER BY units_sold ASC
LIMIT 10;


-- ============================================================
-- 5. REVENUE CONTRIBUTION ANALYSIS
-- ============================================================

-- Revenue share % per product
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
),
product_rev AS (
    SELECT
        product_detail,
        SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
    GROUP BY product_detail
)
SELECT
    p.product_detail,
    ROUND(p.total_revenue, 2)                                               AS total_revenue,
    ROUND((p.total_revenue / t.total_revenue) * 100, 6)                     AS revenue_share_pct,
    DENSE_RANK() OVER (ORDER BY p.total_revenue DESC)                       AS revenue_rank
FROM product_rev p
CROSS JOIN total t
ORDER BY total_revenue DESC;

-- Compare volume rank vs revenue rank per product
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
),
product_rev AS (
    SELECT
        product_detail,
        SUM(transaction_qty * unit_price)                                   AS total_revenue,
        SUM(transaction_qty)                                                AS units_sold,
        DENSE_RANK() OVER (ORDER BY SUM(transaction_qty * unit_price) DESC) AS revenue_rank,
        DENSE_RANK() OVER (ORDER BY SUM(transaction_qty) DESC)              AS volume_rank
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
    GROUP BY product_detail
)
SELECT
    p.product_detail,
    p.units_sold,
    p.volume_rank,
    ROUND(p.total_revenue, 2)                                               AS total_revenue,
    ROUND((p.total_revenue / t.total_revenue) * 100, 6)                     AS revenue_share_pct,
    p.revenue_rank,
    (p.volume_rank - p.revenue_rank)                                        AS rank_gap
FROM product_rev p
CROSS JOIN total t
ORDER BY p.revenue_rank;


-- ============================================================
-- 6. CATEGORY & PRODUCT-TYPE PERFORMANCE
-- ============================================================

-- Revenue share % per category
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
)
SELECT
    t.product_category,
    ROUND(SUM(t.transaction_qty * t.unit_price), 2)                         AS total_revenue,
    ROUND((SUM(t.transaction_qty * t.unit_price) / tot.total_revenue)*100, 6) AS category_share_pct
FROM transactions t
CROSS JOIN total tot
WHERE t.transaction_qty > 0 AND t.unit_price > 0
GROUP BY t.product_category, tot.total_revenue
ORDER BY total_revenue DESC;

-- Revenue share % per product type
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
)
SELECT
    t.product_type,
    ROUND(SUM(t.transaction_qty * t.unit_price), 2)                          AS total_revenue,
    ROUND((SUM(t.transaction_qty * t.unit_price) / tot.total_revenue)*100, 6) AS type_share_pct
FROM transactions t
CROSS JOIN total tot
WHERE t.transaction_qty > 0 AND t.unit_price > 0
GROUP BY t.product_type, tot.total_revenue
ORDER BY total_revenue DESC;

-- Top 10 product types by revenue share
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
)
SELECT
    t.product_type,
    ROUND(SUM(t.transaction_qty * t.unit_price), 2)                          AS total_revenue,
    ROUND((SUM(t.transaction_qty * t.unit_price) / tot.total_revenue)*100, 6) AS type_share_pct
FROM transactions t
CROSS JOIN total tot
WHERE t.transaction_qty > 0 AND t.unit_price > 0
GROUP BY t.product_type, tot.total_revenue
ORDER BY total_revenue DESC
LIMIT 10;


-- ============================================================
-- 7. REVENUE CONCENTRATION & MENU BALANCE (PARETO)
-- ============================================================

-- Pareto table: cumulative revenue % per product
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
),
product_rev AS (
    SELECT
        product_detail,
        SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
    GROUP BY product_detail
),
ranked AS (
    SELECT
        p.product_detail,
        ROUND(p.total_revenue, 2)                                               AS total_revenue,
        ROUND((p.total_revenue / t.total_revenue) * 100, 6)                     AS revenue_share_pct,
        DENSE_RANK() OVER (ORDER BY p.total_revenue DESC)                       AS revenue_rank,
        ROUND(
            SUM(p.total_revenue) OVER (ORDER BY p.total_revenue DESC
                                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            / t.total_revenue * 100, 6
        )                                                                       AS cumulative_pct
    FROM product_rev p
    CROSS JOIN total t
)
SELECT
    product_detail,
    total_revenue,
    revenue_share_pct,
    revenue_rank,
    cumulative_pct,
    CASE WHEN cumulative_pct <= 80 THEN 'Revenue Anchor' ELSE 'Long Tail' END AS category
FROM ranked
ORDER BY revenue_rank;

-- Revenue Anchor products only (top 80% of revenue)
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
),
product_rev AS (
    SELECT
        product_detail,
        SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
    GROUP BY product_detail
),
ranked AS (
    SELECT
        p.product_detail,
        ROUND(p.total_revenue, 2)                                               AS total_revenue,
        ROUND((p.total_revenue / t.total_revenue) * 100, 6)                     AS revenue_share_pct,
        DENSE_RANK() OVER (ORDER BY p.total_revenue DESC)                       AS revenue_rank,
        ROUND(
            SUM(p.total_revenue) OVER (ORDER BY p.total_revenue DESC
                                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            / t.total_revenue * 100, 6
        )                                                                       AS cumulative_pct
    FROM product_rev p
    CROSS JOIN total t
)
SELECT *
FROM ranked
WHERE cumulative_pct <= 80
ORDER BY revenue_rank;

-- Long Tail products only (bottom 20% of revenue)
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
),
product_rev AS (
    SELECT
        product_detail,
        SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
    GROUP BY product_detail
),
ranked AS (
    SELECT
        p.product_detail,
        ROUND(p.total_revenue, 2)                                               AS total_revenue,
        ROUND((p.total_revenue / t.total_revenue) * 100, 6)                     AS revenue_share_pct,
        DENSE_RANK() OVER (ORDER BY p.total_revenue DESC)                       AS revenue_rank,
        ROUND(
            SUM(p.total_revenue) OVER (ORDER BY p.total_revenue DESC
                                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            / t.total_revenue * 100, 6
        )                                                                       AS cumulative_pct
    FROM product_rev p
    CROSS JOIN total t
)
SELECT *
FROM ranked
WHERE cumulative_pct > 80
ORDER BY revenue_rank;

-- Count of Revenue Anchor vs Long Tail products
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
),
product_rev AS (
    SELECT
        product_detail,
        SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
    GROUP BY product_detail
),
ranked AS (
    SELECT
        CASE
            WHEN SUM(p.total_revenue) OVER (ORDER BY p.total_revenue DESC
                                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                 / t.total_revenue * 100 <= 80
            THEN 'Revenue Anchor'
            ELSE 'Long Tail'
        END AS category
    FROM product_rev p
    CROSS JOIN total t
)
SELECT category, COUNT(*) AS number_of_products
FROM ranked
GROUP BY category;


-- ============================================================
-- 8. KPI QUERIES
-- ============================================================

-- Highest single-product revenue contribution %
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
),
product_rev AS (
    SELECT SUM(transaction_qty * unit_price) AS product_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
    GROUP BY product_detail
)
SELECT ROUND(MAX(p.product_revenue) / t.total_revenue * 100, 2) AS highest_product_contribution_pct
FROM product_rev p
CROSS JOIN total t;

-- Total product sales volume (units)
SELECT SUM(transaction_qty) AS total_units_sold
FROM transactions
WHERE transaction_qty > 0;

-- Highest category revenue share %
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
),
cat_rev AS (
    SELECT SUM(transaction_qty * unit_price) AS cat_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
    GROUP BY product_category
)
SELECT ROUND(MAX(c.cat_revenue) / t.total_revenue * 100, 2) AS highest_category_share_pct
FROM cat_rev c
CROSS JOIN total t;

-- Revenue concentration ratio (top-80% products share of total revenue)
WITH total AS (
    SELECT SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
),
product_rev AS (
    SELECT
        product_detail,
        SUM(transaction_qty * unit_price) AS total_revenue
    FROM transactions
    WHERE transaction_qty > 0 AND unit_price > 0
    GROUP BY product_detail
),
ranked AS (
    SELECT
        p.total_revenue,
        SUM(p.total_revenue) OVER (ORDER BY p.total_revenue DESC
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / t.total_revenue * 100  AS cumulative_pct
    FROM product_rev p
    CROSS JOIN total t
)
SELECT
    ROUND(SUM(r.total_revenue) / MAX(t.total_revenue) * 100, 2) AS revenue_concentration_ratio_pct
FROM ranked r
CROSS JOIN total t
WHERE r.cumulative_pct <= 80;

-- Product efficiency score (revenue per unit sold)
SELECT
    ROUND(
        SUM(transaction_qty * unit_price) / SUM(transaction_qty),
        2
    ) AS product_efficiency_score
FROM transactions
WHERE transaction_qty > 0 AND unit_price > 0;

-- Revenue by store location
SELECT
    store_location,
    ROUND(SUM(transaction_qty * unit_price), 2) AS total_revenue
FROM transactions
WHERE transaction_qty > 0 AND unit_price > 0
GROUP BY store_location
ORDER BY total_revenue DESC;