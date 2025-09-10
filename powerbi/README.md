# DAX Documentation (SQL-style writeup)

Each measure is documented like our SQL cards: **What it answers**, **Why it matters**, **View DAX**, **How it’s built**, and **Similar measures**.


## 1) Roas
 👉 **What it answers:**
- Which campaigns/adsets/ads generate the highest return per $1 spent?
- ROAS trend by week/month for top segments
- ROAS by device/placement/audience

👉 **Why it matters:** Shows revenue efficiency of spend; helps rank campaigns/adsets by return.

**View DAX**
```dax
CALCULATE(
    DIVIDE([TotalRevenue], [TotalSpend], 0),
    Campaigns[Objective] = "Conversions"
)
```
🛠️ **How it's built:**
- Numerator: total Revenue scoped to `Objective = "Conversions"`
- Denominator: total Spend in the same filter context
- Use `DIVIDE([TotalRevenue],[TotalSpend])` for safety

👉 **Measures with similar DAX (different base):** Purchase/ClicksConversionRate

## 2) 7D-ROAS
 👉 **What it answers:**
- Is ROAS improving in the last 7 days vs previous 7?
- Which adsets show positive short-term ROAS momentum?

👉 **Why it matters:** Smooths daily ROAS to highlight trend and reduce outlier noise.

**View DAX**
```dax
DIVIDE(
    [7D-Revenue],
    [7D-Spend],
    0
)
```
🛠️ **How it's built:**
- Time window: `DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY)` (7 rows inclusive)
- Use base `7D-*` numerators/denominators for ratios (e.g., 7D-Clicks/7D-Impressions)
- Guard divisions with `DIVIDE()` to avoid divide-by-zero

👉 **Measures with similar DAX (different base):** 7D-AOV, 7D-AtcCR, 7D-CPC, 7D-ConversionRate, 7D-LpvCR, nROAS

## 3) Avg.CTR
 👉 **What it answers:**
- Which creatives/audiences get the highest engagement?
- CTR split by device/placement

👉 **Why it matters:** Indicates creative and audience engagement efficiency.

**View DAX**
```dax
AVERAGE(Performance[CTR])
```
🛠️ **How it's built:**
- Direct `AVERAGE(Performance[Column])` from fact table
- Note: `AVERAGE` (row CTR) may differ from `DIVIDE(Clicks, Impressions)`; choose intentionally

👉 **Measures with similar DAX (different base):** Avg. CPM, Avg. Cpc, Avg. Frequency

## 4) Avg. CPL
 👉 **What it answers:**
- What is the Cost per Lead by adset?
- Top 5 adsets with lowest CPL
- Demographic breakdown of best CPL adsets

👉 **Why it matters:** Direct cost to acquire a lead; core efficiency metric for lead gen.

**View DAX**
```dax
DIVIDE(
    [TotalSpend],
    [TotalLeads]
)
```
🛠️ **How it's built:**
- Compute CPL = Spend / Leads via `DIVIDE([TotalSpend],[TotalLeads])`
- Slice by adset/age/gender/placement for drivers

## 5) 7D-CTR
 👉 **What it answers:**
- Is CTR trending up/down this week?
- Short-term creative performance shifts

👉 **Why it matters:** Short-term CTR momentum for daily monitoring.

**View DAX**
```dax
CALCULATE(DIVIDE([TotalClicks],[TotalImpressions]), DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY))
```
🛠️ **How it's built:**
- Time window: `DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY)` (7 rows inclusive)
- Use base `7D-*` numerators/denominators for ratios (e.g., 7D-Clicks/7D-Impressions)
- Guard divisions with `DIVIDE()` to avoid divide-by-zero

## 6) Purchase/ClicksConversionRate
 👉 **What it answers:**
- Which segments convert clicks into purchases best?
- Landing page effectiveness by audience

👉 **Why it matters:** Click-to-purchase efficiency; signals landing page/offer fit.

