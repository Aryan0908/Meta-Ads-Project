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
