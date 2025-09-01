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
