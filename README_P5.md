# Project 5: Cohort Retention & Trend Analysis (Capstone)
**ServiceNow ITSM | SQL + Python + Power BI Portfolio Project**
**Author:** Thrusha Sahu | Data Analyst | Hyderabad, India

---

## Problem Statement
Stakeholders want to understand which user cohorts (grouped by onboarding month) show the strongest and weakest incident retention patterns — and whether SLA performance and resolution quality is improving over time. Raw data arrived with mixed date formats, messy priority/state values, and ~200 duplicate records.

**My role:** Build a full analyst workflow — SQL cleaning, Python automation, and Power BI visualisation — delivering a 3-page executive dashboard from raw data.

---

## Full Workflow

```
[Raw CSV — 5,700 rows]
     ↓
[SQL: Profile + Clean]          → cohort_clean table (SQLite)
     ↓
[Python: Automate + Export]     → 5 analysis-ready CSVs
     ↓
[Power BI: 3-page Dashboard]    → Heatmap · Trend · Quality
```

---

## Tools & Techniques

| Tool | Purpose |
|------|---------|
| SQL (SQLite) | Data profiling, dedup, normalization, cohort queries |
| Python (Pandas) | Pipeline automation, cohort matrix, trend export |
| Power BI Desktop | 3-page visual dashboard |
| GitHub | Full portfolio repo |

**SQL techniques:** ROW_NUMBER dedup, CASE normalization, STRFTIME date extraction, LAG window function, rolling AVG, RANK() OVER PARTITION BY  
**Python techniques:** Multi-format date parsing, groupby agg, pivot_table cohort matrix, MoM pct_change, rolling mean  
**Power BI:** Matrix heatmap with conditional formatting, dual-axis line chart, DAX measures, scatter bubble chart

---

## Dataset
- **File:** `raw_data/cohort_raw.csv`
- **Rows:** 5,700 (with ~200 duplicates)
- **Users:** 300 unique users across 18 cohorts (Jan 2023 – Jun 2024)
- **Date range:** Jan 2023 – Dec 2024
- **Key mess:** Mixed date formats, priority/state case variance, null resolved_at on closed tickets, duplicate incident_ids

---

## Key Findings

| Finding | Detail |
|---------|--------|
| Avg M6 retention | 54.8% — half of onboarded users still active at month 6 |
| Worst M6 drop | 2023-10 cohort: 100% → 40% (-60pp) |
| Best retained cohort | 2023-11: 75% retention at M6 |
| Peak incident month | Dec 2023 (251 incidents) |
| Avg breach rate | 42.3% consistently across 2023–2024 |
| Highest-risk cohort | 2024-02 (51.9% breach rate) |
| Fastest resolution | 2024-02 (14.8 avg hrs) — fast but bad SLA compliance |

---

## Scripts (run in order)

| File | Stage | Tool |
|------|-------|------|
| `cohort_01_profiling.sql` | Audit raw data | SQLite |
| `cohort_02_cleaning.sql` | Clean → cohort_clean | SQLite |
| `cohort_03_analysis.sql` | 7 analysis queries | SQLite |
| `cohort_automation.py` | Full pipeline + CSV exports | Python |
| `powerbi_guide.md` | Step-by-step dashboard build | Power BI |

---

## Repository Structure
```
project-05-cohort-retention/
├── raw_data/
│   └── cohort_raw.csv
├── scripts/
│   ├── cohort_01_profiling.sql
│   ├── cohort_02_cleaning.sql
│   ├── cohort_03_analysis.sql
│   ├── cohort_automation.py
│   └── powerbi_guide.md
├── outputs/
│   ├── cohort_clean.csv
│   ├── cohort_matrix_long.csv      ← for heatmap (long format)
│   ├── cohort_matrix_wide.csv      ← for Power BI matrix
│   ├── monthly_trend.csv           ← for line chart
│   ├── resolution_quality.csv      ← for bar chart
│   └── cohort_retention_dashboard.pbix  ← add after building
└── README.md
```

---

## Connect
[LinkedIn](https://linkedin.com) | [GitHub](https://github.com)
