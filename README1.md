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
	- default_table (CTE)
	- Join: Performance → Ads → Adsets → Campaigns
    - Filter: objective = conversions
	- Aggregate: Sum of view_content, add_to_cart, initiate_checkout, purchase
  2. ***Unpivot into stage tables***:
    - view_content_tbl, atc_tbl, initiate_checkout_tbl, purchase_tbl (CTE's)
	- Convert wide totals → long format with (campaign, stage, total_events)
	- Attach a stage order: 1=View Content → 2=ATC → 3=Checkout → 4=Purchase
  3. ***Union and compute previous stage***:
	- new_tbl (CTE) 
	- UNION ALL stage tables
	- Use LAG(total_events) to fetch previous stage total per campaign
	- Guard with COALESCE() for the first stage
  4. ***Final output***:
	- drop_off_rate_percnt = (prev - current)/prev * 100
	- Returns one row per (campaign, stage) showing % loss at that step

## 9) CTR by Device
- **🎯 Scope**: Conversions

- **👉 What it answers**: Which devices (mobile, desktop, etc.) deliver the highest CTR for conversion campaigns?

- **👉 Why it matters**: Optimizes spend toward best-performing devices.

<details>
<summary><b> View SQL</b></summary>

```sql
SELECT 
	s.device,
	ROUND(AVG(ctr),2) AS avg_ctr
FROM campaigns AS c
JOIN adsets AS s
	ON s.campaign_id = c.campaign_id
JOIN ads AS ad
	ON ad.adset_id = s.adset_id
JOIN performance AS p
	ON p.ad_id = ad.ad_id
WHERE
	c.objective = 'conversions'
GROUP BY s.device
```
</details>

- **🛠️ How it's built**:
  - Join: campaigns → adsets → ads → performance
  - Group By: 'device'
  - Aggregate: Average CTR rounded upto 2 decimal places

## 10) Detecting Overspend
- **🎯 Scope**: Global

- **👉 What it answers**: Which campaigns spent more than their assigned daily budget?

- **👉 Why it matters**:
  - Usually meta overspends 10-15% of it's assigned budget.
  - This query helps in detecting any major overspend.

<details>
<summary><b> View SQL</b></summary>

```sql
SELECT
  s.campaign_id,
  p.date,
  SUM(p.cost)        AS total_spend,
  SUM(s.daily_budget) AS total_budget,
  (SUM(p.cost) - SUM(s.daily_budget)) AS overspend_amount
FROM performance p
JOIN ads a
  ON p.ad_id = a.ad_id
JOIN adsets s
  ON a.adset_id = s.adset_id
GROUP BY
  s.campaign_id,
  p.date
HAVING
  SUM(p.cost) > SUM(s.daily_budget);
```
</details>

- **🛠️ How it's built**:
  - Join: performance → ads → adsets
  - Group By: campaign id, date
  - Aggregate: Sum of daily cost and daily budget
  - Calculating Overspend: SUM(cost) - SUM(daily_budget)
  - Filter: Show entried where cost > daily budget

## 11) Revenue by ad format
- **🎯 Scope**: Conversions

- **👉 What it answers**: Which ad formats (video, carousel, image) drive the most revenue in conversion campaigns?

- **👉 Why it matters**: Guides creative format investment.

<details>
<summary><b> View SQL</b></summary>

```sql
SELECT
  a.ad_format,
  ROUND(AVG(p.revenue),2) AS avg_revenue
FROM performance p
JOIN ads a
  ON p.ad_id = a.ad_id
JOIN adsets s
  ON a.adset_id = s.adset_id
JOIN campaigns c
  ON c.campaign_id = s.campaign_id
WHERE
  c.objective = 'conversions'
GROUP BY
  a.ad_format
```
</details>

- **🛠️ How it's built**:
  - Join: performance → ads → adsets -> campaigns
  - Group By: ad format
  - Aggregate: Average revenue rounded upto 2 decimals

## 12) Top Creative by adset
- **🎯 Scope**: Global

- **👉 What it answers**: Which creative delivers the highest CTR within each adset?

- **👉 Why it matters**: Reveals best-performing creatives for scaling.

<details>
<summary><b> View SQL</b></summary>

```sql
WITH my_cte AS (SELECT
  s.adset_id,
  a.creative_name,
  ROUND(AVG(p.ctr),2) AS avg_ctr
FROM performance p
JOIN ads a
  ON p.ad_id = a.ad_id
JOIN adsets s
  ON a.adset_id = s.adset_id
JOIN campaigns c
  ON c.campaign_id = s.campaign_id
GROUP BY
  s.adset_id, a.creative_name
),
ranked_creatives  AS (
SELECT 
	adset_id,
	creative_name,
	avg_ctr,
	ROW_NUMBER() OVER (PARTITION BY adset_id ORDER BY avg_ctr DESC) AS rank_num
FROM my_cte
)

SELECT 
	adset_id,
	creative_name,
	avg_ctr
FROM ranked_creatives 
WHERE rank_num = 1
```
</details>

- **🛠️ How it's built**:
  1. ***Build adset-level creative CTR totals:***:
	- my_cte (CTE)
	- Join: Performance → Ads → Adsets → Campaigns
    - Group by: adset id, creative name
	- Aggregate: Avergae CTR upto 2 decimal places
  2. ***Rank creatives within each adset***:
    - ranked_creatives (CTE)
	- ROW_NUMBER() PARTITION BY adset_id ORDER BY avg_ctr DESC
	- Highest-CTR creative in each adset gets rank_num = 1
  4. ***Final output***:
	- Filter: WHERE rank_num = 1
	- Return: one row per adset id with its best creative name and avg ctr

## 13) Rolling 7-day ROAS
- **🎯 Scope**: Conversion, Traffic

- **👉 What it answers**: How does campaign ROAS trend over the last 7 days compared to the prior 7 days?

- **👉 Why it matters**: Daily ROAS fluctuates a lot due to many factors. A 7-day rolling window smooths this volatility and shows whether ROI is improving or dropping week over week.

<details>
<summary><b> View SQL</b></summary>

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
</details>

- **🛠️ How it's built**:
  1. ***Build Daily Totals***:
	 - daily (CTE)
	 - Join: Performance → Ads → Adsets → Campaigns
	 - Group by: campaign id, date
	 - Aggregate: Sum of spend and revenue
  2. ***Apply rolling window***: 
     - rolling (CTE)
	 - Use SUM(...) OVER (ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) from (daily CTE) to calculate 7-day spend and revenue (rolling CTE).
  3. ***Calculate ROAS***: 
     - roas (CTE)
	 - Divide 7-day rolling revenue / 7-day rolling cost.
  4. ***Compare to prior week***: 
     - final (CTE)
	 - Use LAG(roas_7d, 7) to fetch ROAS from the previous 7-day period.
  5. ***Final output***: 
     - Current vs previous ROAS side by side, plus % change.

## 14) Cross-objective creative lift
- **🎯 Scope**: Global

- **👉 What it answers**: How did creative CTR change between its first 7 days vs most recent 7 days?

- **👉 Why it matters**: Helps detect fatigue or creative improvement.

<details>
<summary><b> View SQL</b></summary>

```sql
WITH my_cte AS (
SELECT 
	a.creative_name,
	p.date,
	AVG(p.ctr) OVER (PARTITION BY a.creative_name ORDER BY p.date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW ) AS avg_ctr
FROM performance p
JOIN ads a
ON a.ad_id = p.ad_id
JOIN adsets s
ON s.adset_id = a.adset_id
JOIN campaigns c
ON c.campaign_id = s.campaign_id
ORDER BY a.creative_name ASC
),
avg_rolling_ctr AS (
	SELECT
		creative_name,
		date,
		rolling_avg,
		row_num,
		MAX(row_num) OVER(PARTITION BY creative_name) AS max_date_num
	FROM(
		SELECT 
			creative_name,
			date,
			avg_ctr AS rolling_avg,
			ROW_NUMBER() OVER (PARTITION BY creative_name ORDER BY date ASC) AS row_num
		FROM my_cte
	)
),
filtered_dates AS (
	SELECT
		creative_name,
		date,
		rolling_avg,
		LAG(rolling_avg) OVER (PARTITION BY creative_name ORDER BY date) AS prev_rolling_avg,
		row_num
	FROM avg_rolling_ctr
	WHERE
		max_date_num > 14
		AND
		(row_num = 7
		OR 
		row_num = max_date_num)
)

SELECT 
	creative_name,
	ROUND(((rolling_avg-prev_rolling_avg)/prev_rolling_avg)*100,2) AS creative_life_perc
FROM filtered_dates
WHERE prev_rolling_avg IS NOT NULL
```
</details>

- **🛠️ How it's built**:
  1. ***Build creative-level rolling totals***:
	- my_cte (CTE)
	- Join: Performance → Ads → Adsets → Campaigns
  	- Aggregate: 7-day moving average CTR per (creative_name, date) using AVG(ctr) OVER (PARTITION BY creative_name ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
	- One row per creative/day with avg_ctr (rolling 7-day CTR)
  2. ***Index timeline & carry rolling average***:
	- avg_rolling_ctr (CTE)
	- Add row_num per creative (ROW_NUMBER() ORDER BY date).
	- Compute max_date_num per creative to know the series length
  3. ***Select comparison checkpoints***:
	- filtered_dates (CTE)
	- Ensuring timeline: max_date_num > 14 (need at least 2 weeks)
	- Early dates average: row_num = 7 (first complete 7-day average)
	- Latest dates average: row_num = max_date_num (most recent 7-day average)
	- Getting prev_rolling_avg via LAG(rolling_avg) so latest row carries both values
  4. ***Final output***:
	- creative_lift_pct = (latest_7d − early_7d) / early_7d × 100 (rounded to 2 decimals)
	- Returns one row per creative with its % 

## 15) CPC anomaly detection (z-score)
- **🎯 Scope**: Global

- **👉 What it answers**: Which were the days where we got unexpected metrics and what was the real reason behind it.

- **👉 Why it matters**:  Occasionally CPC spikes due to auction competition, audience saturation, or poor targeting. Detecting anomalies quickly prevents wasted spend.

<details>
<summary><b> View SQL</b></summary>

```sql
WITH standarad_dev AS (
	SELECT
		s.adset_id,
		p.date,
		ROUND(((p.cpc - AVG(p.cpc) OVER (PARTITION BY s.adset_id))/STDDEV(p.cpc) OVER (PARTITION BY s.adset_id)),2) AS z_score
	FROM performance p
	JOIN ads a
		ON a.ad_id = p.ad_id
	JOIN adsets s
		ON s.adset_id = a.adset_id
	JOIN campaigns c
		ON c.campaign_id = s.campaign_id
),
overspend AS (
	SELECT
		s.adset_id,
		p.date,
		s.daily_budget,
		SUM(p.cost) AS daily_cost,
		ROUND(((SUM(p.cost)-s.daily_budget)/s.daily_budget)*100,2) AS overspend_perc
	FROM performance p
	JOIN ads a
		ON a.ad_id = p.ad_id
	JOIN adsets s
		ON s.adset_id = a.adset_id
	JOIN campaigns c
		ON c.campaign_id = s.campaign_id
	GROUP BY 
		s.adset_id,
		p.date,
		s.daily_budget
)

SELECT 
		stdev.adset_id,
		stdev.date,
		stdev.z_score,
		os.daily_budget,
		os.daily_cost,
		os.overspend_perc,
	CASE
		WHEN stdev.z_score >= 2 AND os.overspend_perc > 0 THEN 'Critical: High CPC + Overspend'
		WHEN stdev.z_score < 2 AND os.overspend_perc > 0 THEN 'Check: CPC Normal - Overspend'
		WHEN stdev.z_score >= 2 AND os.overspend_perc <= 0 THEN 'Check: CPC High - No Overspend'
		ELSE 'Everything is Fine!!'
	END AS alert
FROM standarad_dev AS stdev
JOIN overspend os
	ON os.adset_id = stdev.adset_id AND os.date = stdev.date
WHERE
	z_score > 2
ORDER BY adset_id, date
```
</details>

- **🛠️ How it's built**:
  1. ***Calculate z-scores***: 
	- standarad_dev (CTE)
	- For each adset/day, compute z_score = (cpc - mean) / stddev (standarad_dev CTE).
  2. ***Check overspend***: 
	- overspend (CTE)
	- Compare actual spend vs assigned budget and compute overspend % (overspend CTE).
  3. ***Combine results***: 
	- Join CPC anomalies with overspend data.
  4. ***Flag severity***:
	- Use a CASE expression to tag:
		- Critical: High CPC + Overspend
		- Check: CPC Normal + Overspend
		- Check: CPC High + No Overspend
		- Everything is Fine

