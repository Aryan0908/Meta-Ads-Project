# POWER BI - DAX + Table Relationships

End-to-end Power BI model on Meta Ads data with scenario planning, rolling metrics, and drillthrough.  
This guide explains the **data model & relationships**, and **each page’s sections/charts/slicers + use cases**.
## 📦 Data Model (Star Schema)

```mermaid
erDiagram
  Campaigns ||--o{ Adsets : campaign_id
  Adsets   ||--o{ Ads : adset_id
  Ads      ||--o{ Performance : ad_id
  Date     ||--o{ Performance : date

  Campaigns {
    string campaign_id PK
    string objective
  }
  Adsets {
    string adset_id PK
    string campaign_id FK
    string age_range
    string placement
  }
  Ads {
    string ad_id PK
    string adset_id FK
    string ad_format
  }
  Performance {
    string ad_id FK
    date   date
    number impressions
    number clicks
    number cost
    number revenue
    number purchases
  }

## 1) Roas

👉 **What it answers:**

- Which campaigns/adsets/ads generate the highest return per $1 spent?
- ROAS by device/placement/audience
- ROAS trend at current filter level

👉 **Why it matters:** Primary efficiency KPI: revenue per unit spend; used to rank campaigns/adsets and allocate budget.

**View DAX**

```dax
CALCULATE(
    DIVIDE([TotalRevenue], [TotalSpend], 0),
    Campaigns[Objective] = "Conversions"
)
```

🛠️ **How it's built:**

- Numerator: `TotalRevenue` scoped to `Objective = "Conversions"`
- Denominator: `TotalSpend` in the same filter context
- Use `DIVIDE([TotalRevenue], [TotalSpend])` for safe division
- Depends on: Objective, TotalRevenue, TotalSpend

👉 **Name of measures with similar DAX but different base:** Roi

## 2.1) 7D-Spend

👉 **What it answers:**

- Is Spend trending increased/decreased this week?
- Short-term spending shifts

👉 **Why it matters:** Short-term Spend/cost momentum for daily monitoring.

**View DAX**

```dax
CALCULATE([TotalSpend], DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY))
```

🛠️ **How it's built:**

- Time window: `DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY)` (7 rows inclusive)
- Use base `7D-*` numerators/denominators for ratios (e.g., 7D-Clicks/7D-Impressions)
- Guard divisions with `DIVIDE()` to avoid divide-by-zero

👉 **Name of measures with similar DAX but different base:** 7D-ATC, 7D-Clicks, 7D-CTR, 7D-Impressions, 7D-LPV, 7D-Purchases

## 2.2) 7D-Revenue

👉 **What it answers:**

- What has been our revenue for the last 7 days.
- Short-term revenue performance

👉 **Why it matters:** Helps in comparing performance to previous weeks

**View DAX**

```dax
CALCULATE([TotalRevenue], DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY))
```

🛠️ **How it's built:**

- Time window: `DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY)` (7 rows inclusive)
- Use base `7D-*` numerators/denominators for ratios (e.g., 7D-Clicks/7D-Impressions)
- Guard divisions with `DIVIDE()` to avoid divide-by-zero

👉 **Name of measures with similar DAX but different base:** 7D-ATC, 7D-Clicks, 7D-CTR, 7D-Impressions, 7D-LPV, 7D-Purchases

## 2.3) 7D-ROAS

👉 **What it answers:**

- Is ROAS improving in the last 7 days vs previous 7?
- Which adsets show positive short‑term ROAS momentum?

👉 **Why it matters:** Removes single‑day noise and reveals near‑term momentum for decisions.

**View DAX**

```dax
DIVIDE(
    [7D-Revenue],
    [7D-Spend],
    0
)
```

🛠️ **How it's built:**

- Build 7‑day totals with `DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -6, DAY)`
- Compute `DIVIDE([7D-Revenue], [7D-Spend])`
- Window is relative to **max visible date**
- Depends on: 7D-Revenue, 7D-Spend

👉 **Name of measures with similar DAX but different base:** 7D-AOV, 7D-AtcCR, 7D-CPC, 7D-CPM, 7D-ConversionRate, 7D-LpvCR

## 3) 7DaysRollingRoas

👉 **What it answers:**

- Smooth ROAS trend day‑to‑day to see underlying movement
- Where is ROAS consistently improving or deteriorating?

👉 **Why it matters:** Smoothed line that stakeholders can interpret quickly without day‑to‑day noise.

**View DAX**

```dax
AVERAGEX(
    DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -7, DAY),
    [Roas]
)
```

🛠️ **How it's built:**

- Smooth daily ROAS using `AVERAGEX(DATESINPERIOD(...), [Roas])`
- Ideal for trend lines at day granularity
- Depends on: Date, Roas

👉 **Name of measures with similar DAX but different base:** 7DaysRollingAtrConversionRate, 7DaysRollingRevenue, 7DaysRollingRoi, 7DaysRollingSpend

## 4.1) RoasCurrentWeek

👉 **What it answers:**

- What is this week’s ROAS by segment?
- Which segments improved WoW?

👉 **Why it matters:** Operational snapshot for weekly reviews and WoW monitoring.

**View DAX**

```dax
CALCULATE(
    DIVIDE([TotalRevenue], [TotalSpend], 0),
    Campaigns[Objective] = "Conversions",
    'Date'[WeekNum] = MAX('Date'[WeekNum])
)
```

🛠️ **How it's built:**

- Isolate a week via `WEEKNUM`/calendar logic or date filters
- Compute ROAS within week using `DIVIDE([TotalRevenue],[TotalSpend])`
- Pair current vs previous for WoW deltas
- Depends on: Objective, TotalRevenue, TotalSpend, WeekNum

👉 **Name of measures with similar DAX but different base:** LeadsCurrentWeek, RoiCurrentWeek

## 4.2) RoasPreviousWeek

👉 **What it answers:**

- What was last week’s ROAS (baseline)?
- Reference for WoW deltas

👉 **Why it matters:** Baseline for WoW comparisons to attribute changes.

**View DAX**

```dax
CALCULATE(
    DIVIDE([TotalRevenue], [TotalSpend], 0),
    Campaigns[Objective] = "Conversions",
    'Date'[WeekNum] = MAX('Date'[WeekNum]) - 1
)
```

🛠️ **How it's built:**

- Isolate a week via `WEEKNUM`/calendar logic or date filters
- Compute ROAS within week using `DIVIDE([TotalRevenue],[TotalSpend])`
- Pair current vs previous for WoW deltas
- Depends on: Objective, TotalRevenue, TotalSpend, WeekNum

👉 **Name of measures with similar DAX but different base:** LeadsPreviousWeek, RoiPreviousWeek

## 4.3) Roas_WOW

👉 **What it answers:**

- How has ROAS moved week‑over‑week across segments?
- Line chart friendly ROAS for WoW comparisons

👉 **Why it matters:** Consistent weekly series for storytelling and alerts.

**View DAX**

```dax
VAR maxWeek = MAX('Date'[WeekNum])
VAR currentWeek = maxWeek
VAR previousWeek = currentWeek - 1

