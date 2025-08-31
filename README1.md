<h1>Meta Ads Performance Analysis: SQL + Power BI</h1>
<p>I built an end-to-end analytics pipeline on a Meta Ads dataset (Campaigns → Adsets → Ads → Daily Performance) to identify wasted spend, diagnose funnel drop-offs, and model “what-if” budget scenarios — using SQL (KPIs + anomalies) and Power BI/DAX (visual representation, rolling metrics, metric switcher, scenario planning)</p>

<section>
  <h2>Why this project?</h2>
  <p>Companies spend heavily on ads but struggle to see where budget is wasted and which levers move ROAS. I designed this project to:</p>
  <ul>
    <li>Turn raw ad logs into <b>business KPIs</b> (CTR, CPC, CPM, ROAS, CPL).</li>
    <li>Learn <b>customer drop-offs</b> at every stage (Form View/Landing Page View -> Add-to-Cart -> Initiate Checkout -> Conversion/Purchase)</li>
    <li>This project helps me build <b>What-if Analysis Dashboard</b></li>
  </ul>
  <h6>Tip for reviewers: demo first — then skim the Deep Dives for how I engineered it.</h6>
</section>

<section>
  <h2>Data Model:</h2>
  <div>
    <h3>Tables:</h3>
    <ul>
      <li>Campaign: campaign_id, objective, daily_budget</li>
      <li>Adsets: adset_id, campaign_id, age_group, gender, placement, device, daily_budget country, objective</li>
      <li>Ads: ad_id, adset_id, ad_format, headline, call_to_action, video_length_sec</li>
      <li>Performance: ad_id, date, reach, impressions, clicks, ctr, cpc, cpm, cost, view_content, add_to_cart, initiate_checkout, purchase, revenue, form_view, lead, engagement,                 app_install, video_view
      </li>
      <li>date table (Power BI)</li>
    </ul>
  </div>
  
  <div>
  <h3>Relationships</h3>
  <p>Campaigns (One) -> Adsets (Many) -> Ads (Many) -> Performance (Many) -> Date Table (One)</p>
  </div>
</section>

<section>
  <h2>What I Built</h2>
  <div>
    <h3>SQL</h3>
    <ol>
      <li>Core KPI's (CTR, CPL, Spend, Revenue, etc.), Top Campaigns By Revenue, CTR by Age Range and Device</li>
      <li>Conversion Funnel Drop-off By Campaign</li>
      <li>Rolling 7-days ROAS by Campaign</li>
      <li>Cross-Objective Creative Lift (First 7-day CTR VS Latest 7-day CTR)</li>
      <li>CPC anomaly detection</li>
    </ol>
    <h6><b>Note:</b> Some of the queries are campaign objective (conversions, leads, traffic, engagement and sale) specific. </h6>
  </div>
  <div>
    <h3>Power BI</h3>
    <ol>
      <li><b>Pages:</b>Overview, Conversion, Conversion Details, Adset Analysis, Creative Analysis and What-If Analysis</li>
      <li><b>DAX Measures:</b> KPI Cards, Metric Selection, 7-Days Rolling ROAS, Metric Selection Buttons, Dynamic Titles  </li>
      <li><b>What-If Analysis:</b> How increase/decrease of Spend/CTR/CPR/CVR/AOV affects overall performance.</li>
    </ol>
  </div>
</section>
