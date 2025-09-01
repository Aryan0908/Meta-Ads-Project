WITH daily AS (
  SELECT
    c.campaign_id,
    p.date,
    SUM(p.revenue) AS day_revenue,
    SUM(p.cost) AS day_cost
  FROM performance p
  JOIN ads a ON a.ad_id = p.ad_id
  JOIN adsets s ON s.adset_id = a.adset_id
  JOIN campaigns c ON c.campaign_id = s.campaign_id
  WHERE c.objective IN ('conversions','traffic')
  GROUP BY c.campaign_id, p.date
),
rolling AS (
  SELECT
    campaign_id,
    date,
    SUM(day_revenue) OVER (PARTITION BY campaign_id ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rev_7d,
    SUM(day_cost) OVER (PARTITION BY campaign_id ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS cost_7d
  FROM daily
),
roas AS (
  SELECT
    campaign_id,
    date,
    CASE WHEN cost_7d = 0 THEN NULL ELSE rev_7d / cost_7d END AS roas_7d
  FROM rolling
),
final AS (
  SELECT
    campaign_id,
    date,
    roas_7d,
    LAG(roas_7d, 7) OVER (PARTITION BY campaign_id ORDER BY date) AS prev_roas_7d,
    ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY date DESC) AS rn
  FROM roas
)

SELECT
  campaign_id,
  date,
  ROUND(roas_7d, 2) AS current_week_roas,
  ROUND(prev_roas_7d, 2) AS prev_week_roas,
  ROUND( (roas_7d - prev_roas_7d) / NULLIF(prev_roas_7d, 0) * 100, 2) AS seven_day_roas_change
FROM final
WHERE rn = 1
  AND prev_roas_7d IS NOT NULL;
