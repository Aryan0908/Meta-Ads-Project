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

- **Scope**: Global
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

## 2) Spend and Clicks by Objective
- **What it answers**: Spending accross different intent/objective.

- **Scope**: Global
<details>
<summary><b>▶️ View SQL</b></summary>

```sql
SELECT 
	c.objective,
	SUM(p.clicks) AS total_clicks,
	ROUND(SUM(p.cost),2) AS total_cost
FROM campaigns AS c
JOIN adsets AS s
	ON s.campaign_id = c.campaign_id
JOIN ads AS ad
	ON ad.adset_id = s.adset_id
JOIN performance AS p
	ON p.ad_id = ad.ad_id
GROUP BY c.objective
ORDER BY total_clicks DESC
```
</details>

- **Why it matters**: 
Helps in knowing where the budget is being allocated and take decisions accordingly

- **How it's built**:
  - Join up the chain, group by objective, aggregate clicks & cost, and sort

## 3) Top 3 campaigns by revenue
- **Scope**: Conversions and Traffic

- **What it answers**: Which campaigns generated the most revenue, so we can identify the top performers to focus and scale.

- **Why it matters**: 
  - Prioritizes campaigns that drive actual business value, not just clicks and impressions.
  - We can check which creatives and demographics are being used in them and plan future campaigns accordingly

<details>
<summary><b>▶️ View SQL</b></summary>

```sql
SELECT 
	c.campaign_name,
	ROUND(SUM(p.revenue),2) AS total_revenue
FROM campaigns AS c
JOIN adsets AS s
	ON s.campaign_id = c.campaign_id
JOIN ads AS ad
	ON ad.adset_id = s.adset_id
JOIN performance AS p
	ON p.ad_id = ad.ad_id
WHERE
	c.objective IN('conversions','traffic')
GROUP BY c.campaign_name
ORDER BY total_revenue DESC
LIMIT 3
```
</details>

- **How it's built**:
  - Filter to conversions and traffic campaigns
  - Aggregate revenue per campaign
  - Order descending and return top 3

## 4) CTR by Age Ranger
- **Scope**: Traffic

- **What it answers**: Which age group produces the highest click-through rate for traffic campaigns?

- **Why it matters**: Reveals high-CTR audiences for reducing CPC.

<details>
<summary><b>▶️ View SQL</b></summary>

```sql
SELECT 
	s.age_range,
	ROUND(AVG(p.ctr),2) AS avg_ctr_perc
FROM campaigns AS c
JOIN adsets AS s
	ON s.campaign_id = c.campaign_id
JOIN ads AS ad
	ON ad.adset_id = s.adset_id
JOIN performance AS p
	ON p.ad_id = ad.ad_id
WHERE
	c.objective = 'traffic'
GROUP BY s.age_range
ORDER BY avg_ctr DESC
```
</details>

- **How it's built**:
  - Filter campaigns with objective='traffic'
  - Group by 'age range'
  - Average CTR per age range
