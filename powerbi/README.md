# Meta Ads Power BI — DAX Documentation (Explained)

This guide documents **what each important measure does**, **how it’s built**, and the **thinking behind the design**—so reviewers can see both your business logic and your DAX craft.

## How to Read This
- **Concept:** Plain-language definition and business intent.
- **Logic blueprint:** Why the numerator/denominator and filters are chosen; context assumptions.
- **DAX:** The actual formula.
- **Dependencies:** The building blocks this measure uses.
- **Edge cases & pitfalls:** Division by zero, filter traps, time intelligence gotchas.
- **Variants & reuse:** Same pattern with other bases/dimensions.

## KPI Families (Mental Model)
- **Base Totals:** Spend, Revenue, Purchases, Clicks, Impressions (often filtered to `Objective = "Conversions"`).
- **Ratios:** CTR (Clicks/Impressions), ROAS (Revenue/Spend), CPL (Spend/Leads), Conversion Rates (stage-to-stage).
- **Time Windows:** 7-day base measures (`7D-*`) plus rolling averages over time.
- **Periods:** Current vs Previous (WoW/MoM) blocks.
- **Scenario Layer:** What-If (`n*`) measures + ▲/▼ text badges.

### Roas
**Concept:** Return on Ad Spend — how much revenue you earned per 1 unit of spend in the current filter context.

**Logic blueprint:**
- **Numerator:** Revenue from `Performance` (Conversions objective) ensures we attribute revenue only from conversion campaigns.
- **Denominator:** Total Spend in the same filter context.
- **Context:** Inherits slice-by from `Date`, `Campaigns`, `Adsets`, `Ads`.

**DAX:**
```dax
CALCULATE(
    DIVIDE([TotalRevenue], [TotalSpend], 0),
    Campaigns[Objective] = "Conversions"
)
```

**Dependencies:** Objective, TotalRevenue, TotalSpend

**Edge cases & pitfalls:** - Use `DIVIDE` instead of `/` to gracefully handle zero spend.
- Ensure `TotalRevenue` and `TotalSpend` are scoped consistently (e.g., objective filter).

**Variants & reuse:** - `7D-ROAS` uses 7-day windows for both revenue and spend.
- You can compute **ROAS change** by comparing to previous period or 7D baseline.

**Used by (examples):** 7DaysRollingRoas, BestWeek, BestWeekROAS, ConversionSelectedMetric, Max. ROAS, Min. ROAS, RoasCurrentMonth, RoasDailyAvg


### 7D-ROAS
**Concept:** ROAS smoothed over the last 7 days to reduce daily volatility.

**Logic blueprint:**
- Build 7-day `Revenue` and `Spend` with `DATESINPERIOD(..., -6, DAY)` (inclusive 7 rows), then `DIVIDE`.

**DAX:**
```dax
DIVIDE(
    [7D-Revenue],
    [7D-Spend],
    0
)
```

**Dependencies:** 7D-Revenue, 7D-Spend

**Edge cases & pitfalls:** - The 7-day window is **relative to the max visible date**; make sure your date slicers are aligned.
- Beware partial weeks on edges of the dataset.

**Variants & reuse:** - The same template applies to CTR (`7D-CTR`), CPC (`7D-CPC`), ConversionRate (`7D-ConversionRate`).

**Used by (examples):** 7D-MetricSDelection, Overall-WhatIf-Summary, nROASText


### Avg.CTR
**Concept:** Overall click-through rate used for quick glance; taken directly as an average of the CTR column.

**Logic blueprint:**
- When CTR exists as a stored column, `AVERAGE(CTR)` is acceptable for **cards**. For **exact CTR**, prefer `DIVIDE([TotalClicks],[TotalImpressions])`.

**DAX:**
```dax
AVERAGE(Performance[CTR])
```

**Dependencies:** CTR

**Edge cases & pitfalls:** - `AVERAGE` of row-level CTR can differ from `Clicks/Impressions` if the distribution is skewed.

**Variants & reuse:** - `7D-CTR` replaces totals with 7D-totals to smooth fluctuations.

**Used by (examples):** BestWeekCtr, CTR_WOW, CreativePerformanceRecommendation_Text, CreativeSelectedMetric_CTR/CPC, WorstWeekCTR


### 7D-CTR
**Concept:** CTR smoothed over the last 7 days.

