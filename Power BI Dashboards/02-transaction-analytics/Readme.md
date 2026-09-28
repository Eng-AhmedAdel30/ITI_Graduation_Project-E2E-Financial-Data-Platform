# Dashboard 2 · Transaction Analytics

**Business question:** *How much money moves through the bank, through which channels, accounts, and customer segments, and how healthy is liquidity?*

Covers **volume trends, channel analysis, and anomaly detection**.

## Semantic Model

| Table | Role |
|-------|------|
| `Fact_Transaction` | Transaction entries: amount, entry type (credit/debit), status, fraud flag, keys to customer, account, card, bank, merchant, date |
| `Fact_Card_Attempt` | Card attempts and success flag |
| `Dim_Customer` | Demographics, job, income, liability, family status, car/home ownership |
| `Dim_Account` | Account type, status, balance, currency |
| `Dim_Card` | Card type, credit limit, blocked flag |
| `Dim_Bank`, `Dim_Merchant`, `Dim_Location` | Bank, merchant, and geography context |
| `Dim_Date` | Calendar attributes |
| `Dax Measures` | Measure table |

## Measures

| Measure | Purpose |
|---------|---------|
| Total Transaction Amount | Sum of transaction amounts |
| Successful Transactions Count | Count of completed transactions |
| Success Rate % | Successful ÷ total |
| Active Customers | Distinct customers with transactions |
| Total Deposits | Sum of credit entries |
| Total Outflow | Sum of debit entries |
| Net Liquidity | Deposits − Outflow |
| Outflow Test Search | Helper measure (consider removing or renaming before release) |

> TODO: add exact DAX in `dax-measures.md`.

## Slicers

`Year_Num` · `Gender` · `Acc_Type` · `Trans_Status` (Income/demographic pages use `Year_Num`, `Gender`, `Acc_Type`, `Trans_Status` too)

## Pages

### Page 1: Transaction Overview
- **KPIs:** 34K active customers · 1M transactions · 359.9M total amount
- **Amount by status:** Completed 91.7%, Pending 8.0%, Failed 0.2%, Reversed (tiny)
- **Amount by type:** Credit 58.6% / Debit 41.4%
- **Monthly amount:** peaks in Mar (37.8M), drops sharply after May to about 24M–26M per month

### Page 2: Liquidity
- **KPIs:** Deposits 210.78M · Outflow 149.11M · **Net Liquidity 61.67M**
- **Net Liquidity by Account Type:** Savings 69.5%, Credit 29.8%, Business 0.6%
- **Total Deposits by Job Title:** top 5 professions
- **Outflow vs Deposits by Month:** two-line trend; deposits exceed outflow every month

### Page 3: Job Titles and Channels
- **KPIs:** 359.90M total · 871.55K transactions · 251.32 average amount
- **Top 10 Job Titles in Transactions:** about 1.8M–2.2M each
- **Total Outflow by Account Type:** Savings 99M, Credit 49M, Business 2M
- **Amount by Card Type:** Debit 9.61M vs Credit 3.31M

### Page 4: Income and Liabilities
- **KPIs:** Avg monthly income 31.39K · avg monthly liability 10.18K · avg experience 14.04 years
- **Avg Monthly Income by Job Title:** top roles (CEO about 120K)
- **Avg Monthly Liabilities by Family Status:** Divorced 13.0K, Married 11.7K, Single 4.7K
- **Avg Monthly Income by Years of Experience:** rises steadily with experience

### Page 5: Ownership and Account Status
- **KPIs:** 11.6K car owners · Home owners' amount 119.49M · Car owners' amount 123.89M
- **Amount by Account Status:** Active 272.09M, Frozen 44.14M, Suspended 43.67M
- **Amount by Car Ownership:** Non-owners 65.6%, owners 34.4%
- **Amount by Job Title and Car Ownership:** stacked bars

### Page 6: Card Behavior
- **KPIs:** Avg credit limit 30.83K · Credit total 210.78M · Debit total 149.11M
- **Transactions per Month:** 92K in Jan down to about 57K–63K in H2
- **Amount by Card Type and Gender**
- **Avg Years of Experience by Entry Type**

### Page 7: Gender, Family and Education
- **KPIs:** Max income 138.51K · avg liability 10.18K · avg income 31.39K
- **Avg Monthly Income by Gender:** F 32K vs M 31K
- **Amount by Family Status and Gender:** Married > Single > Divorced
- **Amount by Month and Education Level:** stacked area

### Page 8: Entry Types and Status Mix
- **KPIs:** 359.90M · 871.547K transactions · 251.32 average
- **Count of Transactions by Entry Type:** waterfall (Debit 0.81M, Credit 0.62M, Total 1.43M)
- **Amount by Account Status:** Active about 0.27bn, Frozen and Suspended about 0.04bn each
- **Count by Transaction Status:** Completed about 92%, Pending about 7.8%

### Page 9: Income vs Liability
- **KPIs:** Avg income 31.39K · avg liability 10.18K · avg amount 251.32
- **Avg Income by Education Level:** PhD 67K > Bachelor 35K > Diploma 28K > Master 22K > High School 10K
- **Total Income and Liabilities by Family Status**
- **Scatter:** income vs liability per customer, colored by gender

## Key Insights

- Deposits exceed outflow every month (net liquidity 61.67M).
- Volume declines after May, both in amount and transaction count.
- About 92% of transactions complete; about 8% remain pending.
- Savings accounts hold about 70% of net liquidity.
- Frozen/Suspended accounts still account for about 88M in transaction amount, which is worth a review.

## Known Issues to Review Before Publishing

- **Transaction counts differ across pages** (1M on page 1, 871.55K on pages 3 and 8, and 1.43M in the waterfall). Document which measure counts headers vs entries, and use consistent labels.
- **Page 3 card-type amounts (13M)** are far smaller than the 359.9M total. Clarify that they only cover card transactions.
- **Page 8 waterfall:** a waterfall is not the ideal visual for debit/credit counts; consider a clustered bar.
- Rename or remove the `Outflow Test Search` measure.
- Sort month axes by `Month_Num`.

## Files

```
pbix/         # Transaction_Analytics.pbix
screenshots/  # One PNG per page (9)
```
