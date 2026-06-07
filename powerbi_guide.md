# Power BI Build Guide — Project 5: Cohort Retention Analysis
**Thrusha Sahu | ServiceNow ITSM Portfolio**

---

## Files to import into Power BI Desktop

| File | Use |
|------|-----|
| `cohort_matrix_wide.csv` | Cohort retention heatmap (main visual) |
| `monthly_trend.csv` | Line chart — incident volume + breach trend |
| `resolution_quality.csv` | Bar chart — avg resolution hrs by cohort |
| `cohort_clean.csv` | Detail table + slicer source |

---

## Page 1: Cohort Retention Heatmap

### Load cohort_matrix_wide.csv
Home → Get Data → Text/CSV → select file → Load

### Create the Heatmap (Matrix Visual)
1. Insert → **Matrix** visual
2. Rows: `cohort_month`
3. Values: `M0`, `M1`, `M2`, `M3`, `M4`, `M5`, `M6`, `M7`, `M8`, `M9`, `M10`, `M11`
4. In Format pane → **Conditional Formatting** → Background color
   - Format by: Field value
   - Minimum color: `#D73027` (red) = 0%
   - Middle: `#FEE08B` (yellow) = 50%
   - Maximum: `#1A9850` (green) = 100%

### Add Cohort Size Bar
- Insert → Clustered Bar Chart
- Y-axis: `cohort_month`
- X-axis: `cohort_size`
- Title: "Users per Cohort"

---

## Page 2: Monthly Trend

### Load monthly_trend.csv
1. Home → Get Data → Text/CSV → monthly_trend.csv

### Line Chart — Incident Volume
- X-axis: `incident_month`
- Y-axis (Line 1): `total_incidents`
- Y-axis (Line 2): `rolling_3m_breach_pct`
- Add secondary Y-axis for breach rate (Format → Y-axis → Add secondary)
- Title: "Monthly Incident Volume & SLA Breach Trend (2023–2024)"

### KPI Cards (4 cards across the top)
Card 1: `SUM(total_incidents)` → Label: "Total Incidents"
Card 2: `AVERAGE(breach_rate_pct)` → Label: "Avg Breach Rate %"
Card 3: `AVERAGE(avg_resolution_hrs)` → Label: "Avg Resolution Hrs"
Card 4: `SUM(active_users)` → Label: "Total Active Users"

---

## Page 3: Resolution Quality by Cohort

### Load resolution_quality.csv

### Clustered Column Chart
- X-axis: `cohort_month`
- Y-axis (bars): `avg_hrs`
- Line (secondary): `breach_rate_pct`
- Title: "Avg Resolution Time & Breach Rate by Cohort"

### Scatter Plot (optional, impressive)
- X-axis: `avg_hrs`
- Y-axis: `breach_rate_pct`
- Size: `total_resolved`
- Details (tooltip): `cohort_month`
- Title: "Resolution Time vs Breach Rate — Cohort Bubble Chart"

---

## DAX Measures to Create

Open the Modeling tab → New Measure for each:

```dax
-- 1. Total Incidents
Total Incidents = SUM(monthly_trend[total_incidents])

-- 2. Overall Breach Rate %
Overall Breach Rate = 
    DIVIDE(
        SUM(monthly_trend[sla_breached_count]),
        SUM(monthly_trend[total_incidents]),
        0
    ) * 100

-- 3. Avg Resolution Hours
Avg Resolution Hrs = AVERAGE(resolution_quality[avg_hrs])

-- 4. Best Retained Cohort (lowest drop at M6)
-- Create this as a card visual using the matrix table

-- 5. YoY Incident Change (if date table added)
YoY Change = 
    VAR CurrentYear = SUM(monthly_trend[total_incidents])
    VAR PriorYear   = CALCULATE(
        SUM(monthly_trend[total_incidents]),
        DATEADD(monthly_trend[incident_month], -12, MONTH)
    )
    RETURN DIVIDE(CurrentYear - PriorYear, PriorYear, BLANK()) * 100
```

---

## Recommended Dashboard Layout

```
┌─────────────────────────────────────────────────────┐
│  Page 1: Cohort Heatmap                             │
│  [KPI: Total Users] [KPI: Cohorts] [KPI: Avg Ret%] │
│                                                     │
│  [Cohort Retention Matrix Heatmap — full width]     │
│                                                     │
│  [Cohort Size Bar]    [M0 vs M6 Drop Table]         │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Page 2: Trend Analysis                             │
│  [KPI Cards × 4]                                   │
│                                                     │
│  [Monthly Incident Volume + Breach Trend Line]      │
│                                                     │
│  [MoM Change Bar Chart]   [Rolling 3M Breach Line]  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Page 3: Resolution Quality                         │
│  [Cohort Avg Hrs Column + Breach Rate Line]         │
│  [Scatter: Hrs vs Breach Rate — bubble by volume]   │
└─────────────────────────────────────────────────────┘
```

---

## Publishing to GitHub

Only the `.pbix` file + screenshot goes on GitHub (not the .db or large CSVs unless <25MB).

Steps:
1. File → Save As → `cohort_retention_dashboard.pbix`
2. Export → Export to PDF (for screenshot in README)
3. Add to GitHub repo under `/outputs/`
