-- Total Campaign Spend and Clicks by Objective
SELECT 
	c.objective,
	SUM(p.clicks) AS total_clicks,
	SUM(p.cost) AS total_cost
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
	SUM(p.revenue) AS total_revenue
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
	ROUND(AVG(p.ctr),2) AS avg_ctr
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


Campaign Funnel Drop-off
Objective(s): traffic, conversions.

Campaigns Exceeding Daily Budget
Objective(s): All campaign objectives (e.g., conversions, leads, traffic, engagement, reach, app_installs).

Average Revenue by Ad Format for Conversion Campaigns
Objective(s): conversions.

🔴 Advanced SQL Questions (Q11 – Q15)
Top-Performing Creative by Adset
Objective(s): All campaign objectives (e.g., conversions, leads, traffic, engagement, reach, app_installs).

Rolling 7-Day Average ROAS
Objective(s): conversions, traffic.

Attribution Breakdown for Purchases
Objective(s): conversions.

Geographic Performance Comparison
Objective(s): All campaign objectives (e.g., conversions, leads, traffic, engagement, reach, app_installs).

CPC Anomaly Detection
Objective(s): All campaign objectives (e.g., conversions, leads, traffic, engagement, reach, app_installs).