**Logic blueprint:**
- Compute `7D-Clicks` and `7D-Impressions` via `CALCULATE(..., DATESINPERIOD(...))`, then `DIVIDE`.

**DAX:**
```dax
CALCULATE(DIVIDE([TotalClicks],[TotalImpressions]), DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY))
```

**Dependencies:** Date, TotalClicks, TotalImpressions

**Edge cases & pitfalls:** - If impressions are 0 in the 7D window, `DIVIDE` guards against errors.

**Variants & reuse:** - Same approach extends to other ratios like Conversion Rates.

**Used by (examples):** 7D-MetricSDelection, Overall-WhatIf-Summary, nCTR, nCTRText, nClicks, nPurchase, ΔRevenue (Waterfall)


### Avg. Cpc
**Concept:** Average Cpc in the current context.

**Logic blueprint:**
- Simple `AVERAGE` reads fact-level column; good for directional monitoring.

**DAX:**
```dax
AVERAGE(Performance[CPC])
```

**Dependencies:** CPC

**Edge cases & pitfalls:** - For **CPC**, the exact value is `Spend/Clicks`; `AVERAGE(CPC)` and `Spend/Clicks` can diverge. Choose based on your reporting intent.

**Variants & reuse:** - 7-day variants (`7D-CPC`, `7D-CPM`) use 7-day numerators/denominators.

**Used by (examples):** CPC_WOW, CreativeSelectedMetric_CTR/CPC


### Avg. CPM
**Concept:** Average CPM in the current context.

**Logic blueprint:**
- Simple `AVERAGE` reads fact-level column; good for directional monitoring.

**DAX:**
```dax
AVERAGE(Performance[CPM])
```

**Dependencies:** CPM

**Edge cases & pitfalls:** - For **CPC**, the exact value is `Spend/Clicks`; `AVERAGE(CPC)` and `Spend/Clicks` can diverge. Choose based on your reporting intent.

**Variants & reuse:** - 7-day variants (`7D-CPC`, `7D-CPM`) use 7-day numerators/denominators.


### LeadsConversionRate
**Concept:** Probability of users progressing to the next stage (e.g., Click → Lead, Checkout → Purchase).

**Logic blueprint:**
- Define upstream/downstream events clearly (e.g., **Purchases/Clicks**, **Leads/Clicks**, **Purchases/InitiateCheckout**).
- Keep scope: many totals are restricted to `Objective="Conversions"` to avoid polluting rates.

**DAX:**
```dax
CALCULATE(
    DIVIDE(
        [TotalLeads],
        [TotalLeadFormViews]
    ),
    Campaigns[Objective] = "Leads"
)
```

**Dependencies:** Objective, TotalLeadFormViews, TotalLeads

**Edge cases & pitfalls:** - Stage definitions must be mutually consistent (same filters, same date granularity).
- Use `DIVIDE` to handle 0 denominators.

**Variants & reuse:** - Provide 7D versions by swapping in `7D-*` numerators/denominators.
- Add **drop-off** metrics as `1 - ConversionRate`.

**Used by (examples):** LeadsConversionRateText


### Purchase/ClicksConversionRate
**Concept:** Probability of users progressing to the next stage (e.g., Click → Lead, Checkout → Purchase).

**Logic blueprint:**
- Define upstream/downstream events clearly (e.g., **Purchases/Clicks**, **Leads/Clicks**, **Purchases/InitiateCheckout**).
- Keep scope: many totals are restricted to `Objective="Conversions"` to avoid polluting rates.

**DAX:**
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

**Dependencies:** Objective, TotalClicks, TotalPurchases

**Edge cases & pitfalls:** - Stage definitions must be mutually consistent (same filters, same date granularity).
- Use `DIVIDE` to handle 0 denominators.

**Variants & reuse:** - Provide 7D versions by swapping in `7D-*` numerators/denominators.
- Add **drop-off** metrics as `1 - ConversionRate`.


### Avg. CPL
**Concept:** Average cost to acquire a lead — a key financial efficiency metric.

**Logic blueprint:**
- `DIVIDE(Spend, Leads)` in the current context; can be computed in 7D or by segment.

**DAX:**
```dax
DIVIDE(
    [TotalSpend],
    [TotalLeads]
)
```

**Dependencies:** TotalLeads, TotalSpend

