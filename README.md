<h1>Meta Ads Performance Analysis: SQL + Power BI</h1>
<p>I built an end-to-end analytics pipeline on a Meta Ads dataset (Campaigns → Adsets → Ads → Daily Performance) to identify wasted spend, diagnose funnel drop-offs, and model “what-if” budget scenarios — using SQL (KPIs + anomalies) and Power BI/DAX (visual representation, rolling metrics, metric switcher, scenario planning)</p>
<div>
  <h2>Why this project?</h2>
  <p>Companies spend heavily on ads but struggle to see where budget is wasted and which levers move ROAS. I designed this project to:</p>
  <ul>
    <li>Turn raw ad logs into <b>business KPIs</b> (CTR, CPC, CPM, ROAS, CPL).</li>
    <li>Learn <b>customer drop-offs</b> at every stage (Form View/Landing Page View -> Add-to-Cart -> Initiate Checkout -> Conversion/Purchase)</li>
    <li>This project helps me build <b>What-if Analysis Dashboard</b></li>
  </ul>
  <h6>Tip for reviewers: demo first — then skim the Deep Dives for how I engineered it.</h6>
</div>
<div>
  <h2>Data Model:</h2>
  <div>
    <h3>Tables:</h3>
    <ul>
      <li>campaign: campaign_id, objective, daily_budget</li>
      <li>adsets: adset_id, campaign_id, age_group, gender, placement, device, daily_budget country, objective</li>
      <li>ads: ad_id, adset_id, ad_format, headline, call_to_action, video_length_sec</li>
      <li>performance: ad_id, date, reach, impressions, clicks, ctr, cpc, cpm, cost, view_content, add_to_cart, initiate_checkout, purchase, revenue, form_view, lead, engagement,                 app_install, video_view
      </li>
      <li>date table (Power BI)</li>
    </ul>
  </div>
  
  <div>
  <h3>Relationships</h3>
  <p>Campaigns (One) -> Adsets (Many) -> Ads (Many) -> Performance (Many) -> Date Table (One)</p>
  </div>
  
</div>
