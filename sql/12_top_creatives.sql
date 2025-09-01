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
