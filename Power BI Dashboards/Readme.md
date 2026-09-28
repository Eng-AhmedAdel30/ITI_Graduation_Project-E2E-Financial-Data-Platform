# 06 · Power BI Dashboards

Interactive dashboards built on semantic models over the Fabric Data Warehouse. All pages share a common dark FinTech theme and slicers (year, gender, and domain-specific filters).

## Semantic Models

| Model | Main tables |
|-------|------------|
| User Login | `Fact_Login_Attempt`, `Dim_Customer`, `Dim_Date`, `Dim_Time` |
| Transactions Analysis | `Fact_Transaction`, `Fact_Card_Attempt`, `Dim_Customer`, `Dim_Account`, `Dim_Card`, `Dim_Bank`, `Dim_Merchant`, `Dim_Location`, `Dim_Date` |
| Loan Analysis | `Fact_Loan`, `Fact_Loan_Repayment`, `Dim_Customer`, `Dim_Account`, `Dim_Loan_Contract`, `Dim_Date` |

## Dashboards

### Customer Behavior: Login Analytics
Total login attempts, customers, devices, and average logins per customer; logins by hour, month, and weekday; weekday vs. weekend and AM/PM split; logins by education, employment status, and employer.

### Transaction Analytics
Active customers, transaction count and total amount; amount by status and type (credit/debit); monthly trends; deposits vs. outflow and net liquidity by account type; breakdowns by job title, card type, gender, family status, education, and car/home ownership; income and liability analysis.

### Loan Analytics
Total loans, loan amount, customers, and average loan; application status (approved/pending/rejected) and contract status (fully paid/active/defaulted); overdue accounts, average days overdue, default rate, high-risk loans; risk heatmap and delinquent customers table; interest, paid amount, collection efficiency, and late-payment trends.

## Suggested Folder Contents

```
06-powerbi-dashboards/
├── pbix/            # .pbix files (consider Git LFS)
├── screenshots/
└── dax-measures.md  # Documented DAX measures
```

## Setup

1. Open the `.pbix` in Power BI Desktop.
2. Update the data source to your Fabric Warehouse SQL endpoint.
3. Refresh and publish to your Fabric workspace.