**View DAX**
```dax
CALCULATE(
    DIVIDE(
        [TotalPurchases],
        [TotalClicks],
        0
        ),
    Campaigns[Objective] = "Conversions"
)
```
🛠️ **How it's built:**
- Define stage numerator/denominator (e.g., Purchases/Clicks, Purchases/Checkout)
- Keep objective and date filters consistent between numerator and denominator
- Use `DIVIDE()` to handle zero denominators

👉 **Measures with similar DAX (different base):** Roas, LeadsConversionRate

## 7) AddToCartConversionRate
 👉 **What it answers:**
- ATC → Purchase success by segment
- Funnels with high ATC but low purchase (friction points)

👉 **Why it matters:** ATC → Purchase step health; identifies checkout friction.

**View DAX**
```dax
[TotalPurchases] / [TotalAddToCart]
```
🛠️ **How it's built:**
- Define stage numerator/denominator (e.g., Purchases/Clicks, Purchases/Checkout)
- Keep objective and date filters consistent between numerator and denominator
- Use `DIVIDE()` to handle zero denominators

👉 **Measures with similar DAX (different base):** CheckoutConversionRate, RevenuePerPurchase

## 8) 7DaysRollingRoas
 👉 **What it answers:**
- Is ROAS getting more/less stable over time?
- Smooth line for executive dashboards

👉 **Why it matters:** Smoothed ROAS trend; suitable for line charts and alerts.

**View DAX**
```dax
AVERAGEX(
    DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -7, DAY),
    [Roas]
)
```
🛠️ **How it's built:**
- Smooth using `AVERAGEX(DATESINPERIOD(...), [Roas])`
- Use on daily line charts for trends

👉 **Measures with similar DAX (different base):** 7DaysRollingAtrConversionRate, 7DaysRollingRevenue, 7DaysRollingRoi, 7DaysRollingSpend

## 9) RoasStdDeviation
 👉 **What it answers:**
- How noisy is ROAS on a daily basis?
- Which campaigns are most volatile?

👉 **Why it matters:** How variable ROAS is day-to-day; risk/consistency indicator.

**View DAX**
```dax
CALCULATE(
    STDEVX.S(VALUES('Date'[Date]),[Roas]),
    Campaigns[Objective] = "Conversions"
)
```
🛠️ **How it's built:**
- Numerator: total Revenue scoped to `Objective = "Conversions"`
- Denominator: total Spend in the same filter context
- Use `DIVIDE([TotalRevenue],[TotalSpend])` for safety

## 8) RoasVolatility
 👉 **What it answers:**
- Normalized volatility for apples-to-apples ROAS comparison
- Risk-adjusted ranking of segments

👉 **Why it matters:** Std Dev normalized by mean; comparable across segments.

**View DAX**
```dax
CALCULATE(
    DIVIDE([RoasStdDeviation], [RoasDailyAvg]),
    FILTER(Campaigns, Campaigns[Objective] = "Conversions")
)
```
🛠️ **How it's built:**
- Numerator: total Revenue scoped to `Objective = "Conversions"`
- Denominator: total Spend in the same filter context
- Use `DIVIDE([TotalRevenue],[TotalSpend])` for safety

## 9) RoasCurrentMonth
 👉 **What it answers:**
- Current month ROAS by segment
- Which segments improved MoM?

👉 **Why it matters:** This month’s ROAS in isolation for MoM insights.

**View DAX**
```dax
VAR maxMonth = MAX('Date'[MonthNum])

RETURN
CALCULATE(
    [Roas],
    MONTH(performance[date]) = maxMonth
)
```
🛠️ **How it's built:**
- Numerator: total Revenue scoped to `Objective = "Conversions"`
- Denominator: total Spend in the same filter context
- Use `DIVIDE([TotalRevenue],[TotalSpend])` for safety
- Identify month with `EOMONTH` or MonthNum
- Calculate ROAS within month; pair with previous for MoM deltas

