# 07 · SSRS Operational Reports

Paginated operational reports built with **SQL Server Reporting Services**, powered by stored procedures in the OLTP database.

## Reports

| # | Report | Business purpose | Parameters |
|---|--------|------------------|-----------|
| 1 | **Customer Profile** (Customer Financial Health) | 360-degree customer view before service or lending decisions: profile, income, liability, debt ratio, loans, accounts, login behavior | Customer |
| 2 | **Executive Overview** | High-level snapshot: customers, accounts, transactions, loan applications, fraud alerts, deposits; transactions by type; applications by status | Month, Year |
| 3 | **Fraud Monitoring** | Detect and investigate suspicious activity: suspicious transactions, confirmed fraud, risk scores, channel, IP, triggered rules | Date From, Date To, Risk Level |
| 4 | **Loan Approval & Risk Assessment** | Support approval decisions with risk scores; requested/approved amounts, interest rate, contract status | App Status |
| 5 | **Loan Repayment Performance** | Monitor collections: installments, amount due, collected, overdue, collection rate; installments by status | Month |

## Data Sources

Reports call the stored procedures in [`01-oltp-database`](../01-oltp-database), e.g. `SP_Customer_Profile`, `SP_Executive_Overview`, `SP_Fraud_Monitoring`, `SP_Loan_Risk_Assessment`, `SP_Repayment_Performance`.

## Suggested Folder Contents

```
07-ssrs-reports/
├── reports/         # .rdl files
├── datasets/        # Shared data sources / datasets
└── screenshots/
```

## Setup

1. Open the `.rdl` files in Report Builder or Visual Studio (SSRS extension).
2. Point the shared data source to your SQL database.
3. Deploy to your Report Server and test each parameter set.
