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

## PAGES: 

### Page 1: Portfolio Overview

![Page](<./Loan Analytics_1.png>)

### Page 2: Risk and Delinquency

![Page](<./Loan Analytics_2.png>)

### Page 3: Interest and Risk Trends

![Page](<./Loan Analytics_3.png>)

### Page 4: Borrower Demographics

![Page](<./Loan Analytics_4.png>)

### Page 5: Education and Approved Amounts

![Page](<./Loan Analytics_5.png>)

### Page 6: Repayment Performance

![Page](<./Loan Analytics_6.png>)

### Page 7: Collections by Contract and Housing

![Page](<./Loan Analytics_7.png>)

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

## Key Insights

- Only about 39% of applications are approved; about 37% are rejected.
- Full-time employees account for about 61% of the loan volume (69.6M of 114.4M).
- High-risk loans decline month over month across the year.
- Late payments spike sharply in May, in line with the mid-year overdue peak.
- Renters make up the majority of installments.
