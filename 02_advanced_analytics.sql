USE omnipulse_db;

-- ============================================================================
-- 1. MoM REVENUE GROWTH & 3-MONTH ROLLING AVERAGE (WINDOW FUNCTIONS)
-- Demonstrates: LAG(), SUM() OVER(), AVG() OVER(), Date truncation, CTEs
-- Business Value: Evaluates top-line e-commerce sales velocity and smooths
--                 seasonal noise for financial reporting.
-- ============================================================================

WITH MonthlyRevenue AS (
    SELECT 
        DATE_FORMAT(order_date, '%Y-%m-01') AS sales_month,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(DISTINCT customer_id) AS unique_purchasers,
        ROUND(SUM(net_amount), 2) AS monthly_net_revenue
    FROM Fact_Order
    WHERE order_status = 'Completed'
    GROUP BY DATE_FORMAT(order_date, '%Y-%m-01')
),
GrowthMetrics AS (
    SELECT 
        sales_month,
        monthly_net_revenue,
        LAG(monthly_net_revenue, 1) OVER (ORDER BY sales_month) AS prior_month_revenue,
        ROUND(
            (monthly_net_revenue - LAG(monthly_net_revenue, 1) OVER (ORDER BY sales_month)) 
            / NULLIF(LAG(monthly_net_revenue, 1) OVER (ORDER BY sales_month), 0) * 100, 
            2
        ) AS mom_growth_pct,
        ROUND(
            AVG(monthly_net_revenue) OVER (
                ORDER BY sales_month 
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ), 
            2
        ) AS rolling_3m_avg_revenue
    FROM MonthlyRevenue
)
SELECT 
    sales_month,
    monthly_net_revenue,
    prior_month_revenue,
    CONCAT(COALESCE(mom_growth_pct, 0), '%') AS mom_growth_rate,
    rolling_3m_avg_revenue
FROM GrowthMetrics
ORDER BY sales_month DESC;


-- ============================================================================
-- 2. RFM CUSTOMER SEGMENTATION (RECENCY, FREQUENCY, MONETARY)
-- Demonstrates: NTILE(), DATEDIFF(), Dynamic Scoring, Multi-tier CTEs
-- Business Value: Classifies customers into actionable marketing tiers 
--                 (Champions, Loyal, At-Risk, Hibernating).
-- ============================================================================

WITH SnapshotDate AS (
    -- Dynamically sets analysis anchor to 1 day after the latest order
    SELECT DATE_ADD(MAX(order_date), INTERVAL 1 DAY) AS reference_date FROM Fact_Order
),
CustomerBaseMetrics AS (
    SELECT 
        fo.customer_id,
        c.full_name,
        c.acquisition_channel,
        DATEDIFF((SELECT reference_date FROM SnapshotDate), MAX(fo.order_date)) AS recency_days,
        COUNT(DISTINCT fo.order_id) AS frequency_orders,
        ROUND(SUM(fo.net_amount), 2) AS monetary_spend
    FROM Fact_Order fo
    JOIN Dim_Customer c ON fo.customer_id = c.customer_id
    WHERE fo.order_status = 'Completed'
    GROUP BY fo.customer_id, c.full_name, c.acquisition_channel
),
RFMScores AS (
    SELECT 
        customer_id,
        full_name,
        acquisition_channel,
        recency_days,
        frequency_orders,
        monetary_spend,
        -- Higher recency days = worse (1), lower recency days = better (4)
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency_orders ASC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary_spend ASC) AS m_score
    FROM CustomerBaseMetrics
)
SELECT 
    customer_id,
    full_name,
    acquisition_channel,
    recency_days,
    frequency_orders,
    monetary_spend,
    CONCAT(r_score, f_score, m_score) AS rfm_combined,
    CASE 
        WHEN r_score = 4 AND f_score = 4 AND m_score = 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 3 AND f_score <= 2 THEN 'Promising / New Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk (Need Re-engagement)'
        WHEN r_score = 1 AND f_score <= 2 THEN 'Hibernating / Lost'
        ELSE 'Potential Loyalist'
    END AS customer_segment
FROM RFMScores
ORDER BY monetary_spend DESC;


-- ============================================================================
-- 3. COHORT RETENTION HEATMAP (MONTHLY SIGNUP COHORTS)
-- Demonstrates: Cross-table joins, Self-aggregations, Relative period indexing
-- Business Value: Shows user stickiness and repeat purchase patterns across 
--                 months since initial account creation.
-- ============================================================================