**Edge cases & pitfalls:** - Validate **Leads** definition (form submits vs qualified leads). 0 leads → guard with `DIVIDE`.

**Variants & reuse:** - Add **CPL change** vs last 7 days or previous month for dashboards.

**Used by (examples):** LeadsSelectedMetric


### AddToCartConversionRate
**Concept:** Probability of users progressing to the next stage (e.g., Click → Lead, Checkout → Purchase).

**Logic blueprint:**
- Define upstream/downstream events clearly (e.g., **Purchases/Clicks**, **Leads/Clicks**, **Purchases/InitiateCheckout**).
- Keep scope: many totals are restricted to `Objective="Conversions"` to avoid polluting rates.

**DAX:**
```dax
[TotalPurchases] / [TotalAddToCart]
```

**Dependencies:** TotalAddToCart, TotalPurchases

**Edge cases & pitfalls:** - Stage definitions must be mutually consistent (same filters, same date granularity).
- Use `DIVIDE` to handle 0 denominators.

**Variants & reuse:** - Provide 7D versions by swapping in `7D-*` numerators/denominators.
- Add **drop-off** metrics as `1 - ConversionRate`.

**Used by (examples):** 7DaysRollingAtrConversionRate


### CheckoutConversionRate
**Concept:** Probability of users progressing to the next stage (e.g., Click → Lead, Checkout → Purchase).

**Logic blueprint:**
- Define upstream/downstream events clearly (e.g., **Purchases/Clicks**, **Leads/Clicks**, **Purchases/InitiateCheckout**).
- Keep scope: many totals are restricted to `Objective="Conversions"` to avoid polluting rates.

**DAX:**
```dax
[TotalPurchases] / [TotalInititateCheckout]
```

**Dependencies:** TotalInititateCheckout, TotalPurchases

**Edge cases & pitfalls:** - Stage definitions must be mutually consistent (same filters, same date granularity).
- Use `DIVIDE` to handle 0 denominators.

**Variants & reuse:** - Provide 7D versions by swapping in `7D-*` numerators/denominators.
- Add **drop-off** metrics as `1 - ConversionRate`.


### 7D-ConversionRate
**Concept:** Probability of users progressing to the next stage (e.g., Click → Lead, Checkout → Purchase).

**Logic blueprint:**
- Define upstream/downstream events clearly (e.g., **Purchases/Clicks**, **Leads/Clicks**, **Purchases/InitiateCheckout**).
- Keep scope: many totals are restricted to `Objective="Conversions"` to avoid polluting rates.

**DAX:**
```dax
DIVIDE(
    [7D-Purchases],
    [7D-Clicks],
    0
)
```

**Dependencies:** 7D-Clicks, 7D-Purchases

**Edge cases & pitfalls:** - Stage definitions must be mutually consistent (same filters, same date granularity).
- Use `DIVIDE` to handle 0 denominators.

**Variants & reuse:** - Provide 7D versions by swapping in `7D-*` numerators/denominators.
- Add **drop-off** metrics as `1 - ConversionRate`.

**Used by (examples):** 7D-MetricSDelection, nCVR, nPurchase, ΔRevenue (Waterfall)


### TotalSpend
**Concept:** Base total for spend used by multiple KPIs.

**Logic blueprint:**
- Typically a `SUM` over the fact column; **reused** across many downstream measures.
- Revenue/Purchases often constrained to `Objective="Conversions"`.

**DAX:**
```dax
SUM(Performance[Cost])
```

**Dependencies:** Cost

**Edge cases & pitfalls:** - Keep filters consistent across totals feeding a ratio to avoid mismatched scopes.

**Variants & reuse:** - Dimension variants: by **Campaign**, **Adset**, **Ad**, **Device**, etc.

**Used by (examples):** 7D-Spend, 7DaysRollingSpend, Avg. CPL, Avg. Daily Spend, BestWeekSpend, CostPerPurchase, Min. ROAS, Profit/Loss


### TotalRevenue
**Concept:** Base total for revenue used by multiple KPIs.

**Logic blueprint:**
- Typically a `SUM` over the fact column; **reused** across many downstream measures.
- Revenue/Purchases often constrained to `Objective="Conversions"`.

**DAX:**
```dax
CALCULATE(
    SUM(Performance[Revenue]),
    Campaigns[Objective] = "Conversions"
)
```

**Dependencies:** Objective, Revenue

