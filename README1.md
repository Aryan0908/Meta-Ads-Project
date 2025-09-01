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
- **🎯 Scope**: Global

- **👉 What it answers**: 
Creates daily fact table with important metrics: impressions, cicks, cost, revenue, view content, add-to-cart, initiate checkout, purchase, form view, ctr, cpc, cpm, roas, cpl

- **👉 Why it matters**: A single, reusable base eliminates repeating joins queries and BI

<details>
<summary><b> View SQL</b></summary>

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

- **🛠️ How it's built**:
  - Join: performance → ads → adsets → campaigns
  - Aggregate daily: SUM for numbers, COALESCE nulls to 0 to eliminate errors
  - Grouping: date, ad_id, adset_id, campaign_id

## 2) Spend and Clicks by Objective
- **🎯 Scope**: Global

- **👉 What it answers**: Spending accross different intent/objective.

- **👉 Why it matters**: Helps in knowing where the budget is being allocated and take decisions accordingly

<details>
<summary><b> View SQL</b></summary>

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

- **🛠️ How it's built**:
  - Join up the chain, group by objective, aggregate clicks & cost, and sort

## 3) Top 3 campaigns by revenue
- **🎯 Scope**: Conversions and Traffic

- **👉 What it answers**: Which campaigns generated the most revenue, so we can identify the top performers to focus and scale.

- **👉 Why it matters**: 
  - Prioritizes campaigns that drive actual business value, not just clicks and impressions.
  - We can check which creatives and demographics are being used in them and plan future campaigns accordingly

<details>
<summary><b> View SQL</b></summary>

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

- **🛠️ How it's built**:
  - Filter: campaign objectives= 'conversions' & 'traffic'
  - Aggregate: Sum of revenue per campaign rounded upto 2 decimal places
  - Top 3: Order descending and limit upto 3 results

## 4) CTR by Age Range
- **🎯 Scope**: Traffic

- **👉 What it answers**: Which age group produces the highest click-through rate for traffic campaigns?

- **👉 Why it matters**: Reveals high-CTR audiences for reducing CPC.

<details>
<summary><b> View SQL</b></summary>

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
ORDER BY avg_ctr_perc DESC
```
</details>

- **🛠️ How it's built**:
  - Filter: campaigns with objective='traffic'
  - Group by: 'age range'
  - Aggregate: Average CTR per age range, rounded upto 2 decimal places
  - Order By: avg_ctr_perc desending

## 5) Campaign Status
- **🎯 Scope**: Global

- **👉 What it answers**: How many campaigns are currently active vs paused?

- **👉 Why it matters**: Quick health check on campaign management.

<details>
<summary><b> View SQL</b></summary>

```sql
SELECT 
	c.status,
	COUNT(c.campaign_id) AS count_of_campaign
FROM campaigns AS c
GROUP BY c.status
```
</details>

## 6) Ads with 0 impressions
- **🎯 Scope**: Global

- **👉 What it answers**: Which ads received no delivery?

- **👉 Why it matters**: There can be many reasons why the ads are not receiving impressions. By filtering these ads we can look for possible causes

<details>
<summary><b> View SQL</b></summary>

```sql
SELECT 
	ad.ad_id,
	SUM(p.impressions) AS total_impressions
FROM campaigns AS c
JOIN adsets AS s
	ON s.campaign_id = c.campaign_id
JOIN ads AS ad
	ON ad.adset_id = s.adset_id
JOIN performance AS p
	ON p.ad_id = ad.ad_id
GROUP BY ad.ad_id
HAVING SUM(p.impressions) = 0
```
</details>

- **🛠️ How it's built**: 
  - Join: campaigns → adsets → ads → performance
  - Group By: 'ad id'
  - Aggregate: Sum of impressions grouped by 'ad id'
  - Filter: total_impressions = 0

## 7) Cost Per Lead (CPL)
- **🎯 Scope**: Lead

- **👉 What it answers**: 
	- What is the cost per lead (CPL) for each lead adset?
	- Top 5 adset with lowest CPL
	- Demographics of best adsets

- **👉 Why it matters**: Determining which settings (demographics and creatives) are generating cheaper leads.

<details>
<summary><b> View SQL</b></summary>

```sql
SELECT 
	s.adset_id,
	ROUND((SUM(p.cost)/SUM(p.lead)),2) AS CPL,
	s.age_range,
	s.placement,
	s.gender,
	s.country
