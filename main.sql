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
