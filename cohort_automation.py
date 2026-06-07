"""
============================================================
PROJECT 5: Cohort Retention & Trend Analysis
File: cohort_automation.py

What this script does:
  1. Reads the raw CSV
  2. Cleans & normalises (same logic as SQL script 02)
  3. Computes the full cohort retention matrix
  4. Computes monthly trend metrics
  5. Exports 4 analysis-ready CSVs for Power BI / Tableau
  6. Prints a summary report to console

Why Python here alongside SQL?
  SQL is great for ad-hoc querying; Python handles the
  matrix pivoting (cohort table) and bulk export cleanly.

Author: Thrusha Sahu | ServiceNow ITSM Portfolio
============================================================
"""

import pandas as pd
import os, sys, logging
from datetime import datetime

# ── CONFIG ──────────────────────────────────────────────────
RAW_CSV    = "raw_data/cohort_raw.csv"
OUTPUT_DIR = "outputs"
os.makedirs(OUTPUT_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[logging.StreamHandler(sys.stdout),
              logging.FileHandler(f"{OUTPUT_DIR}/cohort_pipeline.log", mode="w")]
)
log = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────
# STEP 1: EXTRACT
# ─────────────────────────────────────────────────────────────
def extract(path: str) -> pd.DataFrame:
    log.info("EXTRACT: reading raw CSV")
    df = pd.read_csv(path, dtype=str, keep_default_na=False)
    log.info(f"  Rows: {len(df):,}  |  Cols: {len(df.columns)}")
    return df


# ─────────────────────────────────────────────────────────────
# STEP 2: TRANSFORM / CLEAN
# ─────────────────────────────────────────────────────────────
DATE_FMTS = [
    "%Y-%m-%d %H:%M:%S", "%d/%m/%Y %H:%M", "%m-%d-%Y",
    "%Y/%m/%d %H:%M",    "%Y-%m-%d",        "%d/%m/%Y",
]

def parse_dt(val):
    if pd.isna(val) or str(val).strip() in ("", "NULL", "N/A", "null", "n/a", "NA"):
        return pd.NaT
    for fmt in DATE_FMTS:
        try:
            return datetime.strptime(str(val).strip(), fmt)
        except ValueError:
            pass
    return pd.NaT

PRIORITY_MAP = {
    "1 - CRITICAL":"1 - Critical","CRITICAL":"1 - Critical","P1":"1 - Critical",
    "2 - HIGH":"2 - High","HIGH":"2 - High","P2":"2 - High",
    "3 - MODERATE":"3 - Moderate","P3":"3 - Moderate",
    "4 - LOW":"4 - Low","LOW":"4 - Low",
}
STATE_MAP = {
    "resolved":"Resolved","closed":"Closed","in progress":"In Progress",
    "new":"New","on hold":"On Hold",
}

def clean(df: pd.DataFrame) -> pd.DataFrame:
    log.info("TRANSFORM: cleaning & normalising")
    df = df.apply(lambda c: c.str.strip() if c.dtype == object else c)
    BLANK = {"", "NULL", "null", "N/A", "n/a", "NA", "na", "None", "TBD"}
    df    = df.apply(lambda c: c.map(lambda x: pd.NA if x in BLANK else x) if c.dtype == object else c)

    # Deduplicate
    before = len(df)
    df = df.drop_duplicates(subset=["incident_id"], keep="first")
    log.info(f"  Duplicates removed: {before - len(df):,}")

    # Normalise
    df["priority"] = df["priority"].map(
        lambda x: PRIORITY_MAP.get(str(x).upper().strip(), "Unknown") if pd.notna(x) else "Unknown")
    df["state"] = df["state"].map(
        lambda x: STATE_MAP.get(str(x).lower().strip(), "Unknown") if pd.notna(x) else "Unknown")
    df["sla_breached"] = df["sla_breached"].map(
        lambda x: {"YES":"Yes","NO":"No"}.get(str(x).upper().strip()) if pd.notna(x) else pd.NA)

    # Parse dates
    df["opened_at"]  = df["opened_at"].apply(parse_dt)
    df["resolved_at"] = df["resolved_at"].apply(parse_dt)

    # Derived columns
    df["incident_month"]  = df["opened_at"].dt.strftime("%Y-%m")
    df["months_since_onboard"] = pd.to_numeric(df["months_since_onboard"], errors="coerce").fillna(0).astype(int)

    # Recalculate resolution hours from clean dates
    has_both = df["opened_at"].notna() & df["resolved_at"].notna()
    df["resolution_hrs_calc"] = pd.NA
    df.loc[has_both, "resolution_hrs_calc"] = (
        (df.loc[has_both, "resolved_at"] - df.loc[has_both, "opened_at"])
        .dt.total_seconds() / 3600
    ).round(2)

    log.info(f"  Clean rows: {len(df):,}")
    return df


