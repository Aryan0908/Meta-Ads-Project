SELECT
  p.date::date AS date,
  p.ad_id,
  a.adset_id,
  s.campaign_id,
  ROUND(SUM(p.impressions),2) AS impressions,
  ROUND(SUM(p.clicks),2) AS clicks,
  SUM(p.cost) AS cost,
  SUM(COALESCE(p.revenue,0)) AS revenue,
  SUM(COALESCE(p.view_content,0)) AS view_content,
  SUM(COALESCE(p.add_to_cart,0)) AS add_to_cart,
  SUM(COALESCE(p.initiate_checkout,0)) AS initiate_checkout,
  SUM(COALESCE(p.purchase,0)) AS purchases,
  SUM(COALESCE(p.form_view,0)) AS form_view,
  CASE WHEN SUM(p.impressions) > 0 THEN ROUND(AVG(ctr)::numeric,2) ELSE NULL END AS ctr,
  CASE WHEN SUM(p.clicks) > 0 THEN ROUND(AVG(cpc)::numeric,2) ELSE NULL END AS cpc,
  CASE WHEN SUM(p.impressions) > 0 THEN ROUND(AVG(cpm)::numeric,2) ELSE NULL END AS cpm,
  CASE WHEN SUM(p.cost) > 0 THEN ROUND(SUM(COALESCE(p.revenue,0)::numeric) / SUM(p.cost)::numeric,2) ELSE NULL END AS roas,
  CASE WHEN SUM(COALESCE(p.purchase, 0)) > 0 
       THEN ROUND(SUM(p.cost)::numeric / NULLIF(SUM(COALESCE(p.purchase,0)),0),2) 
       ELSE NULL END AS cpl
FROM performance p
JOIN ads a ON a.ad_id = p.ad_id
JOIN adsets s ON s.adset_id = a.adset_id
JOIN campaigns c ON c.campaign_id = s.campaign_id
GROUP BY 1,2,3,4;