VAR ROI_CurrentWeek =
    CALCULATE(
        [Roas],
        'Date'[WeekNum] = currentWeek
    )

VAR ROI_PreviousWeek =
    CALCULATE(
        [Roas],
        'Date'[WeekNum] = previousWeek
    )

RETURN

    IF(
        NOT(ISBLANK(ROI_PreviousWeek)),
        (ROI_CurrentWeek - ROI_PreviousWeek) / ROI_PreviousWeek,
        BLANK()
    )
```

🛠️ **How it's built:**

- Calculated over current filter context
- Uses base ROAS (`DIVIDE([TotalRevenue],[TotalSpend])`) within the relevant period/grain
- Depends on: Roas, WeekNum

👉 **Name of measures with similar DAX but different base:** CPC_WOW, CTR_WOW, Lead_WOW, Roi_WOW

## 5.1) RoasCurrentMonth

👉 **What it answers:**

- What is the current month’s ROAS by segment?
- Which segments improved MoM?

👉 **Why it matters:** Exec‑level KPI for monthly pacing and budget shifts.

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

- Isolate month via `EOMONTH` or MonthNum
- Compute ROAS within month using the same base ROAS definition
- Pair current vs previous for MoM deltas
- Depends on: MonthNum, Roas, date

👉 **Name of measures with similar DAX but different base:** ProfitCurrentMonth, PurchasesCurrentMonth, RevenueCurrentMonth, SpendCurrentMonth

## 5.2) RoasPreviousMonth

👉 **What it answers:**

- What was last month’s ROAS (baseline)?
- Reference for MoM deltas

👉 **Why it matters:** Baseline for MoM evaluation and pacing corrections.

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

- Isolate month via `EOMONTH` or MonthNum
- Compute ROAS within month using the same base ROAS definition
- Pair current vs previous for MoM deltas
- Depends on: Date, Roas

👉 **Name of measures with similar DAX but different base:** PurchasesPreviousMonth, RevenuePreviousMonth, SpendPreviousMonth, ProfitPreviousMonth

## 5.3) Roas_MOM%

👉 **What it answers:**

- By what percent did ROAS change vs previous month?
- Which segments contributed most to the MoM change?

👉 **Why it matters:** Quantifies improvement/decline to guide budget reallocation.

**View DAX**

```dax
VAR prev = [RoasPreviousMonth]
VAR curr = [RoasCurrentMonth]
RETURN
IF(
    NOT ISBLANK(prev),
    DIVIDE(curr - prev, prev),
    BLANK()
)
```

🛠️ **How it's built:**

- Calculate ROAS for current vs previous month
- Percent change: `(Current - Previous) / Previous`
- Return % for conditional formatting and ranking
- Depends on: RoasCurrentMonth, RoasPreviousMonth

👉 **Name of measures with similar DAX but different base:** Profit_MOM%, Purchase_MOM%, Revenue_MOM%, Spend_MOM%

## 5.4) Roas_MOMLabel

👉 **What it answers:**

- Readable ▲/▼ label for ROAS MoM change
- Card/tooltip friendly summary

👉 **Why it matters:** Human‑readable signal (▲/▼) for dashboards and tooltips.

**View DAX**

```dax
VAR change = [Roas_MOM%] * 100
RETURN
SWITCH(
    TRUE(),
    ISBLANK(change), "–",
    change > 0, "▲ " & FORMAT(change, "0.0") & "% MOM",
    change < 0, "▼ " & FORMAT(change, "0.0") & "% MOM",
    "0.0%"
)
```

🛠️ **How it's built:**

- Reuse `Roas_MOM%` and bucket ▲/▼ text based on sign and thresholds
- Format with `FORMAT()` for a dashboard‑ready label
- Depends on: Roas_MOM%

👉 **Name of measures with similar DAX but different base:** Profit_MOMLabel, Purchase_MOMLabel, Revenue_MOMLabel, Spend_MOMLabel

## 6) BestWeekROAS

👉 **What it answers:**

- Which week delivered the best ROAS?
- Narrative anchor for highlights

👉 **Why it matters:** Highlights peak performance and helps replicate drivers.

**View DAX**

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

🛠️ **How it's built:**

- Identify target week (max/min ROAS) in the context
- Evaluate with `CALCULATE([Roas], <week filter>)` for that week
- Depends on: BestWeek, Roas, WeekNum

👉 **Name of measures with similar DAX but different base:** BestWeekCtr, BestWeekRevenue, BestWeekRoi, BestWeekSpend

## 7) WorstWeekRoas

👉 **What it answers:**

- Which week delivered the worst ROAS?
- Risk and remediation prioritization

👉 **Why it matters:** Surfaces risk and directs fix‑it analysis.

**View DAX**

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

🛠️ **How it's built:**

- Identify target week (max/min ROAS) in the context
- Evaluate with `CALCULATE([Roas], <week filter>)` for that week
- Depends on: Roas, WeekNum, WorstWeek

👉 **Name of measures with similar DAX but different base:** WorstWeekCtr, WorstWeekRevenue, WorstWeekRoi, WorstWeekSpend

## 8.1) RoasStdDeviation

👉 **What it answers:**

- How variable is ROAS day‑to‑day?
- Which segments are most volatile?

👉 **Why it matters:** Measures stability; unstable ROAS needs investigation.

**View DAX**

```dax
CALCULATE(
    STDEVX.S(VALUES('Date'[Date]),[Roas]),
    Campaigns[Objective] = "Conversions"
)
```

🛠️ **How it's built:**

- Compute daily ROAS; use `STDEVX.S(VALUES('Date'[Date]), [Roas])`
- Depends on: Date, Objective, Roas

👉 **Name of measures with similar DAX but different base:** CTR, CPC, CPM, ConversionRate variants

## 8.2) RoasVolatility

👉 **What it answers:**

- How volatile is ROAS relative to its average?
- Risk‑adjusted comparison across segments

👉 **Why it matters:** Normalizes dispersion by level to compare apples‑to‑apples.

**View DAX**

```dax
CALCULATE(
    DIVIDE([RoasStdDeviation], [RoasDailyAvg]),
    FILTER(Campaigns, Campaigns[Objective] = "Conversions")
)
```

🛠️ **How it's built:**

- Volatility = `RoasStdDeviation / AVERAGEX(VALUES('Date'[Date]), [Roas])`
- Depends on: Objective, RoasDailyAvg, RoasStdDeviation

👉 **Name of measures with similar DAX but different base:** CTR, CPC, CPM, ConversionRate variants

## 9) Max. ROAS

👉 **What it answers:**

- Best ROAS by segment
- Trend over time

👉 **Why it matters:** Key ROAS KPI for optimization and reporting.

**View DAX**

```dax
CALCULATE(
    [Roas],
    TOPN(
        1,
        ADDCOLUMNS(
            SUMMARIZE(
                'Date',
                'Date'[Date]),
            "Daily ROAS",
            [Roas]
        ),
        [Daily ROAS],
        DESC

    ))