👉 **Measures with similar DAX (different base):** ProfitCurrentMonth, PurchasesCurrentMonth, RevenueCurrentMonth, SpendCurrentMonth

## 10) RoasPreviousMonth
 👉 **What it answers:**
- Last month baseline for comparison
- MoM delta calculations

👉 **Why it matters:** Last month’s ROAS baseline for comparison.

**View DAX**
```dax
var startPrevMonth = EOMONTH(MAX('Date'[Date]), -2) + 1
var endPrevMonth = EOMONTH(MAX('Date'[Date]), -1)
RETURN
CALCULATE(
    IF([Roas] > 0, [Roas], 0),
    'Date'[Date] >= startPrevMonth && 'Date'[Date] <= endPrevMonth
)
```
🛠️ **How it's built:**
- Numerator: total Revenue scoped to `Objective = "Conversions"`
- Denominator: total Spend in the same filter context
- Use `DIVIDE([TotalRevenue],[TotalSpend])` for safety
- Identify month with `EOMONTH` or MonthNum
- Calculate ROAS within month; pair with previous for MoM deltas

👉 **Measures with similar DAX (different base):** PurchasesPreviousMonth, RevenuePreviousMonth, SpendPreviousMonth, ProfitPreviousMonth

## 11) RoasCurrentWeek
 👉 **What it answers:**
- Current week ROAS by segment
- Which segments improved WoW?

👉 **Why it matters:** This week’s ROAS for WoW insights.

**View DAX**
```dax
CALCULATE(
    DIVIDE([TotalRevenue], [TotalSpend], 0),
    Campaigns[Objective] = "Conversions",
    'Date'[WeekNum] = MAX('Date'[WeekNum])
)
```
🛠️ **How it's built:**
- Numerator: total Revenue scoped to `Objective = "Conversions"`
- Denominator: total Spend in the same filter context
- Use `DIVIDE([TotalRevenue],[TotalSpend])` for safety
- Identify week using `WEEKNUM`/calendar table
- Calculate ROAS within week; pair with previous for WoW deltas

👉 **Measures with similar DAX (different base):** — LeadsCurrentWeek, RoiCurrentWeek

## 12) RoasPreviousWeek
 👉 **What it answers:**
- Last week baseline for WoW comparison
- WoW delta calculations

👉 **Why it matters:** Last week’s ROAS baseline for comparison.

**View DAX**
```dax
CALCULATE(
    DIVIDE([TotalRevenue], [TotalSpend], 0),
    Campaigns[Objective] = "Conversions",
    'Date'[WeekNum] = MAX('Date'[WeekNum]) - 1
)
```
🛠️ **How it's built:**
- Numerator: total Revenue scoped to `Objective = "Conversions"`
- Denominator: total Spend in the same filter context
- Use `DIVIDE([TotalRevenue],[TotalSpend])` for safety
- Identify week using `WEEKNUM`/calendar table
- Calculate ROAS within week; pair with previous for WoW deltas

👉 **Measures with similar DAX (different base):** — LeadsPreviousWeek, RoiPreviousWeek

## 13) nCPM
 👉 **What it answers:**
- If CPM changes by X%, how do costs shift?
- Scenario testing for auction/seasonality effects

👉 **Why it matters:** Scenario CPM after applying a user-selected change (What‑If).

**View DAX**
```dax
DIVIDE([nSpend], [nImpressions]) * 1000
```
🛠️ **How it's built:**
- Disconnected parameter table → `SELECTEDVALUE('Param'[Value], default)`
- Recompute KPI using adjusted parameter(s) to form scenario
- For `*Text` measures: compare scenario vs baseline and build ▲/▼ strings

👉 **Measures with similar DAX (different base):** —

## 14) nCTR
 👉 **What it answers:**
- If CTR improves by X, how do clicks and downstream metrics change?
- Creative uplift scenarios

👉 **Why it matters:** Scenario CTR after applying a user-selected change (What‑If).

