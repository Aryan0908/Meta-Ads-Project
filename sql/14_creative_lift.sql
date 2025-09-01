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
			avg_ctr AS rolling_avg,
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
		(row_num = 7
		OR 
		row_num = max_date_num)
)

SELECT 
	creative_name,
	ROUND(((rolling_avg-prev_rolling_avg)/prev_rolling_avg)*100,2) AS creative_life_perc
FROM filtered_dates
WHERE prev_rolling_avg IS NOT NULL

