# 06 · Power BI Dashboards

Interactive dashboards built on three semantic models over the **Fabric Data Warehouse** (`FinTech_DW`, galaxy schema). All reports share one dark FinTech theme, a KPI card row at the top of each page, and slicers for filtering.

| # | Dashboard | Pages | Fact tables | Audience |
|---|-----------|-------|-------------|----------|
| 1 | [User Login Analytics](./01-user-login-analytics) | 4 | `Fact_Login_Attempt` | Security and digital-channel teams |
| 2 | [Transaction Analytics](./02-transaction-analytics) | 9 | `Fact_Transaction`, `Fact_Card_Attempt` | Branch managers, financial analysts |
| 3 | [Loan Analytics](./03-loan-analytics) | 7 | `Fact_Loan`, `Fact_Loan_Repayment` | Loan officers, risk and collections teams |

## Folder Structure

```
06-powerbi-dashboards/
├── README.md
├── 01-user-login-analytics/
│   ├── README.md
│   ├── pbix/
│   └── screenshots/
├── 02-transaction-analytics/
│   ├── README.md
│   ├── pbix/
│   └── screenshots/
└── 03-loan-analytics/
    ├── README.md
    ├── pbix/
    └── screenshots/
```

## Shared Setup

1. Open the `.pbix` file in **Power BI Desktop**.
2. Go to **Transform data → Data source settings** and point to your Fabric Warehouse SQL endpoint (`FinTech_DW`).
3. Click **Refresh**, then **Publish** to your Fabric workspace.
4. Optionally schedule a refresh that runs after the Fabric pipeline finishes (the pipeline currently runs every 72 hours).

> Do not commit credentials or workspace URLs. Large `.pbix` files may need Git LFS.

## Shared Design Conventions

- Dark navy theme with FinTech logo in the left panel
- KPI cards across the top, then 2 to 3 visuals per page
- Slicers on the left panel (varies by dashboard)
- Star-schema relationships: single-direction, one-to-many from dimensions to facts

## Dimensions Used Across Models

`Dim_Customer`, `Dim_Account`, `Dim_Date`, `Dim_Time`, `Dim_Card`, `Dim_Bank`, `Dim_Merchant`, `Dim_Location`, `Dim_Loan_Contract`