**View DAX**
```dax
VAR entityID = SELECTEDVALUE(EntitySelector[EntityID])
VAR entityType = SELECTEDVALUE(EntitySelector[EntityType])
VAR baseCTR = [7D-CTR]
VAR cvrMult = IF([CtrChange%] = 0, 1, [CtrChange%])
VAR adjustedCTR = baseCTR * cvrMult

RETURN
AVERAGEX (
    SUMMARIZE (
        Adsets,
        Adsets[Adset ID],
        Campaigns[Campaign ID]
    ),
    VAR thisAdset = Adsets[Adset ID]
    VAR thisCampaign = Campaigns[Campaign ID]
    VAR isTargeted =
        SWITCH (
            TRUE(),
            [Scope] = "Global", TRUE(),
            [Scope] = "Campaign" && thisCampaign = entityID, TRUE(),
            [Scope] = "Adset" && thisAdset = entityID, TRUE(),
            FALSE
        )
        
    RETURN 
    IF(isTargeted, adjustedCTR, baseCTR)
)
```
🛠️ **How it's built:**
- Disconnected parameter table → `SELECTEDVALUE('Param'[Value], default)`
- Recompute KPI using adjusted parameter(s) to form scenario
- For `*Text` measures: compare scenario vs baseline and build ▲/▼ strings

👉 **Measures with similar DAX (different base):** —

## 15) nClicks
 👉 **What it answers:**
- Projected clicks with new CTR/Impressions assumptions
- Impact on CPC and funnel

👉 **Why it matters:** Scenario Clicks recalculated from CTR/Impressions changes (What‑If).

**View DAX**
```dax
VAR entityID = SELECTEDVALUE(EntitySelector[EntityID])
RETURN
SUMX(
    SUMMARIZE(
        Adsets,
        Adsets[Adset ID],
        Campaigns[Campaign ID]
    ),
    VAR thisAdset = Adsets[Adset ID]
    VAR thisCampaign = Campaigns[Campaign ID]
    VAR baseImpressions = CALCULATE([7D-Impressions], Adsets[Adset ID] = thisAdset)
    VAR baseCTR = CALCULATE([7D-CTR], Adsets[Adset ID] = thisAdset)
    VAR isTargeted =
        SWITCH(
            TRUE(),
            [Scope] = "Global", TRUE(),
            [Scope] = "Campaign" && thisCampaign = entityID, TRUE(),
            [Scope] = "Adset" && thisAdset = entityID, TRUE(),
            FALSE
        )
    VAR mult = IF(isTargeted, [CtrChange%], 1)
    RETURN 
    baseImpressions * (baseCTR * mult)
)
```
🛠️ **How it's built:**
- Disconnected parameter table → `SELECTEDVALUE('Param'[Value], default)`
- Recompute KPI using adjusted parameter(s) to form scenario
- For `*Text` measures: compare scenario vs baseline and build ▲/▼ strings

👉 **Measures with similar DAX (different base):** —

## 16) nImpressions
 👉 **What it answers:**
- Projected reach given CPM/Budget changes
- Impact on CTR/CPC

👉 **Why it matters:** Scenario Impressions after CPM/Spend changes (What‑If).

**View DAX**
```dax
VAR entityID = SELECTEDVALUE(EntitySelector[EntityID]) 
VAR entityType = SELECTEDVALUE(EntitySelector[EntityType])

RETURN
SUMX (
    SUMMARIZE( 
        Adsets, 
        Adsets[Adset ID], 
        Campaigns[Campaign ID] 
        ),
    VAR thisAdset   = Adsets[Adset ID]
    VAR thisCampaign = Campaigns[Campaign ID]
    VAR baseSpend = CALCULATE([7D-Spend], Adsets[Adset ID] = thisAdset)
    VAR baseCPM = CALCULATE([7D-CPM], Adsets[Adset ID] = thisAdset)
    VAR IsTargeted = 
    SWITCH ( 
        TRUE(), 
        [Scope] = "Global", TRUE(), 
        [Scope] = "Campaign" && thisCampaign = entityID, TRUE(), 
        [Scope] = "Adset" && ThisAdset = entityID, TRUE(), FALSE 
    )
    VAR sMult = IF( isTargeted, [SpendChange%], 1 )
    VAR cpmMult = IF( isTargeted, [CpmChange%] , 1 )
    VAR nSpendRow = baseSpend * sMult
    VAR nCpmRow = baseCPM  * cpmMult

    RETURN 
    DIVIDE( nSpendRow, nCpmRow ) * 1000
)
```
🛠️ **How it's built:**
- Disconnected parameter table → `SELECTEDVALUE('Param'[Value], default)`
- Recompute KPI using adjusted parameter(s) to form scenario
- For `*Text` measures: compare scenario vs baseline and build ▲/▼ strings

