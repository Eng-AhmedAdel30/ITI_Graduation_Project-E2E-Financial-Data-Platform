# 1. Dashboard · User Login Analytics

**Business question:** *How, when, and from whom do customers log in, and what does that say about engagement and security risk?*

Part of the **Customer Behavior Analytics** area: segmentation, engagement metrics, and login behavior.

## Semantic Model

| Table | Role |
|-------|------|
| `Fact_Login_Attempt` | One row per login attempt (`Login_Attempt_BK`, `Cust_SK`, `Date_Key`, `Time_Key`, `Device_ID`, `Is_Success`, `Attempt_DateTime`) |
| `Dim_Customer` | Demographics and employment (education, employer, employment status, income, liability, etc.) |
| `Dim_Date` | Calendar attributes (day, month, weekend/holiday flags) |
| `Dim_Time` | Hour (12/24), AM/PM, time period |
| `Measure` | Table holding all DAX measures |

**Relationships:** `Dim_Customer` (1) → `Fact_Login_Attempt` (*); `Dim_Date` (1) → fact (*); `Dim_Time` (1) → fact (*).

## Measures

| Measure | Purpose |
|---------|---------|
| Total Login Attempts | Count of login attempts |
| Total Customers | Distinct customers who logged in |
| Total Devices | Distinct devices used |
| Average Attempts Per Customer | Attempts ÷ customers |
| Average Logins by Customer | Avg logins per customer |
| Average Logins by Employment Status | Avg logins per employment segment |
| Average Daily Logins | Attempts ÷ days |
| Average Monthly Logins | Attempts ÷ months |
| Peak Login Hour | Hour with the highest activity |
| Weekday Attempts / Weekend Attempts | Attempts split by `Is_Weekend` |
| Missing Dates | Days with no activity (data completeness check) |

> TODO: add the exact DAX for each measure in `dax-measures.md`.

## Slicers

`Year_Num` · `Gender` · `Employment_Status` · `Education_Level`

## Pages

### Page 1: Login Trends Over Time
- **KPIs:** 234K total login attempts · 33K customers · 83K devices · 7 avg logins per customer
- **Average Daily Logins by Hour (0–23):** area chart. Activity dips sharply between about 05:00 and 09:00 and peaks between 17:00 and 21:00.
- **Average Monthly Logins by Month:** column chart. Higher in Jan–May (about 22K–25K) and flat at 16K–17K from June onward.
- **Average Daily Logins by Day:** line chart. Very flat (about 266–271 per day), with a slight Monday peak.

### Page 2: Time-of-Day and Weekday Patterns
- **Weekday vs Weekend attempts:** donut (about 72% weekday / 28% weekend)
- **AM vs PM attempts:** donut (about 59% PM / 41% AM)
- **Average Daily Logins by Time Period:** Evening and Late Night lead (63), then Afternoon (56), Morning (49), Night (38)

### Page 3: Customer Segments
- **Total Login Attempts by Education Level:** Bachelor (124K) leads, then Master (56K), Diploma (27K), PhD (14K), High School (13K)
- **Total Login Attempts by Employer:** Tech Dynamics Corp. (75K), Swift Energy Group (56K), Nexa Data Inc. (38K)
- **Total Login Attempts by Employment Status:** Full-Time (121K), Part-Time (40K), Unemployed (39K), Self-Employed (17K), Retired (8K), Student (8K)

### Page 4: Employers and Device Activity
- **Top 15 Employers by Login Activity:** ranked bar chart
- **Count of Device_ID by Date:** daily time series, Jan 2024 onward, oscillating around 250–300 per day (useful for spotting anomalies or spikes)

## Key Insights

- Login activity peaks in the evening (17:00–21:00) and drops overnight/early morning.
- Roughly 7 in 10 attempts happen on weekdays.
- Volume fell after May, from about 22K–25K to about 16K–17K per month.
- Bachelor-degree and full-time customers generate the most activity.

## Known Issues to Review Before Publishing

- **Page 2:** the AM/PM donut has the same title as the weekday/weekend donut. Retitle it (e.g., "AM vs PM Attempts").
- **Page 4:** the "Top 15 Employers" axis shows first names (Christopher, Robert, …), so it appears to use `First_Name` instead of `Employer_Name`. Check the field.
- Month axes are sorted by value in places; sort by `Month_Num` for chronological order.

## Files

```
pbix/         # User_Login_Analytics.pbix
screenshots/  # One PNG per page
```