**Edge cases & pitfalls:** - Keep filters consistent across totals feeding a ratio to avoid mismatched scopes.

**Variants & reuse:** - Dimension variants: by **Campaign**, **Adset**, **Ad**, **Device**, etc.

**Used by (examples):** 7D-Revenue, 7DaysRollingRevenue, Avg. Daily Revenue, BestWeekRevenue, ConversionSelectedMetric, CreativeSelectedMetric_Purchase/Revenue, Profit/Loss, RevenueCurrentMonth


### TotalPurchases
**Concept:** Base total for purchases used by multiple KPIs.

**Logic blueprint:**
- Typically a `SUM` over the fact column; **reused** across many downstream measures.
- Revenue/Purchases often constrained to `Objective="Conversions"`.

**DAX:**
```dax
CALCULATE(
    SUM(Performance[Purchase]),
    Campaigns[Objective] = "Conversions"
)
```

**Dependencies:** Objective, Purchase

**Edge cases & pitfalls:** - Keep filters consistent across totals feeding a ratio to avoid mismatched scopes.

**Variants & reuse:** - Dimension variants: by **Campaign**, **Adset**, **Ad**, **Device**, etc.

**Used by (examples):** 7D-Purchases, AddToCartConversionRate, Avg. DailyPurchase, CheckoutConversionRate, CostPerPurchase, CreativeSelectedMetric_Purchase/Revenue, Purchase/ClicksConversionRate, PurchasesCurrentMonth


### TotalClicks
**Concept:** Base total for clicks used by multiple KPIs.

**Logic blueprint:**
- Typically a `SUM` over the fact column; **reused** across many downstream measures.
- Revenue/Purchases often constrained to `Objective="Conversions"`.

**DAX:**
```dax
SUM(Performance[Clicks])
```

**Dependencies:** Clicks

**Edge cases & pitfalls:** - Keep filters consistent across totals feeding a ratio to avoid mismatched scopes.

**Variants & reuse:** - Dimension variants: by **Campaign**, **Adset**, **Ad**, **Device**, etc.

**Used by (examples):** 7D-CTR, 7D-Clicks, Purchase/ClicksConversionRate


### TotalImpressions
**Concept:** Base total for impressions used by multiple KPIs.

**Logic blueprint:**
- Typically a `SUM` over the fact column; **reused** across many downstream measures.
- Revenue/Purchases often constrained to `Objective="Conversions"`.

**DAX:**
```dax
SUM(Performance[Impressions])
```

**Dependencies:** Impressions

**Edge cases & pitfalls:** - Keep filters consistent across totals feeding a ratio to avoid mismatched scopes.

**Variants & reuse:** - Dimension variants: by **Campaign**, **Adset**, **Ad**, **Device**, etc.

**Used by (examples):** 7D-CTR, 7D-Impressions


## Reusable Templates

### 7-Day Window on a Base Measure
**Why:** Stabilize noisy daily metrics; keep logic consistent across KPIs.
- Use the same `DATESINPERIOD` selector; swap **only** the base measure.

**Example (`7D-Clicks`):**
```dax
CALCULATE([TotalClicks], DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY))
```
**Gotchas:** Relative to the **max visible date**; beware gaps in dates.

### Rolling Averages Over Time (Smoothing)
**Why:** Smooths short-term noise for trend lines.
- `AVERAGEX(DATESINPERIOD(...), [DailyKPI])`: iterate over dates and average the KPI.

**Example (`7DaysRollingRoas`):**
```dax
AVERAGEX(
    DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -7, DAY),
    [Roas]
)
```
**Gotchas:** Rolling average ≠ 7D ratio; choose appropriately for the story.

### Current vs Previous Period Blocks (WoW/MoM)
**Why:** Attribute change to period effects.
- Compute current and previous period with `EOMONTH`/`WEEKNUM`, then `CALCULATE([Measure], <period filter>)`.

**Example (`RoasCurrentMonth`):**
```dax
VAR maxMonth = MAX('Date'[MonthNum])

RETURN
CALCULATE(
    [Roas],
    MONTH(performance[date]) = maxMonth
)
```
**Gotchas:** Fiscal calendars vs ISO weeks; alignment with slicers.