```

🛠️ **How it's built:**

- Calculated over current filter context
- Uses base ROAS (`DIVIDE([TotalRevenue],[TotalSpend])`) within the relevant period/grain
- Depends on: Daily ROAS, Date, Roas

👉 **Name of measures with similar DAX but different base:** CTR, CPC, CPM, ConversionRate variants

## 10) Min. ROAS

👉 **What it answers:**

- ROAS by segment
- Trend over time

👉 **Why it matters:** Key ROAS KPI for optimization and reporting.

**View DAX**

```dax
CALCULATE(
    [Roas],
    TOPN(
        1,
        FILTER(
            ADDCOLUMNS(
                SUMMARIZE(
                    'Date',
                    'Date'[Date]),
                "Daily ROAS",
                [Roas],
                "Spend",
                [TotalSpend]
        ),
        [TotalSpend] > 0
        ),
        [Daily ROAS],
        ASC

    ))
```

🛠️ **How it's built:**

- Calculated over current filter context
- Uses base ROAS (`DIVIDE([TotalRevenue],[TotalSpend])`) within the relevant period/grain
- Depends on: Daily ROAS, Date, Roas, TotalSpend

👉 **Name of measures with similar DAX but different base:** CTR, CPC, CPM, ConversionRate variants

## 11) RoasDailyAvg

👉 **What it answers:**

- ROAS by segment
- Trend over time

👉 **Why it matters:** Key ROAS KPI for optimization and reporting.

**View DAX**

```dax
AVERAGEX(
    VALUES('Date'[Date]),
    [Roas]
)
```

🛠️ **How it's built:**

- Calculated over current filter context
- Uses base ROAS (`DIVIDE([TotalRevenue],[TotalSpend])`) within the relevant period/grain
- Depends on: Date, Roas

👉 **Name of measures with similar DAX but different base:** CTR, CPC, CPM, ConversionRate variants

## 12.1) nSpend

👉 **What it answers:**

- Projected spend given budget tweaks
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

## 12.2) nRevenue

👉 **What it answers:**

- Projected revenue given adjusted CR/ATC rates
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

## 12.3) nROAS

👉 **What it answers:**

- ROAS by segment
- Trend over time

👉 **Why it matters:** Key ROAS KPI for optimization and reporting.

**View DAX**

```dax
DIVIDE(
    [nRevenue],
    [nSpend],
    0
)
```

🛠️ **How it's built:**

- Calculated over current filter context
- Uses base ROAS (`DIVIDE([TotalRevenue],[TotalSpend])`) within the relevant period/grain
- Depends on: nRevenue, nSpend

👉 **Name of measures with similar DAX but different base:** 7D-AOV, 7D-AtcCR, 7D-CPC, 7D-ConversionRate, 7D-LpvCR

## 12.4) nROASText

👉 **What it answers:**

- Display adjusted ROAS in clear indicated form

👉 **Why it matters:** Key ROAS KPI for optimization and reporting.

**View DAX**

```dax
VAR diff = IF([7D-ROAS] <> 0, ([nROAS] - [7D-ROAS])/[7D-ROAS], 0)
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

- Calculated over current filter context
- Uses base ROAS (`DIVIDE([TotalRevenue],[TotalSpend])`) within the relevant period/grain
- Depends on: 7D-ROAS, nROAS

👉 **Name of measures with similar DAX but different base:** nAOVText, nCPMText, nCTRText, nClicksText, nImpressionsText, nPurchasesText, nRevenueText, nSpendText
