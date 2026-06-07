-- ============================================================
-- PROJECT 5: Cohort Retention & Trend Analysis
-- Script 02: Clean → cohort_clean table
-- ============================================================

DROP TABLE IF EXISTS cohort_clean;

CREATE TABLE cohort_clean AS
WITH

deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY incident_id ORDER BY rowid) AS rn
    FROM cohort_raw
    WHERE TRIM(COALESCE(incident_id,'')) != ''
),

normalized AS (
    SELECT
        incident_id,
        number,
        user_id,
        cohort_month,
        CAST(months_since_onboard AS INTEGER) AS months_since_onboard,

        -- Standardize opened_at
        CASE
            WHEN opened_at LIKE '____-__-__ __:__:__' THEN opened_at
            WHEN opened_at LIKE '__/__/____ __:__'
                THEN SUBSTR(opened_at,7,4)||'-'||SUBSTR(opened_at,4,2)||'-'||SUBSTR(opened_at,1,2)||' '||SUBSTR(opened_at,12,5)||':00'
            WHEN opened_at LIKE '__-__-____'
                THEN SUBSTR(opened_at,7,4)||'-'||SUBSTR(opened_at,1,2)||'-'||SUBSTR(opened_at,4,2)||' 00:00:00'
            WHEN opened_at LIKE '____/__/__ __:__'
                THEN REPLACE(SUBSTR(opened_at,1,10),'/','-')||' '||SUBSTR(opened_at,12,5)||':00'
            WHEN opened_at LIKE '____-__-__' THEN opened_at||' 00:00:00'
            ELSE NULL
        END AS opened_at,

        -- Clean resolved_at
        CASE
            WHEN TRIM(COALESCE(resolved_at,'')) IN ('','NULL','N/A','null','n/a') THEN NULL
            WHEN resolved_at LIKE '__-__-____ __:__'
                THEN SUBSTR(resolved_at,7,4)||'-'||SUBSTR(resolved_at,4,2)||'-'||SUBSTR(resolved_at,1,2)||' '||SUBSTR(resolved_at,12,5)||':00'
            ELSE resolved_at
        END AS resolved_at,

        -- Normalize priority
        CASE UPPER(TRIM(COALESCE(priority,'')))
            WHEN '1 - CRITICAL' THEN '1 - Critical'
            WHEN 'CRITICAL' THEN '1 - Critical'  WHEN 'P1' THEN '1 - Critical'
            WHEN '2 - HIGH'     THEN '2 - High'
            WHEN 'HIGH'     THEN '2 - High'      WHEN 'P2' THEN '2 - High'
            WHEN '3 - MODERATE' THEN '3 - Moderate' WHEN 'P3' THEN '3 - Moderate'
            WHEN '4 - LOW'      THEN '4 - Low'    WHEN 'LOW' THEN '4 - Low'
            ELSE 'Unknown'
        END AS priority,

        -- Normalize state
        CASE LOWER(TRIM(COALESCE(state,'')))
            WHEN 'resolved'    THEN 'Resolved'
            WHEN 'closed'      THEN 'Closed'
            WHEN 'in progress' THEN 'In Progress'
            WHEN 'new'         THEN 'New'
            WHEN 'on hold'     THEN 'On Hold'
            ELSE 'Unknown'
        END AS state,

        UPPER(TRIM(COALESCE(category,'Unknown')))     AS category,
        TRIM(COALESCE(assignment_group,'Unknown'))     AS assignment_group,
        TRIM(COALESCE(location,'Unknown'))             AS location,

        CASE WHEN TRIM(COALESCE(resolution_hrs,''))='' THEN NULL
             ELSE CAST(resolution_hrs AS REAL) END     AS resolution_hrs,

        CASE UPPER(TRIM(COALESCE(sla_breached,'')))
            WHEN 'YES' THEN 'Yes' WHEN 'NO' THEN 'No' ELSE NULL
        END AS sla_breached,

        CASE WHEN TRIM(COALESCE(reopen_count,''))='' THEN 0
             ELSE CAST(reopen_count AS INTEGER) END    AS reopen_count

    FROM deduped WHERE rn = 1
),

with_derived AS (
    SELECT *,
           STRFTIME('%Y-%m', opened_at)  AS incident_month,
           STRFTIME('%Y',    opened_at)  AS incident_year,
           STRFTIME('%m',    opened_at)  AS incident_month_num,
           CASE
               WHEN opened_at IS NOT NULL AND resolved_at IS NOT NULL
               THEN ROUND((JULIANDAY(resolved_at) - JULIANDAY(opened_at)) * 24, 2)
               ELSE resolution_hrs
           END AS calc_resolution_hrs
    FROM normalized
)

SELECT * FROM with_derived;

-- Quick verification
SELECT
    COUNT(*) AS clean_rows,
    COUNT(DISTINCT user_id) AS unique_users,
    COUNT(DISTINCT cohort_month) AS cohorts,
    MIN(opened_at) AS earliest,
    MAX(opened_at) AS latest
FROM cohort_clean;
