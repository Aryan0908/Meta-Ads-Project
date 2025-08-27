-- Total Campaign Spend and Clicks by Objective
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

	
-- Top 3 Campaigns by Revenue
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

	
-- CTR by Age Range for Traffic Campaigns
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

	
-- Active vs Paused Campaigns
SELECT 
	c.status,
	COUNT(c.campaign_id) AS count_of_campaign
FROM campaigns AS c
GROUP BY c.status


-- Ads with Zero Impressions
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


-- Cost Per Lead (CPL) for Lead Campaigns
SELECT 
	c.campaign_id,
	ROUND((SUM(p.cost)/SUM(p.lead)),2) AS CPL
FROM campaigns AS c
JOIN adsets AS s
	ON s.campaign_id = c.campaign_id
JOIN ads AS ad
	ON ad.adset_id = s.adset_id
JOIN performance AS p
	ON p.ad_id = ad.ad_id
WHERE
	c.objective = 'leads'
GROUP BY c.campaign_id


	
-- Click-Through Rate (CTR) by Device for Conversion Campaigns
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


	
-- Campaign Funnel Drop-off
With default_table AS (
SELECT
	c.campaign_name,
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
GROUP BY campaign_name
ORDER BY campaign_name DESC
),
view_content_tbl AS (
SELECT
	campaign_name,
	'View Content' AS conversion_event,
	view_content AS total_events
FROM default_table
),
atc_tbl AS (
SELECT
	campaign_name,
	'Add To Cart' AS conversion_event,
	add_to_cart AS total_events
FROM default_table
),
initiate_checkout_tbl AS (
SELECT
	campaign_name,
	'Initiate Checkout' AS conversion_event,
	initiate_checkout AS total_events
FROM default_table
),
purchase_tbl AS (
SELECT
	campaign_name,
	'Purchase' AS conversion_event,
	purchase AS total_events
FROM default_table
),
new_tbl AS (
SELECT campaign_name, conversion_event, total_events, 
COALESCE(
	LAG(total_events) OVER (PARTITION BY campaign_name ORDER BY total_events DESC),
	0) AS lag_col 
FROM
(SELECT * FROM view_content_tbl
UNION ALL
SELECT * FROM atc_tbl
UNION ALL
SELECT * FROM initiate_checkout_tbl
UNION ALL
SELECT * FROM purchase_tbl
ORDER BY campaign_name DESC, total_events DESC)
)

SELECT 
	campaign_name,
	conversion_event,
	total_events,
	CASE
	     WHEN lag_col = 0 THEN 0
	     ELSE ROUND(((lag_col - total_events)*100.00/lag_col),2)
	END AS drop_off_rate_percnt

FROM new_tbl

	
-- Campaigns Exceeding Daily Budget
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


-- Average Revenue by Ad Format for Conversion Campaigns
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


-- Top-Performing Creative by Adset
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
  s.adset_id, a.creative_name),

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


-- Rolling 7-Day Average ROAS
WITH my_cte AS (SELECT
  c.campaign_id,
  p.date,
  (
    SUM(p.revenue) OVER win
    / NULLIF(SUM(p.cost)    OVER win, 0)
  ) * 100 AS rolling_roas_pct
FROM performance p
JOIN ads a
ON a.ad_id = p.ad_id
JOIN adsets s
ON s.adset_id = a.adset_id
JOIN campaigns c
ON c.campaign_id = s.campaign_id
WHERE 
c.objective IN('conversions','traffic') AND p.revenue > 0
WINDOW win AS (
  PARTITION BY c.campaign_id
  ORDER BY p.date
  ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
)),

all_rolling_avgs AS (
SELECT
campaign_id,
date,
AVG(rolling_roas_pct) AS roas,
LAG(AVG(rolling_roas_pct),7) OVER (PARTITION BY campaign_id ORDER BY date ASC) AS prev_roas,
ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY date DESC) AS row_num
FROM my_cte
GROUP BY campaign_id, date
)

SELECT
	r.campaign_id,
	r.date,
	ROUND(((roas-prev_roas)/prev_roas),2)*100 AS seven_day_roas_change
FROM all_rolling_avgs AS r
WHERE 
	prev_roas IS NOT NULL
	AND row_num = 1

-- Cross-Objective Creative Lift (new)
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
			LAG(avg_ctr, 6) OVER (PARTITION BY creative_name ORDER BY date ASC) AS rolling_avg,
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
		row_num = 7
		OR row_num = max_date_num
)

SELECT 
	creative_name,
	ROUND(((rolling_avg-prev_rolling_avg)/prev_rolling_avg)*100,2)
FROM filtered_dates
WHERE prev_rolling_avg IS NOT NULL


-- CPC Anomaly Detection (keep)
-- Calculate each adset’s daily CPC z-score and flag days with |z| > 3 and cost > daily_budget. Return adset_id, date, CPC, z-score, and overspend flag.

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
	SUM(p.cost) AS daily_cost
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
	os.daily_cost
FROM standarad_dev AS stdev
JOIN overspend os
	ON os.adset_id = stdev.adset_id AND os.date = stdev.date
WHERE
	z_score > 3
ORDER BY adset_id, date