## What‑If Analysis (Scenario Layer)
**Goal:** Project KPI movement when inputs like CTR or CPM change.
- Disconnected **parameter tables** feed `SELECTEDVALUE` for user inputs.
- `n*` measures recompute KPIs using adjusted inputs.
- Text measures (e.g., `nCPMText`) render ▲/▼ with percentage change.

**Parameter tables detected:** AOV Change %, CPM Change %, CTR Change %, CVR Change %, Date, Demographics Legend, Leads/CPL Metric Selection, Metric Selection, Purchase Elasticity, Purchase/Revenue Metric Selection, ROAS/CTR Metric Selection, ROAS/ROI/Spend Metric Selection, ROAS/Revenue Metric Selection, Scenario Scope, Spend Change %, Waterfall Steps

### nCPM
**Concept:** Scenario version of `CPM` (or its KPI text). It applies user input(s) via `SELECTEDVALUE` and recomputes.

**DAX:**
```dax
DIVIDE([nSpend], [nImpressions]) * 1000
```

**Dependencies:** nImpressions, nSpend

**Edge cases & pitfalls:** Ensure defaults in `SELECTEDVALUE(..., default)`; clamp unrealistic values; keep units consistent (percent vs decimal).

### nCTR
**Concept:** Scenario version of `CTR` (or its KPI text). It applies user input(s) via `SELECTEDVALUE` and recomputes.

**DAX:**
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

**Dependencies:** 7D-CTR, Adset ID, Campaign ID, CtrChange%, EntityID, EntityType, Scope

**Edge cases & pitfalls:** Ensure defaults in `SELECTEDVALUE(..., default)`; clamp unrealistic values; keep units consistent (percent vs decimal).

### nClicks
**Concept:** Scenario version of `Clicks` (or its KPI text). It applies user input(s) via `SELECTEDVALUE` and recomputes.

**DAX:**
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

**Dependencies:** 7D-CTR, 7D-Impressions, Adset ID, Campaign ID, CtrChange%, EntityID, Scope

**Edge cases & pitfalls:** Ensure defaults in `SELECTEDVALUE(..., default)`; clamp unrealistic values; keep units consistent (percent vs decimal).

### nImpressions
**Concept:** Scenario version of `Impressions` (or its KPI text). It applies user input(s) via `SELECTEDVALUE` and recomputes.

**DAX:**
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

**Dependencies:** 7D-CPM, 7D-Spend, Adset ID, Campaign ID, CpmChange%, EntityID, EntityType, Scope, SpendChange%

**Edge cases & pitfalls:** Ensure defaults in `SELECTEDVALUE(..., default)`; clamp unrealistic values; keep units consistent (percent vs decimal).

### nRevenue
**Concept:** Scenario version of `Revenue` (or its KPI text). It applies user input(s) via `SELECTEDVALUE` and recomputes.

**DAX:**
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

**Dependencies:** 7D-AOV, AOVChange%, Adset ID, Campaign ID, EntityID, Scope, nPurchase

**Edge cases & pitfalls:** Ensure defaults in `SELECTEDVALUE(..., default)`; clamp unrealistic values; keep units consistent (percent vs decimal).

### nSpend
**Concept:** Scenario version of `Spend` (or its KPI text). It applies user input(s) via `SELECTEDVALUE` and recomputes.

**DAX:**
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

**Dependencies:** 7D-Spend, Adset ID, Campaign ID, EntityID, EntityType, Scope, SpendChange%

**Edge cases & pitfalls:** Ensure defaults in `SELECTEDVALUE(..., default)`; clamp unrealistic values; keep units consistent (percent vs decimal).

### nPurchase
**Concept:** Scenario version of `Purchase` (or its KPI text). It applies user input(s) via `SELECTEDVALUE` and recomputes.

**DAX:**
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

**Dependencies:** 7D-CPM, 7D-CTR, 7D-ConversionRate, 7D-Spend, Adset ID, Campaign ID, CpmChange%, CtrChange%, CvrChange%, EntityID, EntityType, Purchase Elasticity, Scope, SpendChange%

**Edge cases & pitfalls:** Ensure defaults in `SELECTEDVALUE(..., default)`; clamp unrealistic values; keep units consistent (percent vs decimal).

### nCPMText
**Concept:** Scenario version of `CPMText` (or its KPI text). It applies user input(s) via `SELECTEDVALUE` and recomputes.

**DAX:**
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

**Dependencies:** 7D-CPM, nCPM

