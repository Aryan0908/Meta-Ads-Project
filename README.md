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

### 1) Rolling 7-day ROAS Change
- **👉 Why**: Daily ROAS fluctuates a lot due to many factors. A 7-day rolling window smooths this volatility and shows whether ROI is improving or dropping week over week.
<details>
<summary><b>View SQL code</b></summary>

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

- **👉 How**:
  1. ***Build Daily Totals***:
	 - Aggregate spend and revenue by campaign/date (daily CTE).
  2. ***Apply rolling window***: 
     - Use SUM(...) OVER (ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) from (daily CTE) to calculate 7-day spend and revenue (rolling CTE).
  3. ***Calculate ROAS***: 
     - Divide 7-day rolling revenue / 7-day rolling cost (roas CTE).
  4. ***Compare to prior week***: 
     - Use LAG(roas_7d, 7) to fetch ROAS from the previous 7-day period (final CTE).
  5. ***Final output***: 
     - Current vs previous ROAS side by side, plus % change.

- **✅ Business value**: Helps marketers avoid overreacting to noisy daily ROAS and instead make budget decisions based on sustained week-over-week performance.
> 💡 Note for reviewers: This query is specifically designed for campaigns with conversion and traffic campaigns.

### 2) CPC anomaly detection (z-score)
- **👉 Why**: Occasionally CPC spikes due to auction competition, audience saturation, or poor targeting. Detecting anomalies quickly prevents wasted spend.
<details>
<summary>View SQL Code</summary>

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

- **👉 How**:
  1. ***Calculate z-scores***: 
	- For each adset/day, compute z_score = (cpc - mean) / stddev (standarad_dev CTE).
  2. ***Check overspend***: 
	- Compare actual spend vs assigned budget and compute overspend % (overspend CTE).
  3. ***Combine results***: 
	- Join CPC anomalies with overspend data.
  4. ***Flag severity***:
	- Use a CASE expression to tag:
		- Critical: High CPC + Overspend
		- Check: CPC Normal + Overspend
		- Check: CPC High + No Overspend
		- Everything is Fine

- **✅ Business value**: Detecting when the anomaly occured and it's z-score and detect the most probable cause i.e. overspend.

### 3) Campaign funnel drop-offs & stage rates
- **👉 Why**: Not all campaigns fail at the same stage — some lose clicks at the landing page, others lose buyers at checkout. This query highlights where users drop out of the funnel.
<details>
<summary><b>View SQL code</b></summary>

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

- **👉 How**:
  1. ***Build campaign-level totals***:
	- default_table: Join Performance → Ads → Adsets → Campaigns
    - Filter to objective = conversions
	- Aggregate view_content, add_to_cart, initiate_checkout, purchase
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

- **✅ Business value**: This explains where company is loosing it's customers. For eg.
	- Large drop from “Add To Cart → Checkout” = pricing or shipping issue
	- High “View Content” but low “Add To Cart” = weak product relevance or creatives
This helps marketers pinpoint the weakest funnel stage and fix it first.

## 🔹 Deep Dives — DAX
### Best Week (by ROAS)
- **👉 Why**: Surface the single strongest week to highlight peak performance in the period
<details>
<summary><b>View DAX code</b></summary>

```DAX
BestWeek =
CALCULATE(
    MAX('Date'[WeekNum]),
    TOPN(
        1,
        ADDCOLUMNS(
            SUMMARIZE('Date', 'Date'[WeekNum]),
            "Weekly ROAS", [Roas]
        ),
        [Weekly ROAS], DESC
    )
)
```
</details>

- **👉 How**: Ranks weeks by [Roas] and returns the week with the highest value

### Rolling ROAS (7 days)
- **👉 Why**: To keep up ROAS fluctuations and trends
<details>
<summary><b>View DAX code</b></summary>

```DAX
7DaysRollingRoas =
AVERAGEX(
    DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -7, DAY),
    [Roas]
)
```
</details>

- **👉 How**: Averages daily [Roas] across the last 7 days.

### ROAS Month-over-Month
- **👉 Why**: Track ROAS trend month over month with explicit date windows
<details>
<summary><b>View DAX code</b></summary>

```DAX
RoasCurrentMonth =
VAR maxMonth = MAX('Date'[MonthNum])
RETURN
    CALCULATE(
        [Roas],
        MONTH(performance[date]) = maxMonth
    )

RoasPreviousMonth =
VAR startPrevMonth = EOMONTH(MAX('Date'[Date]), -2) + 1
VAR endPrevMonth   = EOMONTH(MAX('Date'[Date]), -1)
RETURN
    CALCULATE(
        IF ( [Roas] > 0, [Roas], 0 ),
        'Date'[Date] >= startPrevMonth && 'Date'[Date] <= endPrevMonth
    )

Roas_MOM% =
VAR prev = [RoasPreviousMonth]
VAR curr = [RoasCurrentMonth]
RETURN IF ( NOT ISBLANK(prev), DIVIDE(curr - prev, prev) )

Roas_MOMLabel =
VAR change = [Roas_MOM%] * 100
RETURN
    SWITCH(
        TRUE(),
        ISBLANK(change), "–",
        change > 0, "▲ " & FORMAT(change, "0.0") & "% MoM",
        change < 0, "▼ " & FORMAT(change, "0.0") & "% MoM",
        "0.0% MoM"
    )
```
</details>

- **👉 How**:
	1. ***Current month***: Uses MAX('Date'[MonthNum]) to select the active month
	2. ***Previous month***: calculates start/end boundaries with EOMONTH

### Metric Selector + Dynamic Title
- **👉 Why**: One visual toggles CTR/CPC/ROAS/CPL
<details>
<summary><b>View DAX code</b></summary>

```DAX
  Selected Metric Value =
VAR m = SELECTEDVALUE ( MetricSelector[Metric], "ROAS" )
RETURN
    SWITCH (
        TRUE (),
        m = "CTR",  DIVIDE ( [Clicks],   [Impressions] ),
        m = "CPC",  DIVIDE ( [Cost],     [Clicks]     ),
        m = "ROAS", DIVIDE ( [Revenue],  [Cost]       ),
        m = "CPL",  DIVIDE ( [Cost],     [Purchases]  )
    )

Dynamic Title = "Performance by " & SELECTEDVALUE ( MetricSelector[Metric], "ROAS" )
```
</details>

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
