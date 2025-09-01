# 📘 SQL Deep Dives — How Each Query Was Built (Step-by-Step)

**Dataset**: campaigns → adsets → ads → performance

---

## Table of contents
- Daily KPI’s
- Total campaign spend & clicks by objective
- Top 3 campaigns by revenue
- CTR by age range (traffic objective)
- Active vs paused campaigns
- Ads with zero impressions
- Cost-per-lead (lead objective)
- CTR by device (conversions objective)
- Campaign funnel drop-off (View→ATC→Checkout→Purchase)
- Campaigns exceeding daily budget
- Avg revenue by ad format (conversions objective)
- Top-performing creative by adset
- Cross-objective creative lift (first vs latest 7-day CTR)
- CPC anomaly detection (z-score + overspend)

---

## 1) Daily KPI’s (foundation view)
- **What it answers**: 
Creates daily fact table with important metrics: impressions, cicks, cost, revenue, view content, add-to-cart, initiate checkout, purchase, form view, ctr, cpc, cpm, roas, cpl
<details>
<summary><b>▶️ View SQL</b></summary>

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
</details>

- **Why it matters**: 
A single, reusable base eliminates repeating joins queries and BI

- **How it's built**:
  - Join: performance → ads → adsets → campaigns
  - Aggregate daily: SUM for numbers, COALESCE nulls to 0 to eliminate errors
  - Grouping: (date, ad_id, adset_id, campaign_id)
