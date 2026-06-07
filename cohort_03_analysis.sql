-- ============================================================
-- PROJECT 5: Cohort Retention & Trend Analysis
-- Script 03: Cohort + Trend Analysis Queries
-- Techniques: CTEs, Window Functions, CASE, GROUP BY, STRFTIME
-- All queries on cohort_clean
-- ============================================================


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: Cohort Size — how many users onboarded per month?
-- ══════════════════════════════════════════════════════════════
SELECT
    cohort_month,
    COUNT(DISTINCT user_id) AS cohort_size
FROM cohort_clean
GROUP BY cohort_month
ORDER BY cohort_month;


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: Cohort Retention Matrix
-- For each cohort, in each subsequent month (0,1,2,...),
-- how many users are still raising/having incidents?
-- This is the core cohort table — paste into Power BI / Tableau
-- Technique: double GROUP BY cohort + months_since_onboard
-- ══════════════════════════════════════════════════════════════
WITH cohort_sizes AS (
    SELECT cohort_month,
           COUNT(DISTINCT user_id) AS cohort_size
    FROM cohort_clean
    GROUP BY cohort_month
),
monthly_active AS (
    SELECT cohort_month,
           months_since_onboard,
           COUNT(DISTINCT user_id) AS active_users
    FROM cohort_clean
    WHERE months_since_onboard BETWEEN 0 AND 11   -- first 12 months
    GROUP BY cohort_month, months_since_onboard
)
SELECT
    m.cohort_month,
    c.cohort_size,
    m.months_since_onboard                                    AS month_number,
    m.active_users,
    ROUND(100.0 * m.active_users / NULLIF(c.cohort_size, 0), 1) AS retention_pct
FROM monthly_active m
JOIN cohort_sizes c ON m.cohort_month = c.cohort_month
ORDER BY m.cohort_month, m.months_since_onboard;


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: Month 0 vs Month 6 Retention Drop
-- Which cohorts dropped off hardest after 6 months?
-- ══════════════════════════════════════════════════════════════
WITH pivoted AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT CASE WHEN months_since_onboard = 0 THEN user_id END) AS m0_users,
        COUNT(DISTINCT CASE WHEN months_since_onboard = 6 THEN user_id END) AS m6_users
    FROM cohort_clean
    GROUP BY cohort_month
)
SELECT
    cohort_month,
    m0_users,
    m6_users,
    ROUND(100.0 * m6_users / NULLIF(m0_users, 0), 1) AS retention_at_m6_pct,
    m0_users - m6_users                               AS users_lost_by_m6
FROM pivoted
WHERE m0_users > 0
ORDER BY retention_at_m6_pct ASC;


-- ══════════════════════════════════════════════════════════════
-- QUERY 4: Monthly Incident Volume Trend (2023–2024)
-- Is overall incident volume increasing or decreasing?
-- Technique: STRFTIME, window LAG for month-over-month change
-- ══════════════════════════════════════════════════════════════
WITH monthly_vol AS (
    SELECT
        incident_month,
        COUNT(*)                                                 AS total_incidents,
        COUNT(DISTINCT user_id)                                  AS active_users,
        COUNT(CASE WHEN sla_breached = 'Yes' THEN 1 END)        AS sla_breached_count,
        ROUND(AVG(calc_resolution_hrs), 1)                       AS avg_resolution_hrs
    FROM cohort_clean
    WHERE incident_month IS NOT NULL
    GROUP BY incident_month
),
with_lag AS (
    SELECT *,
           LAG(total_incidents) OVER (ORDER BY incident_month) AS prev_month_incidents,
           LAG(avg_resolution_hrs) OVER (ORDER BY incident_month) AS prev_avg_hrs
    FROM monthly_vol
)
SELECT
    incident_month,
    total_incidents,
    active_users,
    sla_breached_count,
    avg_resolution_hrs,
    -- Month-over-month change
    ROUND(
        100.0 * (total_incidents - prev_month_incidents) / NULLIF(prev_month_incidents, 0),
        1
    ) AS mom_change_pct,
    ROUND(avg_resolution_hrs - prev_avg_hrs, 1) AS resolution_hrs_delta
FROM with_lag
ORDER BY incident_month;


-- ══════════════════════════════════════════════════════════════
-- QUERY 5: Cohort Resolution Quality — do newer cohorts
-- get resolved faster than older cohorts?
-- ══════════════════════════════════════════════════════════════
SELECT
    cohort_month,
    COUNT(*)                                                        AS total_resolved,
    ROUND(AVG(calc_resolution_hrs), 1)                             AS avg_resolution_hrs,
    ROUND(MIN(calc_resolution_hrs), 1)                             AS min_hrs,
    ROUND(MAX(calc_resolution_hrs), 1)                             AS max_hrs,
    COUNT(CASE WHEN sla_breached = 'Yes' THEN 1 END)              AS breaches,
    ROUND(
        100.0 * COUNT(CASE WHEN sla_breached = 'Yes' THEN 1 END)
        / NULLIF(COUNT(*), 0), 1
    )                                                              AS breach_rate_pct
FROM cohort_clean
WHERE state IN ('Resolved', 'Closed')
  AND calc_resolution_hrs IS NOT NULL
GROUP BY cohort_month
ORDER BY cohort_month;


-- ══════════════════════════════════════════════════════════════
-- QUERY 6: Top Users by Incident Volume per Cohort
-- Who are the power users driving incident counts in each cohort?
-- Technique: RANK() partitioned by cohort
-- ══════════════════════════════════════════════════════════════
WITH user_counts AS (
    SELECT
        cohort_month,
        user_id,
        COUNT(*) AS incident_count,
        RANK() OVER (PARTITION BY cohort_month ORDER BY COUNT(*) DESC) AS rnk
    FROM cohort_clean
    GROUP BY cohort_month, user_id
)
SELECT cohort_month, user_id, incident_count, rnk AS rank_in_cohort
FROM user_counts
WHERE rnk <= 3
ORDER BY cohort_month, rnk;


-- ══════════════════════════════════════════════════════════════
-- QUERY 7: 3-Month Rolling Avg — SLA breach rate smoothed
-- For trend line in executive charts
-- ══════════════════════════════════════════════════════════════
WITH monthly AS (
    SELECT
        incident_month,
        COUNT(*)                                                      AS total,
        COUNT(CASE WHEN sla_breached = 'Yes' THEN 1 END)            AS breached
    FROM cohort_clean
    WHERE incident_month IS NOT NULL
    GROUP BY incident_month
)
SELECT
    incident_month,
    total,
    breached,
    ROUND(100.0 * breached / NULLIF(total, 0), 1)                    AS breach_rate_pct,
    ROUND(
        AVG(100.0 * breached / NULLIF(total, 0))
        OVER (ORDER BY incident_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
        1
    )                                                                  AS rolling_3m_breach_pct
FROM monthly
ORDER BY incident_month;