👉 **Measures with similar DAX (different base):** —

## 17) nRevenue
 👉 **What it answers:**
- Projected revenue given CR/ATC rates
- Upside case vs baseline

👉 **Why it matters:** Scenario Revenue from modified rates or conversion assumptions (What‑If).

**View DAX**
```dax
VAR entityID   = SELECTEDVALUE(EntitySelector[EntityID])
VAR rowsForScenario =
    SUMMARIZE(
        Adsets,
        Adsets[Adset ID],
        Campaigns[Campaign ID]
    )
RETURN
SUMX(
    rowsForScenario,
    VAR thisAdset    = Adsets[Adset ID]
    VAR thisCampaign = Campaigns[Campaign ID]
    VAR BaseAOV =
        CALCULATE([7D-AOV],
            KEEPFILTERS(Adsets[Adset ID] = thisAdset)
        )
    VAR IsTargeted =
        SWITCH( TRUE(),
            [Scope] = "Global", TRUE(),
            [Scope] = "Campaign" && thisCampaign = entityID, TRUE(),
            [Scope] = "Adset" && thisAdset = entityID, TRUE(),
            FALSE
        )
    VAR AOVmult = IF(IsTargeted, [AOVChange%], 1)
    VAR nPurch_row =
        CALCULATE([nPurchase],
            KEEPFILTERS(Adsets[Adset ID] = thisAdset)
        )

    RETURN 
    (BaseAOV * AOVmult) * nPurch_row
)
```
🛠️ **How it's built:**
- Disconnected parameter table → `SELECTEDVALUE('Param'[Value], default)`
- Recompute KPI using adjusted parameter(s) to form scenario
- For `*Text` measures: compare scenario vs baseline and build ▲/▼ strings

👉 **Measures with similar DAX (different base):** —

## 18) nSpend
 👉 **What it answers:**
- Projected spend given CPM/budget tweaks
- Budget planning scenarios

👉 **Why it matters:** Scenario Spend after budget/bid adjustments (What‑If).

**View DAX**
```dax
VAR entityID = SELECTEDVALUE(EntitySelector[EntityID])
VAR entityType = SELECTEDVALUE(EntitySelector[EntityType])
RETURN
SUMX (
    SUMMARIZE (
        Adsets,
        Adsets[Adset ID],
        Campaigns[Campaign ID]
    ),
    VAR thisAdset = Adsets[Adset ID]
    VAR thisCampaign = Campaigns[Campaign ID]
    VAR baseSpend = CALCULATE([7D-Spend], Adsets[Adset ID] = thisAdset)
    VAR IsTargeted =
        SWITCH (
            TRUE(),
            [Scope] = "Global", TRUE(),
            [Scope] = "Campaign" && thisCampaign = entityID, TRUE(),
            [Scope] = "Adset" && thisAdset = entityID, TRUE(),
            FALSE
        )

    RETURN 
    IF(IsTargeted, baseSpend * [SpendChange%], baseSpend)
)
```
🛠️ **How it's built:**
- Disconnected parameter table → `SELECTEDVALUE('Param'[Value], default)`
- Recompute KPI using adjusted parameter(s) to form scenario
- For `*Text` measures: compare scenario vs baseline and build ▲/▼ strings

