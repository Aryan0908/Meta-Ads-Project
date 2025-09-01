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