WITH CustomerCohorts AS (
    -- Assign each customer to their initial signup cohort month
    SELECT 
        customer_id,
        DATE_FORMAT(signup_date, '%Y-%m-01') AS cohort_month
    FROM Dim_Customer
),
OrderActivity AS (
    -- Map each customer's repeat orders and find month offset from signup
    SELECT 
        cc.cohort_month,
        fo.customer_id,
        PERIOD_DIFF(
            DATE_FORMAT(fo.order_date, '%Y%m'), 
            DATE_FORMAT(cc.cohort_month, '%Y%m')
        ) AS month_index
    FROM Fact_Order fo
    JOIN CustomerCohorts cc ON fo.customer_id = cc.customer_id
    WHERE fo.order_status = 'Completed'
    GROUP BY cc.cohort_month, fo.customer_id, month_index
),
CohortSizes AS (
    -- Size of each original cohort
    SELECT 
        cohort_month,
        COUNT(customer_id) AS total_cohort_users
    FROM CustomerCohorts
    GROUP BY cohort_month
)
SELECT 
    cs.cohort_month,
    cs.total_cohort_users,
    COUNT(DISTINCT CASE WHEN oa.month_index = 0 THEN oa.customer_id END) AS m0_active,
    ROUND(COUNT(DISTINCT CASE WHEN oa.month_index = 0 THEN oa.customer_id END) / cs.total_cohort_users * 100, 1) AS m0_retention_pct,
    COUNT(DISTINCT CASE WHEN oa.month_index = 1 THEN oa.customer_id END) AS m1_active,
    ROUND(COUNT(DISTINCT CASE WHEN oa.month_index = 1 THEN oa.customer_id END) / cs.total_cohort_users * 100, 1) AS m1_retention_pct,
    COUNT(DISTINCT CASE WHEN oa.month_index = 2 THEN oa.customer_id END) AS m2_active,
    ROUND(COUNT(DISTINCT CASE WHEN oa.month_index = 2 THEN oa.customer_id END) / cs.total_cohort_users * 100, 1) AS m2_retention_pct,
    COUNT(DISTINCT CASE WHEN oa.month_index = 3 THEN oa.customer_id END) AS m3_active,
    ROUND(COUNT(DISTINCT CASE WHEN oa.month_index = 3 THEN oa.customer_id END) / cs.total_cohort_users * 100, 1) AS m3_retention_pct,
    COUNT(DISTINCT CASE WHEN oa.month_index = 6 THEN oa.customer_id END) AS m6_active,
    ROUND(COUNT(DISTINCT CASE WHEN oa.month_index = 6 THEN oa.customer_id END) / cs.total_cohort_users * 100, 1) AS m6_retention_pct
FROM CohortSizes cs
LEFT JOIN OrderActivity oa ON cs.cohort_month = oa.cohort_month
GROUP BY cs.cohort_month, cs.total_cohort_users
ORDER BY cs.cohort_month DESC;


-- ============================================================================
-- 4. SUBSCRIPTION MRR & CHURN ANALYSIS
-- Demonstrates: Conditional aggregations, Ratio metrics, Plan-tier joins
-- Business Value: Calculates SaaS Monthly Recurring Revenue (MRR), failed
--                 invoices, churn rate, and revenue leakage per plan tier.
-- ============================================================================

SELECT 
    p.plan_name,
    p.billing_cycle,
    COUNT(fb.billing_id) AS total_invoices_generated,
    SUM(CASE WHEN fb.payment_status = 'Paid' THEN 1 ELSE 0 END) AS successful_payments,
    SUM(CASE WHEN fb.payment_status = 'Failed' THEN 1 ELSE 0 END) AS failed_payments,
    ROUND(
        SUM(CASE WHEN fb.payment_status = 'Failed' THEN 1 ELSE 0 END) 
        / NULLIF(COUNT(fb.billing_id), 0) * 100, 
        2
    ) AS failure_rate_pct,
    SUM(fb.is_churned) AS total_churned_accounts,
    ROUND(
        SUM(fb.is_churned) 
        / NULLIF(COUNT(DISTINCT fb.customer_id), 0) * 100, 
        2
    ) AS account_churn_rate_pct,
    ROUND(SUM(fb.amount_paid), 2) AS realized_mrr,
    ROUND(
        SUM(CASE WHEN fb.payment_status = 'Failed' THEN p.monthly_fee ELSE 0 END), 
        2
    ) AS revenue_leakage_amount
FROM Fact_Subscription_Billing fb
JOIN Dim_Subscription_Plan p ON fb.plan_id = p.plan_id
GROUP BY p.plan_id, p.plan_name, p.billing_cycle
ORDER BY realized_mrr DESC;