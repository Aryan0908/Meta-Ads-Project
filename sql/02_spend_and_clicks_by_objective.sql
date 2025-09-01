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
