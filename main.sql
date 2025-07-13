-- Q1. What are the top-performing ad formats by CTR in traffic campaigns?

SELECT 
    a.ad_format,
    ROUND(AVG(p.ctr)::numeric, 2) AS ctr_per
FROM performance p
JOIN ads a ON a.ad_id = p.ad_id
JOIN adsets asets ON asets.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = asets.campaign_id
WHERE 
  c.objective = 'traffic'
  AND p.ctr IS NOT NULL
  AND p.ctr > 0
GROUP BY a.ad_format
ORDER BY ctr_per DESC;


-- What is the average cost-per-click (CPC) by placement for traffic campaigns?
SELECT 
    asets.placement,
    ROUND(AVG(p.cpc)::numeric, 2) AS cpc
FROM performance p
JOIN ads a ON a.ad_id = p.ad_id
JOIN adsets asets ON asets.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = asets.campaign_id
WHERE 
  c.objective = 'traffic'
  AND p.cpc IS NOT NULL
  AND p.cpc > 0
GROUP BY asets.placement
ORDER BY cpc DESC;


-- Which adset demographics (age × gender × device) drive the lowest CPC in traffic campaigns?
SELECT 
	asets.gender,
	asets.placement,
	asets.device,
    ROUND(AVG(p.cpc)::numeric, 2) AS avg_cpc
FROM performance p
JOIN ads a ON a.ad_id = p.ad_id
JOIN adsets asets ON asets.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = asets.campaign_id
WHERE 
  c.objective = 'traffic'
  AND p.cpc IS NOT NULL
  AND p.cpc > 0
  AND asets.gender <> 'unknown'
GROUP BY asets.gender, asets.placement, asets.device
ORDER BY avg_cpc DESC
LIMIT 1;

-- What is the ROAS for each campaign under the conversions objective?
SELECT
	c.campaign_name,
    ROUND((SUM(p.revenue)/SUM(p.cost))::numeric,2) AS roas
FROM performance p
JOIN ads a ON a.ad_id = p.ad_id
JOIN adsets asets ON asets.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = asets.campaign_id
WHERE 
  c.objective = 'conversions'
  AND p.cost IS NOT NULL
  AND p.cost > 0
GROUP BY c.campaign_name
ORDER BY roas DESC;

--Which placements generate the highest number of purchases for conversion campaigns?
SELECT
	asets.placement,
    SUM(purchase) AS purchase
FROM performance p
JOIN ads a ON a.ad_id = p.ad_id
JOIN adsets asets ON asets.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = asets.campaign_id
WHERE
	c.objective = 'conversions'
GROUP BY asets.placement
ORDER BY purchase DESC
LIMIT 1;

-- What is the conversion funnel breakdown by campaign?
With default_table AS (
SELECT
	c.campaign_name,
	SUM(p.view_content) AS view_content,
	SUM(p.add_to_cart) AS add_to_cart,
	SUM(p.initiate_checkout) AS initiate_checkout,
	SUM(p.purchase) AS purchase
FROM performance p
JOIN ads a ON a.ad_id = p.ad_id
JOIN adsets asets ON asets.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = asets.campaign_id
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

-- What is the average cost per lead (CPL) by campaign?
SELECT 
    c.campaign_name,
    ROUND(SUM(p.cost)::numeric / NULLIF(SUM(p.lead), 0), 2) AS avg_cpl
FROM performance p
JOIN ads a ON a.ad_id = p.ad_id
JOIN adsets asets ON asets.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = asets.campaign_id
WHERE 
  c.objective = 'leads'
GROUP BY c.campaign_name
ORDER BY avg_cpl ASC;

-- Which age group and gender combination results in the most form views for lead campaigns?
SELECT 
    asets.age_range,
    asets.gender,
    SUM(p.form_view) AS total_form_views
FROM performance p
JOIN ads a ON a.ad_id = p.ad_id
JOIN adsets asets ON asets.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = asets.campaign_id
WHERE c.objective = 'leads'
GROUP BY asets.age_range, asets.gender
ORDER BY total_form_views DESC
LIMIT 1;

