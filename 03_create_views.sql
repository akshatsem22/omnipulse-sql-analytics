USE omnipulse_db;

-- 1. View: Monthly Revenue Trends
CREATE OR REPLACE VIEW vw_monthly_revenue_growth AS
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
    mom_growth_pct,
    rolling_3m_avg_revenue
FROM GrowthMetrics;

-- 2. View: RFM Customer Segments
CREATE OR REPLACE VIEW vw_rfm_customer_segments AS
WITH SnapshotDate AS (
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
FROM RFMScores;

-- 3. View: Subscription Health & MRR
CREATE OR REPLACE VIEW vw_subscription_performance AS
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
GROUP BY p.plan_id, p.plan_name, p.billing_cycle;