SELECT
  s.campaign_id,
  p.date,
  SUM(p.cost)        AS total_spend,
  SUM(s.daily_budget) AS total_budget,
  (SUM(p.cost) - SUM(s.daily_budget)) AS overspend_amount
FROM performance p
JOIN ads a
  ON p.ad_id = a.ad_id
JOIN adsets s
  ON a.adset_id = s.adset_id
GROUP BY
  s.campaign_id,
  p.date
HAVING
  SUM(p.cost) > SUM(s.daily_budget);