FROM campaigns AS c
JOIN adsets AS s
	ON s.campaign_id = c.campaign_id
JOIN ads AS ad
	ON ad.adset_id = s.adset_id
JOIN performance AS p
	ON p.ad_id = ad.ad_id
WHERE
	c.objective = 'leads'
GROUP BY s.adset_id, s.age_range, s.placement, s.gender, s.country
ORDER BY ROUND((SUM(p.cost)/SUM(p.lead)),2) ASC
LIMIT 5
```
</details>

- **🛠️ How it's built**:
  - Join: campaigns → adsets → ads → performance
  - Filter: campaigns with objective='leads'
  - Group By: 'adset id' and other demographics
  - Calculate CPL: SUM(p.cost)/SUM(p.lead) and round the result to 2 digits
  - Top 5: Order by CPL and limit results to 5

## 8) Coversion Funnel-Drop Off
- **🎯 Scope**: Conversions

- **👉 What it answers**: At which stage are we loosing our customer.

- **👉 Why it matters**: Knowing the stage where the issue is we can work towards a solution to reduce drop-offs.

<details>
<summary><b> View SQL</b></summary>

```sql
With default_table AS (
SELECT
	c.campaign_id,
	SUM(p.view_content) AS view_content,
	SUM(p.add_to_cart) AS add_to_cart,
	SUM(p.initiate_checkout) AS initiate_checkout,
	SUM(p.purchase) AS purchase
FROM performance p
JOIN ads a ON a.ad_id = p.ad_id
JOIN adsets s ON s.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = s.campaign_id
WHERE
	c.objective = 'conversions'
GROUP BY c.campaign_id
),
view_content_tbl AS (
SELECT
	campaign_id,
	'View Content' AS conversion_event,
	COALESCE(view_content,0) AS total_events,
	1 AS stager
FROM default_table
),
atc_tbl AS (
SELECT
	campaign_id,
	'Add To Cart' AS conversion_event,
	COALESCE(add_to_cart,0) AS total_events,
	2 AS stager
FROM default_table
),
initiate_checkout_tbl AS (
SELECT
	campaign_id,
	'Initiate Checkout' AS conversion_event,
	COALESCE(initiate_checkout,0) AS total_events,
	3 AS stager
FROM default_table
),
purchase_tbl AS (
SELECT
	campaign_id,
	'Purchase' AS conversion_event,
	COALESCE(purchase,0) AS total_events,
	4 AS stager
FROM default_table
),
new_tbl AS (
SELECT campaign_id, conversion_event, total_events, 
COALESCE(
	LAG(total_events) OVER (PARTITION BY campaign_id ORDER BY stager ASC),
	0) AS lag_col 
FROM
(SELECT * FROM view_content_tbl
UNION ALL
SELECT * FROM atc_tbl
UNION ALL
SELECT * FROM initiate_checkout_tbl
UNION ALL
SELECT * FROM purchase_tbl
ORDER BY campaign_id DESC, stager ASC)
)

SELECT 
	campaign_id,
	conversion_event,
	total_events,
	CASE
	     WHEN lag_col = 0 THEN 0
	     ELSE ROUND(((lag_col - total_events)*100.00/lag_col),2)
	END AS drop_off_rate_percnt

FROM new_tbl
```
</details>

- **🛠️ How it's built**:
  1. ***Build campaign-level totals***:
	- default_table: Join Performance → Ads → Adsets → Campaigns
    - Filter: objective = conversions
	- Aggregate: Sum of view_content, add_to_cart, initiate_checkout, purchase
  2. ***Unpivot into stage tables***:
    - view_content_tbl, atc_tbl, initiate_checkout_tbl, purchase_tbl
	- Convert wide totals → long format with (campaign, stage, total_events)
	- Attach a stage order: 1=View Content → 2=ATC → 3=Checkout → 4=Purchase
  3. ***Union and compute previous stage***:
	- new_tbl: UNION ALL stage tables
	- Use LAG(total_events) to fetch previous stage total per campaign
	- Guard with COALESCE() for the first stage
  4. ***Final output***:
	- drop_off_rate_percnt = (prev - current)/prev * 100
	- Returns one row per (campaign, stage) showing % loss at that step
