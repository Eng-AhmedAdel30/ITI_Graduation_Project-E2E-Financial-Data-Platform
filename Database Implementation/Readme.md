# 01 · OLTP Operational Database

The operational banking database, hosted on **Azure SQL Database**, that captures all customer, account, card, transaction, fraud, and loan activity.

## Overview

| Item | Value |
|------|-------|
| Database name | `Fin-Tech` |
| Platform | Azure SQL Database (Standard S0, 10 DTUs) |
| Region | UAE North |
| ER design | 22 entities |
| Physical tables | 20 |
| Stored procedures | 35 |
| Views | 2 (feed the ML models) |
| Triggers | Yes, for consistency and fraud checks |

## Tables (20)

**Customers & access:** `Customer`, `User_Login`, `Login_Attempt`, `Financial_History`
**Accounts & cards:** `Account`, `AccountOwner`, `Bank`, `Merchants`, `Card`, `Card_Attempt`
**Transactions & fraud:** `Transactions_Header`, `Transaction_Entry`, `Transactions_Audit`, `Fraud_Assessment`, `Fraud_Alert`, `Transaction_Rules`
**Lending:** `Loan_Application`, `Loan_Contract`, `Re_Payment_Schedule`, `Risk_Assessment`

## Stored Procedures (35)

Grouped by purpose (see the SQL files for the full list):

- **Customer & account:** `sp_CreateCustomerAccount`, `sp_GetCustomerProfile`, `sp_Customer360Profile`, `sp_GetAccountSummary`, `sp_UserLogin`
- **Money movement:** `sp_Deposit`, `sp_Withdraw`, `sp_TransferMoney`, `sp_OnlinePurchase_card`, `sp_OnlinePurchaseByLogin`
- **Cards:** `sp_BlockCard`, `sp_UnblockCard`, `sp_GetCardDetails`
- **Fraud:** `sp_CalculateFraudScore`, `sp_RunFraudChecks`, `SP_Fraud_Detection_Monitoring`, `SP_Fraud_Investigation`, `SP_Fraud_Monitoring`, `sp_GetFraudAlerts`
- **Loans & risk:** `sp_ApproveLoan`, `sp_RunRiskAssessment`, `SP_Loan_Risk_Assessment`, `SP_Credit_Decision_Analysis`, `SP_Loan_Collection`, `SP_Repayment_Performance`, `sp_GetLoanStatus`
- **Reporting / KPIs:** `SP_Executive_KPI`, `SP_Executive_Overview`, `sp_GetDashboardKPIs`, `rpt_*` procedures (geo-cluster, failed-login spikes, loan approval)

## Views (ML feature sources)

- `vw_FraudFeatures`
- `vw_LoanRiskFeatures`

## Triggers & Constraints

- `trg_AfterInsert_LoanApplication`, `trg_AfterUpdate_LoanApplication_Approved` on `Loan_Application`
- `trg_RunFraudChecks` on `Transactions_Header`
- Primary/foreign keys and constraints to keep data consistent

## Suggested Folder Contents

```
01-oltp-database/
├── schema/          # CREATE TABLE scripts
├── procedures/      # Stored procedures
├── views/
├── triggers/
├── seed-data/       # Sample/synthetic data (no real customer data)
└── diagrams/        # ER diagram (22 entities) + database diagram (20 tables)
```

## Setup

1. Create an Azure SQL Database (or use a local SQL Server instance).
2. Run scripts in this order: schema → constraints → views → procedures → triggers.
3. Load seed data.
4. Configure the server firewall to allow your client IP.

> Do not commit connection strings or the Azure subscription ID.
