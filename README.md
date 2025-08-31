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
- **👉 Why**: This is the backbone of the project. It aggregates raw performance logs into daily KPIs that everything else builds on.
```sql
SELECT
  p.date::date AS date,
  p.ad_id,
  a.adset_id,
  s.campaign_id,
  ROUND(SUM(p.impressions),2) AS impressions,
  ROUND(SUM(p.clicks),2) AS clicks,
  SUM(p.cost) AS cost,
  SUM(COALESCE(p.revenue,0)) AS revenue,
  SUM(COALESCE(p.view_content,0)) AS view_content,
  SUM(COALESCE(p.add_to_cart,0)) AS add_to_cart,
  SUM(COALESCE(p.initiate_checkout,0)) AS initiate_checkout,
  SUM(COALESCE(p.purchase,0)) AS purchases,
  SUM(COALESCE(p.form_view,0)) AS form_view,
  CASE WHEN SUM(p.impressions) > 0 THEN ROUND(AVG(ctr)::numeric,2) ELSE NULL END AS ctr,
  CASE WHEN SUM(p.clicks) > 0 THEN ROUND(AVG(cpc)::numeric,2) ELSE NULL END AS cpc,
  CASE WHEN SUM(p.impressions) > 0 THEN ROUND(AVG(cpm)::numeric,2) ELSE NULL END AS cpm,
  CASE WHEN SUM(p.cost) > 0 THEN ROUND(SUM(COALESCE(p.revenue,0)::numeric) / SUM(p.cost)::numeric,2) ELSE NULL END AS roas,
  CASE WHEN SUM(COALESCE(p.purchase, 0)) > 0 
       THEN ROUND(SUM(p.cost)::numeric / NULLIF(SUM(COALESCE(p.purchase,0)),0),2) 
       ELSE NULL END AS cpl
FROM performance p
JOIN ads a ON a.ad_id = p.ad_id
JOIN adsets s ON s.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = s.campaign_id
GROUP BY 1,2,3,4;
```
- **✔️ Business value**: Instead of calculating CTR, CPC, ROAS in every query, this centralizes KPIs into a view so analysts (or dashboards) can reuse them. It’s basically your fact table.
> 💡 Note for reviewers: For the project I've not used this view for my future queries or DAX measures.

### Rolling 7-day ROAS Change
- **👉 Why**: This helps to determine the campaigns performance.
- **👉 How**:
  - ***CTE1***: Calculated sum of spend and revenue by campaign id and date
  2. ***CTE2***: Calculated Rolling 7-day spend and Rolling 7-day revenue from *CTE1* using PARTITION BY campaign_id ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  3. ***CTE3***: Calculated Rolling 7-day ROAS (7-day revenue / 7-day spend) using *CTE2*
  4. ***CTE4***: Calculated previous week Rolling 7-day ROAS using LAG(roas_7d, 7)
  5. ***Final***: Compared current 7-day ROAS VS previous 7-day ROAS and showed the difference in percent
```sql
WITH daily AS (
  SELECT
    c.campaign_id,
    p.date,
    SUM(p.revenue) AS day_revenue,
    SUM(p.cost) AS day_cost
  FROM performance p
  JOIN ads a ON a.ad_id = p.ad_id
  JOIN adsets s ON s.adset_id = a.adset_id
  JOIN campaigns c ON c.campaign_id = s.campaign_id
  WHERE c.objective IN ('conversions','traffic')
  GROUP BY c.campaign_id, p.date
),
rolling AS (
  SELECT
    campaign_id,
    date,
    SUM(day_revenue) OVER (PARTITION BY campaign_id ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rev_7d,
    SUM(day_cost) OVER (PARTITION BY campaign_id ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS cost_7d
  FROM daily
),
roas AS (
  SELECT
    campaign_id,
    date,
    CASE WHEN cost_7d = 0 THEN NULL ELSE rev_7d / cost_7d END AS roas_7d
  FROM rolling
),
final AS (
  SELECT
    campaign_id,
    date,
    roas_7d,
    LAG(roas_7d, 7) OVER (PARTITION BY campaign_id ORDER BY date) AS prev_roas_7d,
    ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY date DESC) AS rn
  FROM roas
)
SELECT
  campaign_id,
  date,
  ROUND(roas_7d, 2) AS current_week_roas,
  ROUND(prev_roas_7d, 2) AS prev_week_roas,
  ROUND( (roas_7d - prev_roas_7d) / NULLIF(prev_roas_7d, 0) * 100, 2) AS seven_day_roas_change
FROM final
WHERE rn = 1
  AND prev_roas_7d IS NOT NULL;
```
- **✔️ Business value**: Using this marketers can make decisions for optimising the campaigns for increasing profits and make improvements to minimise furthur losses.
> 💡 Note for reviewers: This query is specifically designed for campaigns with conversion and traffic campaigns.

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
