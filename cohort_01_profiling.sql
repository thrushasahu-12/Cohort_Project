-- ============================================================
-- PROJECT 5: Cohort Retention & Trend Analysis
-- Script 01: Data Profiling (run before anything else)
-- Tool: SQLite / DBeaver
-- ============================================================

-- ── 1. Total rows + duplicate check ─────────────────────────
SELECT
    COUNT(*)                          AS total_rows,
    COUNT(DISTINCT incident_id)       AS unique_incident_ids,
    COUNT(*) - COUNT(DISTINCT incident_id) AS duplicates
FROM cohort_raw;

-- ── 2. Null audit on key columns ────────────────────────────
SELECT
    SUM(CASE WHEN TRIM(COALESCE(user_id,''))       ='' THEN 1 ELSE 0 END) AS null_user_id,
    SUM(CASE WHEN TRIM(COALESCE(cohort_month,''))  ='' THEN 1 ELSE 0 END) AS null_cohort_month,
    SUM(CASE WHEN TRIM(COALESCE(opened_at,''))     ='' THEN 1 ELSE 0 END) AS null_opened_at,
    SUM(CASE WHEN TRIM(COALESCE(resolved_at,''))   ='' THEN 1 ELSE 0 END) AS null_resolved_at,
    SUM(CASE WHEN TRIM(COALESCE(priority,''))      ='' THEN 1 ELSE 0 END) AS null_priority,
    SUM(CASE WHEN TRIM(COALESCE(state,''))         ='' THEN 1 ELSE 0 END) AS null_state,
    SUM(CASE WHEN TRIM(COALESCE(resolution_hrs,''))='' THEN 1 ELSE 0 END) AS null_resolution_hrs
FROM cohort_raw;

-- ── 3. Priority variance ─────────────────────────────────────
SELECT priority, COUNT(*) AS cnt FROM cohort_raw GROUP BY priority ORDER BY cnt DESC;

-- ── 4. State variance ───────────────────────────────────────
SELECT state, COUNT(*) AS cnt FROM cohort_raw GROUP BY state ORDER BY cnt DESC;

-- ── 5. Cohort distribution ──────────────────────────────────
SELECT cohort_month, COUNT(DISTINCT user_id) AS users, COUNT(*) AS incidents
FROM cohort_raw
GROUP BY cohort_month
ORDER BY cohort_month;

-- ── 6. Resolved tickets missing resolved_at ─────────────────
SELECT COUNT(*) AS resolved_missing_date
FROM cohort_raw
WHERE LOWER(TRIM(state)) IN ('resolved','closed')
  AND TRIM(COALESCE(resolved_at,'')) IN ('','NULL','N/A','null','n/a');