# ─────────────────────────────────────────────────────────────
# STEP 3: COHORT RETENTION MATRIX
# ─────────────────────────────────────────────────────────────
def build_cohort_matrix(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    log.info("ANALYSIS: building cohort retention matrix")

    # Cohort sizes (unique users per cohort)
    sizes = (df.groupby("cohort_month")["user_id"]
               .nunique()
               .rename("cohort_size")
               .reset_index())

    # Monthly active users per cohort × month_number
    active = (df[df["months_since_onboard"].between(0, 11)]
                .groupby(["cohort_month", "months_since_onboard"])["user_id"]
                .nunique()
                .rename("active_users")
                .reset_index())

    matrix_long = active.merge(sizes, on="cohort_month")
    matrix_long["retention_pct"] = (
        100 * matrix_long["active_users"] / matrix_long["cohort_size"]
    ).round(1)

    # Pivot to wide format (cohorts as rows, months as columns)
    matrix_wide = matrix_long.pivot_table(
        index="cohort_month",
        columns="months_since_onboard",
        values="retention_pct",
        aggfunc="first"
    )
    matrix_wide.columns = [f"M{int(c)}" for c in matrix_wide.columns]
    matrix_wide = matrix_wide.reset_index()
    matrix_wide = matrix_wide.merge(sizes, on="cohort_month")

    log.info(f"  Cohorts: {len(matrix_wide)} | Max month tracked: M{matrix_long['months_since_onboard'].max()}")
    return matrix_long, matrix_wide


# ─────────────────────────────────────────────────────────────
# STEP 4: MONTHLY TREND
# ─────────────────────────────────────────────────────────────
def build_monthly_trend(df: pd.DataFrame) -> pd.DataFrame:
    log.info("ANALYSIS: building monthly trend table")
    grp = df.groupby("incident_month").agg(
        total_incidents   = ("incident_id", "count"),
        active_users      = ("user_id",     "nunique"),
        sla_breached_count= ("sla_breached", lambda x: (x == "Yes").sum()),
        avg_resolution_hrs= ("resolution_hrs_calc", "mean"),
    ).reset_index()
    grp["avg_resolution_hrs"] = grp["avg_resolution_hrs"].round(1)
    grp["breach_rate_pct"]    = (
        100 * grp["sla_breached_count"] / grp["total_incidents"]
    ).round(1)

    # Month-over-month change
    grp = grp.sort_values("incident_month")
    grp["mom_incident_change_pct"] = (
        grp["total_incidents"].pct_change() * 100
    ).round(1)
    grp["rolling_3m_breach_pct"] = (
        grp["breach_rate_pct"]
        .rolling(3, min_periods=1).mean().round(1)
    )
    return grp


# ─────────────────────────────────────────────────────────────
# STEP 5: COHORT RESOLUTION QUALITY
# ─────────────────────────────────────────────────────────────
def build_resolution_quality(df: pd.DataFrame) -> pd.DataFrame:
    log.info("ANALYSIS: building cohort resolution quality table")
    resolved = df[df["state"].isin(["Resolved","Closed"]) & df["resolution_hrs_calc"].notna()]
    grp = resolved.groupby("cohort_month").agg(
        total_resolved    = ("incident_id", "count"),
        avg_hrs           = ("resolution_hrs_calc", "mean"),
        min_hrs           = ("resolution_hrs_calc", "min"),
        max_hrs           = ("resolution_hrs_calc", "max"),
        sla_breaches      = ("sla_breached", lambda x: (x == "Yes").sum()),
    ).reset_index()
    grp["avg_hrs"]         = grp["avg_hrs"].round(1)
    grp["min_hrs"]         = grp["min_hrs"].round(1)
    grp["max_hrs"]         = grp["max_hrs"].round(1)
    grp["breach_rate_pct"] = (
        100 * grp["sla_breaches"] / grp["total_resolved"]
    ).round(1)
    return grp


# ─────────────────────────────────────────────────────────────
# STEP 6: EXPORT CSVs
# ─────────────────────────────────────────────────────────────
def export(clean_df, matrix_long, matrix_wide, trend, quality):
    log.info("EXPORT: writing CSVs for Power BI / Tableau")
    exports = {
        "cohort_clean.csv"           : clean_df,
        "cohort_matrix_long.csv"     : matrix_long,   # for heatmap visuals
        "cohort_matrix_wide.csv"     : matrix_wide,   # pivot table format
        "monthly_trend.csv"          : trend,
        "resolution_quality.csv"     : quality,
    }
    for fname, frame in exports.items():
        path = os.path.join(OUTPUT_DIR, fname)
        frame.to_csv(path, index=False)
        log.info(f"  Saved: {path}  ({len(frame):,} rows)")


# ─────────────────────────────────────────────────────────────
# STEP 7: CONSOLE SUMMARY REPORT
# ─────────────────────────────────────────────────────────────
def print_summary(clean_df, matrix_wide, trend, quality):
    print("\n" + "="*60)
    print("  PROJECT 5 — COHORT RETENTION SUMMARY REPORT")
    print("="*60)
    print(f"  Total clean incidents : {len(clean_df):,}")
    print(f"  Unique users          : {clean_df['user_id'].nunique():,}")
    print(f"  Cohorts tracked       : {clean_df['cohort_month'].nunique()}")
    print(f"  Date range            : {clean_df['incident_month'].min()} → {clean_df['incident_month'].max()}")

    print("\n── RETENTION AT MONTH 0 vs MONTH 6 ──")
    m0_col = "M0" if "M0" in matrix_wide.columns else None
    m6_col = "M6" if "M6" in matrix_wide.columns else None
    if m0_col and m6_col:
        for _, row in matrix_wide.iterrows():
            m0 = row.get("M0", None)
            m6 = row.get("M6", None)
            if pd.notna(m0) and pd.notna(m6):
                print(f"  Cohort {row['cohort_month']}  |  M0: {m0}%  →  M6: {m6}%  |  Drop: {round(m0-m6,1)}pp")

    print("\n── MONTHLY TREND (last 6 months) ──")
    last6 = trend.tail(6)
    for _, r in last6.iterrows():
        print(f"  {r['incident_month']}  |  Incidents: {int(r['total_incidents']):,}  |  Breach rate: {r['breach_rate_pct']}%  |  Avg res hrs: {r['avg_resolution_hrs']}")

    print("\n── TOP 3 COHORTS BY BREACH RATE ──")
    top3 = quality.nlargest(3, "breach_rate_pct")
    for _, r in top3.iterrows():
        print(f"  Cohort {r['cohort_month']}  |  Breach rate: {r['breach_rate_pct']}%  |  Avg hrs: {r['avg_hrs']}")

    print("\n" + "="*60)
    print("  Outputs saved to /outputs/")
    print("  Load cohort_matrix_wide.csv into Power BI as heatmap")
    print("  Load monthly_trend.csv for line chart")
    print("="*60 + "\n")


# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info("="*60)
    log.info("PROJECT 5 — COHORT RETENTION PIPELINE START")
    log.info(f"Run: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log.info("="*60)

    raw              = extract(RAW_CSV)
    clean_df         = clean(raw)
    matrix_long, matrix_wide = build_cohort_matrix(clean_df)
    trend            = build_monthly_trend(clean_df)
    quality          = build_resolution_quality(clean_df)
    export(clean_df, matrix_long, matrix_wide, trend, quality)
    print_summary(clean_df, matrix_wide, trend, quality)
    log.info("PIPELINE COMPLETE")