👉 **Measures with similar DAX (different base):** —

## 19) nPurchase
 👉 **What it answers:**
- Projected purchases under improved conversion rates
- Funnel uplift scenarios

👉 **Why it matters:** Scenario Purchases after conversion changes (What‑If).

**View DAX**
```dax
VAR entityID = SELECTEDVALUE(EntitySelector[EntityID])
VAR entityType = SELECTEDVALUE(EntitySelector[EntityType])
RETURN
SUMX (
    SUMMARIZE (
        Adsets,
        Adsets[Adset ID],
        Campaigns[Campaign ID]
    ),
    VAR thisAdset = Adsets[Adset ID]
    VAR thisCampaign = Campaigns[Campaign ID]
    VAR baseSpend = CALCULATE([7D-Spend], Adsets[Adset ID]=thisAdset)
    VAR baseCTR = CALCULATE([7D-CTR], Adsets[Adset ID]=thisAdset)
    VAR baseCPM = CALCULATE([7D-CPM], Adsets[Adset ID]=thisAdset)
    VAR baseCVR = CALCULATE([7D-ConversionRate], Adsets[Adset ID]=thisAdset)
    VAR IsTargeted =
        SWITCH (
            TRUE(),
            [Scope] = "Global", TRUE(),
            [Scope] = "Campaign" && thisCampaign = entityID, TRUE(),
            [Scope] = "Adset" && thisAdset = entityID, TRUE(),
            FALSE
        )
    VAR sMult = IF(IsTargeted, [SpendChange%], 1)
    VAR cpmMult = IF(IsTargeted, [CpmChange%] , 1)
    VAR ctrMult = IF(IsTargeted, [CtrChange%], 1)
    VAR cvrMult = IF(IsTargeted, [CvrChange%], 1)
    VAR nSpend = baseSpend * sMult
    VAR nCpm = baseCPM * cpmMult
    VAR nImpressions = DIVIDE(nSpend, nCpm) * 1000
    VAR adjCTR = MIN(1, MAX(0, baseCTR * ctrMult))
    VAR adjCVR = MIN(1, MAX(0, baseCVR * cvrMult))
    VAR nClicks = nImpressions * adjCTR
    VAR elasticity = SELECTEDVALUE('Purchase Elasticity'[Purchase Elasticity], 1)
    VAR growth = DIVIDE( nSpend, baseSpend, BLANK() )
    VAR mech = nClicks * adjCVR

    RETURN 
    IF(ISBLANK(growth), mech, mech * POWER(growth, elasticity))
)
```
🛠️ **How it's built:**
- Disconnected parameter table → `SELECTEDVALUE('Param'[Value], default)`
- Recompute KPI using adjusted parameter(s) to form scenario
- For `*Text` measures: compare scenario vs baseline and build ▲/▼ strings

## 20) nCPMText
 👉 **What it answers:**
- Readable badge ▲▼ for CPM change
- Tooltip explanations

👉 **Why it matters:** Readable ▲/▼ label for scenario CPM change vs baseline.

**View DAX**
```dax
VAR diff = IF([7D-CPM] <> 0, ([nCPM] - [7D-CPM])/[7D-CPM], 0)
VAR roundDiff = (ROUND(diff, 2)) * 100
VAR eps = 0.0005

RETURN
SWITCH(
    TRUE(),
    roundDiff > eps, "▲ " & roundDiff & "%",
    roundDiff < -eps, "▼ " & roundDiff & "%",
    "-"
)
```
🛠️ **How it's built:**
- Disconnected parameter table → `SELECTEDVALUE('Param'[Value], default)`
- Recompute KPI using adjusted parameter(s) to form scenario
- For `*Text` measures: compare scenario vs baseline and build ▲/▼ strings

👉 **Measures with similar DAX (different base):** nAOVText, nCTRText, nClicksText, nImpressionsText, nPurchasesText, nROASText, nRevenueText, nSpendText