**Edge cases & pitfalls:** Ensure defaults in `SELECTEDVALUE(..., default)`; clamp unrealistic values; keep units consistent (percent vs decimal).

### nCTRText
**Concept:** Scenario version of `CTRText` (or its KPI text). It applies user input(s) via `SELECTEDVALUE` and recomputes.

**DAX:**
```dax
VAR diff = IF([7D-CTR] <> 0, ([nCTR] - [7D-CTR])/[7D-CTR], 0)
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

**Dependencies:** 7D-CTR, nCTR

**Edge cases & pitfalls:** Ensure defaults in `SELECTEDVALUE(..., default)`; clamp unrealistic values; keep units consistent (percent vs decimal).

### nClicksText
**Concept:** Scenario version of `ClicksText` (or its KPI text). It applies user input(s) via `SELECTEDVALUE` and recomputes.

**DAX:**
```dax
VAR diff = IF([7D-Clicks] <> 0, ([nClicks] - [7D-Clicks])/[7D-Clicks], 0)
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

**Dependencies:** 7D-Clicks, nClicks

**Edge cases & pitfalls:** Ensure defaults in `SELECTEDVALUE(..., default)`; clamp unrealistic values; keep units consistent (percent vs decimal).

### nPurchasesText
**Concept:** Scenario version of `PurchasesText` (or its KPI text). It applies user input(s) via `SELECTEDVALUE` and recomputes.

**DAX:**
```dax
VAR diff = IF([7D-Purchases] <> 0,([nPurchase] - [7D-Purchases])/[7D-Purchases],0)
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

**Dependencies:** 7D-Purchases, nPurchase

**Edge cases & pitfalls:** Ensure defaults in `SELECTEDVALUE(..., default)`; clamp unrealistic values; keep units consistent (percent vs decimal).

## RoasStdDeviation
**Concept:** 
Dispersion of daily ROAS — how much ROAS varies day-to-day.

**DAX:**
```dax
CALCULATE(
    STDEVX.S(VALUES('Date'[Date]),[Roas]),
    Campaigns[Objective] = "Conversions"
)
```

## RoasVolatility
**Concept:** 
Normalized variability (Std Dev / Mean), comparable across segments.

**DAX:**
```dax
CALCULATE(
    DIVIDE([RoasStdDeviation], [RoasDailyAvg]),
    FILTER(Campaigns, Campaigns[Objective] = "Conversions")
)
```

## BestWeekROAS
**Concept:** 
Identify the best/worst week’s ROAS for narrative insights.

**DAX:**
```dax
VAR BestWeek = [BestWeek] 
VAR ROAS =CALCULATE(
    [Roas],
    FILTER(
        'Date',
        'Date'[WeekNum] = BestWeek
))


RETURN
"ROAS: $" & FORMAT(ROAS, "0.0")
```

## WorstWeekRoas
**Concept:** 
Identify the best/worst week’s ROAS for narrative insights.

**DAX:**
```dax
VAR WorstWeek = [WorstWeek] 
VAR ROAS = CALCULATE(
    [Roas],
    FILTER(
        'Date',
        'Date'[WeekNum] = WorstWeek
))


RETURN
"ROAS: $" & FORMAT(ROAS, "0.0")
```

## Pattern Families (Same Code, Different Base)
Document once, then reference all members.

- nAOVText, nClicksText, nCPMText, nCTRText, nImpressionsText, nPurchasesText, nRevenueText, nROASText, nSpendText
- 7D-LPV, 7D-Atc, 7D-Spend, 7D-Impressions, 7D-Clicks, 7D-Purchases, 7D-Revenue
- 7D-CPC, 7D-ConversionRate, 7D-AtcCR, 7D-LpvCR, 7D-AOV, 7D-ROAS, nROAS
- 7DaysRollingRoas, 7DaysRollingRevenue, 7DaysRollingSpend, 7DaysRollingRoi, 7DaysRollingAtrConversionRate
- TotalRevenue, TotalPurchases, TotalAddToCart, TotalViewContent, TotalInititateCheckout
- SpendCurrentMonth, RevenueCurrentMonth, RoasCurrentMonth, PurchasesCurrentMonth, ProfitCurrentMonth
- Avg.CTR, Avg. Cpc, Avg. CPM, Avg. Frequency
- TotalSpend, TotalClicks, TotalEngagement, TotalImpressions
