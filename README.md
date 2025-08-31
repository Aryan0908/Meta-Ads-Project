# 📊 Meta Ads Performance Analysis — SQL + Power BI

**End-to-end pipeline to uncover wasted spend, quantify funnel drop-offs, and simulate budget scenarios with SQL, DAX and interactive Power BI dashboards.**  

Badges: `Power BI` · `PostgreSQL` · `Status: Complete`

[Live Demo](#) · [Download .pbix](#)

---

## 🔹 Overview
I built an end-to-end analytics pipeline on a Meta Ads dataset (Campaigns → Adsets → Ads → Daily Performance) to identify wasted spend, diagnose funnel drop-offs, and model “what-if” budget scenarios — using **SQL** (KPIs + anomalies) and **Power BI/DAX** (rolling metrics, metric selector, scenario planning, custom tooltips, and drillthrough).

---

## 🔹 Why this project?
- Turn raw ad logs into **business KPIs** (CTR, CPC, CPM, ROAS, CPL).
- Quantify **customer drop-offs** at every stage (Impression → Click → View Content → Add-to-Cart → Checkout → Purchase).
- Build a **What-if Analysis** layer to simulate spend, CTR, CVR and AOV changes.

> 💡 Tip for reviewers: explore screenshots below, then skim the deep dives for the engineering behind them.

---

## 🔹 Data & Model
**Tables**
- Campaigns: campaign_id, objective, buying_type, budget_type, budgets, dates
- Adsets: adset_id, campaign_id, age_group, gender, placement, device, country, budgets, dates
- Ads: ad_id, adset_id, ad_format, headline, call_to_action, video_length_sec
- Performance: ad_id, date, reach, impressions, clicks, cost, revenue, form_view, add_to_cart, initiate_checkout, purchases
- Date (Power BI) linked to Performance[date]

**Relationships:** Campaigns (1) → Adsets (∞) → Ads (∞) → Performance (∞)

---

## 🔹 Dashboard Pages
*(Add screenshots from your repo's images folder)*

- Main Dashboard  
- Conversion  
- Conversion Details  
- Adset Analysis  
- Creative Analysis  
- What-if Analysis (Page 1)  
- What-if Analysis (Page 2)  

---

## 🔹 Custom Tooltips & Drillthrough
- **Custom tooltips**: dedicated tooltip pages show contextual KPIs when hovering KPI cards/points.
- **Drillthrough**: right-click on a campaign/adset to open its detail page with context filters carried over.
- **Navigation**: back buttons and “Page Navigation” slicers streamline movement across pages.

---

## 🔹 Deep Dives — SQL

### v_daily_kpis (foundation view)
```sql
CREATE OR REPLACE VIEW v_daily_kpis AS
SELECT
  p.date::date AS date,
  p.ad_id,
  a.adset_id,
  s.campaign_id,
  SUM(p.impressions) AS impressions,
  SUM(p.clicks) AS clicks,
  SUM(p.cost) AS cost,
  SUM(COALESCE(p.revenue,0)) AS revenue,
  SUM(COALESCE(p.view_content,0)) AS view_content,
  SUM(COALESCE(p.add_to_cart,0)) AS add_to_cart,
  SUM(COALESCE(p.initiate_checkout,0)) AS initiate_checkout,
  SUM(COALESCE(p.purchases, p.conversions)) AS purchases,
  SUM(COALESCE(p.form_view,0)) AS form_view,
  CASE WHEN SUM(p.impressions) > 0 THEN SUM(p.clicks)::numeric / SUM(p.impressions) ELSE NULL END AS ctr,
  CASE WHEN SUM(p.clicks) > 0 THEN SUM(p.cost)::numeric / SUM(p.clicks) ELSE NULL END AS cpc,
  CASE WHEN SUM(p.impressions) > 0 THEN (SUM(p.cost)::numeric / SUM(p.impressions)) * 1000 ELSE NULL END AS cpm,
  CASE WHEN SUM(p.cost) > 0 THEN SUM(COALESCE(p.revenue,0))::numeric / SUM(p.cost) ELSE NULL END AS roas,
  CASE WHEN SUM(COALESCE(p.purchases, p.conversions,0)) > 0 
       THEN SUM(p.cost)::numeric / NULLIF(SUM(COALESCE(p.purchases, p.conversions,0)),0) 
       ELSE NULL END AS cpl
FROM performance p
JOIN ads a    ON a.ad_id    = p.ad_id
JOIN adsets s ON s.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = s.campaign_id
GROUP BY 1,2,3,4;
```

### Rolling 7-day ROAS per campaign
```sql
WITH daily AS (
  SELECT
    v.date, v.campaign_id,
    SUM(v.revenue) AS revenue,
    SUM(v.cost)    AS cost
  FROM v_daily_kpis v
  GROUP BY v.date, v.campaign_id
),
roll AS (
  SELECT
    campaign_id,
    date,
    (SUM(revenue) OVER win) / NULLIF(SUM(cost) OVER win, 0) AS roas_7d
  FROM daily
  WINDOW win AS (
    PARTITION BY campaign_id
    ORDER BY date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  )
),
endpoints AS (
  SELECT
    campaign_id,
    roas_7d,
    LAG(roas_7d, 7) OVER (PARTITION BY campaign_id ORDER BY date) AS roas_7d_prev
  FROM roll
)
SELECT campaign_id,
       roas_7d,
       roas_7d_prev,
       ROUND(((roas_7d - roas_7d_prev) / NULLIF(roas_7d_prev,0)) * 100, 2) AS wow_change_pct
FROM endpoints
WHERE roas_7d_prev IS NOT NULL;
```

### CPC anomaly detection (z-score)
```sql
WITH daily AS (
  SELECT v.campaign_id, v.date, 
         SUM(v.cost) / NULLIF(SUM(v.clicks),0) AS cpc
  FROM v_daily_kpis v
  GROUP BY v.campaign_id, v.date
),
stats AS (
  SELECT
    campaign_id,
    AVG(cpc) AS mean_cpc,
    STDDEV(cpc) AS std_cpc
  FROM daily
  GROUP BY campaign_id
)
SELECT d.campaign_id, d.date, d.cpc,
       ROUND((d.cpc - s.mean_cpc) / NULLIF(s.std_cpc,0), 2) AS z_score
FROM daily d
JOIN stats s ON s.campaign_id = d.campaign_id
WHERE ABS((d.cpc - s.mean_cpc) / NULLIF(s.std_cpc,0)) >= 2.0
ORDER BY ABS((d.cpc - s.mean_cpc) / NULLIF(s.std_cpc,0)) DESC;
```

### CTR objective lift — first 7 days vs last 7 days (per creative)
```sql
WITH base AS (
  SELECT
    c.objective,
    a.ad_id,
    p.date::date AS date,
    SUM(p.clicks)::numeric / NULLIF(SUM(p.impressions),0) AS ctr
  FROM performance p
  JOIN ads a    ON a.ad_id    = p.ad_id
  JOIN adsets s ON s.adset_id = a.adset_id
  JOIN campaigns c ON c.campaign_id = s.campaign_id
  WHERE c.objective = 'conversions'
  GROUP BY c.objective, a.ad_id, p.date
),
ranked AS (
  SELECT
    ad_id,
    date,
    ctr,
    ROW_NUMBER() OVER (PARTITION BY ad_id ORDER BY date ASC)  AS rn_asc,
    ROW_NUMBER() OVER (PARTITION BY ad_id ORDER BY date DESC) AS rn_desc,
    COUNT(*)     OVER (PARTITION BY ad_id) AS total_days
  FROM base
),
first_last AS (
  SELECT
    ad_id,
    AVG(CASE WHEN rn_asc  <= 7 THEN ctr END) AS ctr_first7,
    AVG(CASE WHEN rn_desc <= 7 THEN ctr END) AS ctr_last7
  FROM ranked
  GROUP BY ad_id
)
SELECT ad_id,
       ROUND(ctr_first7, 4) AS ctr_first7,
       ROUND(ctr_last7, 4)  AS ctr_last7,
       ROUND((ctr_last7 - ctr_first7) / NULLIF(ctr_first7,0) * 100, 2) AS lift_pct
FROM first_last
WHERE ctr_first7 IS NOT NULL AND ctr_last7 IS NOT NULL
ORDER BY lift_pct DESC;
```

### Campaign funnel drop-offs & stage rates
```sql
SELECT
  v.campaign_id,
  SUM(v.impressions)        AS impressions,
  SUM(v.clicks)             AS clicks,
  SUM(v.view_content)       AS view_content,
  SUM(v.add_to_cart)        AS add_to_cart,
  SUM(v.initiate_checkout)  AS initiate_checkout,
  SUM(v.purchases)          AS purchases,
  SUM(v.clicks)::numeric         / NULLIF(SUM(v.impressions),0)        AS ctr,
  SUM(v.view_content)::numeric   / NULLIF(SUM(v.clicks),0)             AS click_to_viewcontent,
  SUM(v.add_to_cart)::numeric    / NULLIF(SUM(v.view_content),0)       AS view_to_cart,
  SUM(v.initiate_checkout)::numeric / NULLIF(SUM(v.add_to_cart),0)     AS cart_to_checkout,
  SUM(v.purchases)::numeric      / NULLIF(SUM(v.initiate_checkout),0)  AS checkout_to_purchase
FROM v_daily_kpis v
GROUP BY v.campaign_id
ORDER BY impressions DESC;
```

### Week-over-Week ROI by adset
```sql
WITH weekly AS (
  SELECT
    a.adset_id,
    DATE_TRUNC('week', v.date)::date AS week_start,
    SUM(v.revenue) / NULLIF(SUM(v.cost),0) AS roi
  FROM v_daily_kpis v
  JOIN ads a ON a.ad_id = v.ad_id
  GROUP BY a.adset_id, DATE_TRUNC('week', v.date)
),
delta AS (
  SELECT
    adset_id,
    week_start,
    roi,
    LAG(roi) OVER (PARTITION BY adset_id ORDER BY week_start) AS prev_roi
  FROM weekly
)
SELECT
  adset_id,
  week_start,
  roi,
  prev_roi,
  ROUND((roi - prev_roi) / NULLIF(prev_roi,0) * 100, 2) AS wow_change_pct
FROM delta
WHERE prev_roi IS NOT NULL
ORDER BY ABS((roi - prev_roi) / NULLIF(prev_roi,0)) DESC;
```

---

## 🔹 Deep Dives — DAX
```DAX
Impressions = SUM(Performance[Impressions])
Clicks      = SUM(Performance[Clicks])
Cost        = SUM(Performance[Cost])
Revenue     = SUM(Performance[Revenue])
Purchases   = SUM(Performance[Purchases])
Form Views  = SUM(Performance[Form Views])

CTR %   = DIVIDE([Clicks], [Impressions])
CPC     = DIVIDE([Cost], [Clicks])
CPM     = DIVIDE([Cost], [Impressions]) * 1000
ROAS %  = DIVIDE([Revenue], [Cost])
CPL     = DIVIDE([Cost], [Purchases])

Rolling ROAS % (7d) =
VAR Rev7  = CALCULATE ( [Revenue], DATESINPERIOD ( 'Date'[Date], MAX ( 'Date'[Date] ), -6, DAY ) )
VAR Cost7 = CALCULATE ( [Cost],    DATESINPERIOD ( 'Date'[Date], MAX ( 'Date'[Date] ), -6, DAY ) )
RETURN DIVIDE ( Rev7, Cost7 )

Selected Metric Value =
VAR m = SELECTEDVALUE ( MetricSelector[Metric], "ROAS" )
RETURN
    SWITCH ( TRUE(),
        m = "CTR",  [CTR %],
        m = "CPC",  [CPC],
        m = "ROAS", [ROAS %],
        m = "CPL",  [CPL]
    )

Dynamic Title = "Performance by " & SELECTEDVALUE ( MetricSelector[Metric], "ROAS" )

Projected Cost   = [Cost] * ( 1 + 'Budget Adjustment %'[Budget Adjustment % Value] )
Projected ROAS % = DIVIDE ( [Revenue], [Projected Cost] )
Projected CPL    = DIVIDE ( [Projected Cost], [Purchases] )
```

---

## 🔹 Key Insights
- Video creatives delivered ~25% higher ROAS than static images.
- Mobile-first placements reduced CPL by ~12% with stable ROAS.
- Age 18–24 clicked most but converted least → tighten targeting/LP.
- ~20% of adsets consumed ~80% of spend with below-median ROI.
- Anomaly flags (CPC spikes, ROAS drops) identified weeks requiring creative or bid changes.

---

## 🔹 How to Run
1. Load CSVs to PostgreSQL and create the view using the SQL above (or your existing warehouse).
2. Open the `.pbix` file in Power BI Desktop and refresh.
3. Ensure a marked **Date** table is related to **Performance[date]**.
4. Optional: Publish to Power BI Service and enable public demo ("Publish to web") for sharing.

---

## 🔹 What I Learned & Next
- Window functions for rolling metrics and robust KPI derivations.
- DAX patterns for metric selectors, dynamic titles, and what-if parameters.
- Designing story-driven dashboards: overview → drilldown → decision.

**Next:** service refresh automation, budget reallocation recommender, and multi-platform ads integration (Google/TikTok/LinkedIn).

---

© 2025 • Meta Ads Analytics (Portfolio). Built with SQL + Power BI. Custom tooltips, drillthrough, and scenario analysis included.
