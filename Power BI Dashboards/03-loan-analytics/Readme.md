# 3. Dashboard - Loan Analytics

**Business question:** *How is the loan portfolio performing, who is at risk, and how well are we collecting?*

Covers **portfolio performance, risk distribution, and repayment/collections**.

## Semantic Model

| Table | Role |
|-------|------|
| `Fact_Loan` | One row per loan application/contract: status, annual rate, risk score, ML model version, total installments, scheduled interest/principal, date keys |
| `Fact_Loan_Repayment` | One row per installment: principal, interest, status, days overdue, late-payment flag |
| `Dim_Loan_Contract` | Approved amount, term, rate, contract status, start/end dates |
| `Dim_Customer` | Demographics, employment, income, liability, home ownership |
| `Dim_Account` | Account type, status, balance |
| `Dim_Date` | Calendar attributes (linked to application, contract start, contract end, and repayment dates) |

## Slicers

`Year_Num` · `Gender` · `App_Status` · `Contract_Status`

## Key Measures (by KPI)

| KPI | Meaning |
|-----|---------|
| Total Loans / Total Loan Amount | Count and sum of loans |
| Total Customers | Distinct borrowers |
| Avg Loan Amount | Loan amount ÷ loans |
| Overdue Accounts / Avg Days Overdue | Delinquency volume and severity |
| Default Rate | Share of defaulted loans |
| High Risk Loans | Loans above the risk threshold |
| Total Installments / Paid Amount | Repayment schedule and collections |
| Collection Efficiency | Collected ÷ due |
| Late Payments | Count of late installments |
| Home Owners % | Share of borrowers who own a home |

> TODO: add exact DAX and thresholds (e.g., what counts as "high risk") in `dax-measures.md`.

## Pages

### Page 1: Portfolio Overview
- **KPIs:** 24.1K loans · 114.4M total amount · 34.2K customers · 4.7K avg loan
- **Avg Loan Amount by Month:** fluctuates between about 4.4K and 5.0K
- **Loans by Application Status:** Approved 38.9%, Rejected 36.7%, Pending 24.4%
- **Loan Amount by Contract Status:** Fully Paid 80M, Active 31M, Defaulted 3M

### Page 2: Risk and Delinquency
- **KPIs:** 2K overdue accounts · 36 avg days overdue · 8.25% default rate · 8K high-risk loans
- **Avg Days Overdue by Month:** peaks mid-year (47 in June)
- **Risk Heatmap:** average risk by employment status × home ownership
- **Delinquent Customers Table:** employer, loan amount, days overdue, risk score
- **Total Loans by Risk Score:** distribution across score buckets

### Page 3: Interest and Risk Trends
- **Total Interest by Month:** about 418K in Jan falling to about 255K–295K after May
- **Risk Score and Total Loans by Year:** 2024 (41.9%), 2025 (42.4%), 2026 (15.8%, partial year)
- **High-Risk Loans by Month:** declines steadily from 835 to 506

### Page 4: Borrower Demographics
- **KPIs:** 31K avg income · 14 years avg experience · 33% home owners · 10K avg liability
- **Total Loans by Day of Week**
- **Loan Amount by Gender:** F 55% / M 45%
- **Loan Amount by Employment Status:** treemap (Full-Time 69.6M, Part-Time 20.6M, Self-Employed 9.1M, Unemployed 5.3M, Retired 5.2M, Student 4.6M)

### Page 5: Education and Approved Amounts
- **Loan Amount by Employment Status:** ranked bars
- **Loans by Education Level:** Bachelor 52.7%, Master 23.9%, Diploma 11.8%, PhD 5.9%
- **Avg Approved Amount by Month**

### Page 6: Repayment Performance
- **KPIs:** 41K installments · 118M paid · 7.2% collection efficiency · 4.7K late payments
- **Total Interest by Account Type:** Savings 2,623K, Credit 1,277K, Business 41K
- **Paid Amount by Month:** peaks in April (11.8M)
- **Late Payments by Month:** large spike in May (974)

### Page 7: Collections by Contract and Housing
- **Paid Amount by Month**
- **Paid Amount by Contract Status:** Fully Paid 83M, Active 32M, Defaulted 3M
- **Total Installments by Home Ownership:** Rented 26K (58.4%), Owned 15K

## Key Insights

- Only about 39% of applications are approved; about 37% are rejected.
- Full-time employees account for about 61% of the loan volume (69.6M of 114.4M).
- High-risk loans decline month over month across the year.
- Late payments spike sharply in May, in line with the mid-year overdue peak.
- Renters make up the majority of installments.

## Known Issues to Review Before Publishing

- **Page 5:** "Avg Approved Amount by Month" shows a flat $13.43K for every month, so the measure probably ignores the date filter. Check the relationship or measure context.
- **Page 2:** the risk-score axis is formatted as currency ($70, $75, …). Change it to a number format. The delinquent table also shows many rows with 0 days overdue, so check that the delinquency filter is applied.
- **Page 6:** a 7.2% collection efficiency looks inconsistent with 118M paid. Check the numerator/denominator and the percentage formatting.
- **Default Rate (8.25%)** vs defaulted amount (3M of 114.4M, about 2.6%): document whether the rate is by count or by amount.
- **Page 3:** 2026 is a partial year, so year-over-year percentages are not like-for-like. Consider adding a note.
- Day-of-week and month axes are sorted by value; sort by day/month number.

## Files

```
pbix/         # Loan_Analytics.pbix
screenshots/  # One PNG per page (7)
```
