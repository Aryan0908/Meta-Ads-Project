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
