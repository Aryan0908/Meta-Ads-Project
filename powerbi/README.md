# Meta Ads Power BI — DAX Documentation

This README documents the **key and complex DAX** powering the Meta Ads analytics project. It focuses on business-critical KPIs, reusable calculation templates (e.g., 7‑day windows), and the **What‑If Analysis** layer.

## Repository Structure (suggested)

```
/DAX/
  measures.csv           # Exported from DAX Studio (all measures)
  README.md              # This file
/model/
  meta_ads.pbix          # If shareable
```

## Data Model (high level)

- **Fact**: `Performance` (Impressions, Clicks, CPC, CPM, Revenue, Purchases, etc.)
- **Dimensions**: `Campaigns`, `Adsets`, `Ads`, `Date`
- Many base totals are scoped to `Campaigns[Objective] = "Conversions"`, ensuring KPI integrity.

## Exported Measures

All measures are available in `/DAX/measures.csv` (exported via DAX Studio). Below we document the most important and complex ones. Supporting/base measures are linked under each KPI.

## Tier‑1 KPIs (fully explained)

### Roas
**Return on Ad Spend** — ratio of Revenue to Spend within current filter context.
```dax
CALCULATE(
    DIVIDE([TotalRevenue], [TotalSpend], 0),
    Campaigns[Objective] = "Conversions"
)
```

### 7D-ROAS
7‑day ROAS using 7‑day Revenue and 7‑day Spend (rolling window on Date).
```dax
DIVIDE(
    [7D-Revenue],
    [7D-Spend],
    0
)
```

### Avg.CTR
Average CTR from the fact table column — used for quick reference cards.
```dax
AVERAGE(Performance[CTR])
```

### 7D-CTR
7‑day CTR using 7‑day Clicks and 7‑day Impressions.
```dax
CALCULATE(DIVIDE([TotalClicks],[TotalImpressions]), DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY))
```

### Avg. Cpc
Average CPC across the selected context.
```dax
AVERAGE(Performance[CPC])
```

### Avg. CPM
Average CPM across the selected context.
```dax
AVERAGE(Performance[CPM])
```

### LeadsConversionRate
Lead conversion rate (Leads over base denominator; see code).
```dax
CALCULATE(
    DIVIDE(
        [TotalLeads],
        [TotalLeadFormViews]
    ),
    Campaigns[Objective] = "Leads"
)
```

### Purchase/ClicksConversionRate
Purchase conversion rate per Click (Purchases / Clicks).
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

### Avg. CPL
Cost per Lead: Spend / Leads.
```dax
DIVIDE(
    [TotalSpend],
    [TotalLeads]
)
```

### AddToCartConversionRate
ATC → Purchase conversion rate.
```dax
[TotalPurchases] / [TotalAddToCart]
```

### CheckoutConversionRate
Checkout → Purchase conversion rate.
```dax
[TotalPurchases] / [TotalInititateCheckout]
```

### 7D-ConversionRate
7‑day conversion rate computed from 7‑day Purchases and Clicks.
```dax
DIVIDE(
    [7D-Purchases],
    [7D-Clicks],
    0
)
```

### TotalSpend
Total ad spend (filtered to Conversions objective where appropriate).
```dax
SUM(Performance[Cost])
```

### TotalRevenue
Total revenue (Conversions objective).
```dax
CALCULATE(
    SUM(Performance[Revenue]),
    Campaigns[Objective] = "Conversions"
)
```

### TotalPurchases
Total purchases (Conversions objective).
```dax
CALCULATE(
    SUM(Performance[Purchase]),
    Campaigns[Objective] = "Conversions"
)
```

### TotalClicks
Total clicks.
```dax
SUM(Performance[Clicks])
```

### TotalImpressions
Total impressions.
```dax
SUM(Performance[Impressions])
```


## Reusable DAX Templates (explain once, reuse everywhere)

### 7‑Day Window on a Base Measure
Same logic used for `7D-Clicks`, `7D-Impressions`, `7D-Spend`, `7D-Purchases`, `7D-Atc`, `7D-LPV`, etc. Only the **base measure** changes.

```dax
CALCULATE([TotalClicks], DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY))
```
### 7‑Day KPI Ratios (e.g., 7D‑CTR, 7D‑ConversionRate, 7D‑CPC, 7D‑AtcCR, 7D‑LpvCR)
The KPI is built by dividing the corresponding 7‑day numerator/denominator.

```dax
CALCULATE(DIVIDE([TotalClicks],[TotalImpressions]), DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY))
```
### Rolling Averages Over Time
Used for rolling ROAS/Revenue/Spend/Purchases and other smoothed trends.

```dax
AVERAGEX(
    DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -7, DAY),
    [Roas]
)
```
### Base Totals Filtered to Objective = "Conversions"
Pattern is reused for Revenue, Purchases, View Content, ATC, Initiate Checkout.

```dax
CALCULATE(
    SUM(Performance[Revenue]),
    Campaigns[Objective] = "Conversions"
)
```
### Period‑to‑Period Blocks (WoW/MoM)
The same period selector structure is used for Spend/Revenue/Purchases/ROAS — only the inner measure differs.

```dax
VAR maxMonth = MAX('Date'[MonthNum])

RETURN
CALCULATE(
    [Roas],
    MONTH(performance[date]) = maxMonth
)
```

## What‑If Analysis (scenario layer)

This layer simulates KPI changes from user‑selected parameters (e.g., CTR/CPM deltas). It introduces parallel **n*** measures (e.g., `nSpend`, `nImpressions`, `nCPM`) and badge text measures (e.g., `nCPMText`) to show ▲/▼ deltas against a baseline (often 7D KPIs).

### Representative What‑If Measures

#### nCPM
```dax
DIVIDE([nSpend], [nImpressions]) * 1000
```

#### nCTR
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

#### nClicks
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

#### nImpressions
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

#### nRevenue
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

#### nSpend
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

#### nPurchase
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

#### nCPMText
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

#### nCTRText
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

#### nClicksText
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

#### nPurchasesText
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


## Advanced/Analytics Measures

### RoasStdDeviation
```dax
CALCULATE(
    STDEVX.S(VALUES('Date'[Date]),[Roas]),
    Campaigns[Objective] = "Conversions"
)
```

### RoasVolatility
```dax
CALCULATE(
    DIVIDE([RoasStdDeviation], [RoasDailyAvg]),
    FILTER(Campaigns, Campaigns[Objective] = "Conversions")
)
```

### BestWeekROAS
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

### WorstWeekRoas
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


## Full Catalog
See all exported measures in [`/DAX/measures.csv`](DAX/measures.csv).