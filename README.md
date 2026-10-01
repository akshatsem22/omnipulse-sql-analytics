# OmniPulse Analytics: Enterprise E-Commerce & SaaS Intelligence Engine

## 1. Project Overview
OmniPulse Analytics is an end-to-end relational data warehousing and business intelligence solution designed to analyze multi-channel transactions, user lifecycle metrics, and recurring subscription revenue. 

The system models complex customer behavior across 15,000+ transactional records, automating financial performance reporting, cohort retention tracking, and customer segmentation for executive decision-making.

---

## 2. Architecture & Data Model (Star Schema)
The database is structured in 3NF across five primary relational tables:

- **`Dim_Customer`**: Tracks user acquisition channels, demographic origin, and registration dates.
- **`Dim_Product`**: Catalogs software, add-on tools, and modular features with pricing tiers.
- **`Dim_Subscription_Plan`**: Manages recurring license tiers, billing cadence, and monthly fees.
- **`Fact_Order`**: Records transactional e-commerce checkout events, gross/net revenue, and discounts.
- **`Fact_Subscription_Billing`**: Tracks recurring invoice settlement, churn events, and payment failure rates.

---

## 3. Advanced SQL Highlights

### A. MoM Growth & Rolling Metrics (Window Functions)
- Utilized `LAG()` to compute month-over-month revenue deltas and growth percentages.
- Deployed dynamic frame windows (`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`) to calculate 3-month moving averages that smooth seasonal revenue spikes.

### B. RFM Segmentation (Recency, Frequency, Monetary)
- Employed multi-tier Common Table Expressions (CTEs) and `NTILE(4)` ranking to score customer behavior dynamically.
- Programmed business logic mapping composite RFM scores into actionable cohorts: *Champions*, *Loyal Customers*, *At Risk*, and *Hibernating*.

### C. Cohort Retention Heatmap
- Assigned customer acquisition cohorts using signup date truncation.
- Tracked repeat transaction rates using relative month offsets (`PERIOD_DIFF`) across Months 0, 1, 2, 3, and 6 to gauge long-term product stickiness.

### D. SaaS Health & Churn Analysis
- Aggregated Monthly Recurring Revenue (MRR), failed invoice rates, and customer churn percentages across individual subscription tiers to evaluate revenue leakage.

---

## 4. Repository Structure
```text
omnipulse_sql_analytics/
├── 01_schema_setup.sql          # DDL table creation and schema definitions
├── 02_advanced_analytics.sql     # Complex CTEs, window functions, and cohort models
├── 03_create_views.sql           # Production-ready SQL views for BI integration
├── generate_data.py             # Python synthetic data generation engine
├── data/                        # Generated CSV data files
└── README.md                    # Technical and business documentation