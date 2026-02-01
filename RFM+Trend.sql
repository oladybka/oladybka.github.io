/* ============================================================
PROJECT: Customer Segmentation – RFM + Spend Trend (AdventureWorks)
GOAL:
Build a customer-level segmentation table combining:
1) RFM segments (Recency, Frequency, Monetary)
2) Spend trend segment based on change in SubTotal between purchases
Then create an aggregated matrix (RFM × Trend) for Power BI heatmap.

DATA:
AdventureWorks2019 -> Sales.SalesOrderHeader

OUTPUTS:
1) dbo.analiza  : 1 row per customer (RFM + trend segment + counts)
2) dbo.macierz  : matrix table (rfm_segment × customer_trend_segment)
============================================================ */

-- ============================================================
-- VIEW 1: Customer-level table (1 row = 1 customer)
-- Purpose: reusable “single source of truth” for Power BI and analysis
-- ============================================================
CREATE OR ALTER VIEW dbo.analiza
AS
WITH
-- 1) Prepare order sequence per customer + previous purchase value
orders AS (
    SELECT
        CustomerID,
        SalesOrderID,
        OrderDate,
        SubTotal,
        ROW_NUMBER() OVER (
            PARTITION BY CustomerID
            ORDER BY OrderDate, SalesOrderID
        ) AS order_number,
        LAG(SubTotal) OVER (
            PARTITION BY CustomerID
            ORDER BY OrderDate, SalesOrderID
        ) AS prev_subtotal
    FROM Sales.SalesOrderHeader
    WHERE SubTotal > 0
),

-- 2) Calculate purchase-to-purchase deltas (% and absolute)
deltas AS (
    SELECT
        CustomerID,
        SalesOrderID,
        OrderDate,
        SubTotal,
        prev_subtotal,
        SubTotal - prev_subtotal AS delta_abs,
        (SubTotal - prev_subtotal) * 1.0 / NULLIF(prev_subtotal, 0) AS delta_pct
    FROM orders
    WHERE prev_subtotal IS NOT NULL
),

-- 3) Convert delta_pct into spend trend labels per transition
trend_transitions AS (
    SELECT
        CustomerID,
        CASE
            WHEN delta_pct <= -0.10 THEN 'down'
            WHEN delta_pct >=  0.10 THEN 'up'
            ELSE 'flat'
        END AS spend_trend
    FROM deltas
),

-- 4) Aggregate trend transitions to customer-level trend profile
trend_customer AS (
    SELECT
        CustomerID,
        COUNT(*) AS transitions_count,
        SUM(CASE WHEN spend_trend = 'down' THEN 1 ELSE 0 END) AS down_count,
        SUM(CASE WHEN spend_trend = 'up'   THEN 1 ELSE 0 END) AS up_count,
        SUM(CASE WHEN spend_trend = 'flat' THEN 1 ELSE 0 END) AS flat_count,
        SUM(CASE WHEN spend_trend = 'down' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS down_share,
        SUM(CASE WHEN spend_trend = 'up'   THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS up_share,
        SUM(CASE WHEN spend_trend = 'flat' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS flat_share
    FROM trend_transitions
    GROUP BY CustomerID
),

-- 5) Final customer trend segment (declining/growing/stable/mixed/insufficient)
segment AS (
    SELECT
        CustomerID,
        down_count,
        up_count,
        flat_count,
        CASE
            WHEN transitions_count < 2 THEN 'insufficient_data'
            WHEN down_share >= 0.5 THEN 'declining'
            WHEN up_share   >= 0.5 THEN 'growing'
            WHEN flat_share >= 0.6 THEN 'stable'
            ELSE 'mixed'
        END AS customer_trend_segment
    FROM trend_customer
),

-- 6) RFM base: last purchase date, frequency, total spend
rfm_base AS (
    SELECT
        CustomerID,
        MAX(OrderDate) AS last_order,
        COUNT(*) AS frequency,
        SUM(SubTotal) AS monetary
    FROM Sales.SalesOrderHeader
    WHERE SubTotal > 0
    GROUP BY CustomerID
),

-- 7) Recency (days since last order relative to max last_order in dataset)
rfm_recency AS (
    SELECT
        CustomerID,
        DATEDIFF(DAY, last_order, MAX(last_order) OVER ()) AS recency,
        frequency,
        monetary
    FROM rfm_base
),

-- 8) RFM scores (1–5) using NTILE
rfm_scores AS (
    SELECT
        CustomerID,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency)    AS f_score,
        NTILE(5) OVER (ORDER BY monetary)     AS m_score
    FROM rfm_recency
),

-- 9) Map scores to business-friendly RFM segments
rfm AS (
    SELECT
        CustomerID,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'champions'
            WHEN r_score >= 3 AND f_score >= 4                 THEN 'loyal'
            WHEN r_score >= 4 AND f_score >= 2                 THEN 'potential loyalist'
            WHEN r_score <= 2 AND f_score >= 3                 THEN 'at risk'
            WHEN r_score <= 2 AND f_score <= 2                 THEN 'hibernating'
            ELSE 'others'
        END AS rfm_segment,
        CONCAT(r_score, f_score, m_score) AS rfm_score
    FROM rfm_scores
)

-- 10) Final customer-level output (1 row per customer)
SELECT
    rfm.CustomerID,
    rfm.rfm_segment,
    rfm.rfm_score,
    segment.customer_trend_segment,
    segment.down_count,
    segment.up_count,
    segment.flat_count
FROM rfm
LEFT JOIN segment
    ON rfm.CustomerID = segment.CustomerID;
GO


-- ============================================================
-- VIEW 2: Matrix (RFM × Trend)
-- Purpose: ready-to-use aggregated table for Power BI heatmap/matrix
-- ============================================================
CREATE OR ALTER VIEW dbo.macierz
AS
SELECT
    a.rfm_segment,
    ISNULL(a.customer_trend_segment, 'single_purchase') AS customer_trend_segment,
    COUNT(DISTINCT a.CustomerID) AS customers_count,
    COUNT(DISTINCT a.CustomerID) * 1.0
        / SUM(COUNT(DISTINCT a.CustomerID)) OVER (PARTITION BY a.rfm_segment)
        AS share_within_rfm
FROM dbo.analiza AS a
GROUP BY
    a.rfm_segment,
    ISNULL(a.customer_trend_segment, 'single_purchase');
GO


-- ============================================================
-- TEST QUERIES (run after creating views)
-- ============================================================
SELECT TOP (50) *
FROM dbo.analiza;

SELECT *
FROM dbo.macierz
ORDER BY rfm_segment, share_within_rfm DESC;
