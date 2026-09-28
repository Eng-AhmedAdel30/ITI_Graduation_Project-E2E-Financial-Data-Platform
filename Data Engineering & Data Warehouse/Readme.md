# 02 · Data Engineering & Data Warehouse

Automated ETL from the Azure SQL OLTP database into a **Microsoft Fabric Data Warehouse** (`FinTech_DW`) modeled as a galaxy (multi-fact star) schema.

## Pipeline

```
Azure SQL (OLTP) ──► Copy job (incremental) ──► Fabric Warehouse ──► Master Orchestration (stored proc)
```

- **Scheduling:** Fabric pipeline with a scheduled copy job (72-hour interval in the current setup)
- **Extract:** Delta changes pulled from Azure SQL OLTP
- **Transform:** Business rules, data cleansing, surrogate key generation
- **Load:** Incremental load into staging and final warehouse tables (schema `dw`)
- **Orchestration:** `usp_Master_Load` runs all dimension and fact loads

## Load Procedures

**Dimensions:** `usp_Load_Dim_Account`, `_Card`, `_Customer`, `_Loan_Contract`, `_Location`, `_Merchant`, `_ML_Model`, `_Txn_Rule`
**Facts:** `usp_Load_Fact_Card_Attempt`, `_Fraud_Assessment`, `_Loan`, `_Loan_Repayment`, `_Login_Attempt`, `_Transaction`
**Master:** `usp_Master_Load`

## Warehouse Model (Galaxy Schema)

| Domain | Fact table | Description |
|--------|-----------|-------------|
| Banking & Payments | `Fact_Transaction` | Transaction amounts and volumes |
| Banking & Payments | `Fact_Card_Attempt` | Card attempts and outcomes |
| Lending | `Fact_Loan` | Loan applications and approvals |
| Lending | `Fact_Loan_Repayment` | Repayment activity |
| Security | `Fact_Login_Attempt` | User login activity |

**Conformed dimensions:** `Dim_Customer`, `Dim_Account`, `Dim_Card`, `Dim_Bank`, `Dim_Merchant`, `Dim_Loan_Contract`, `Dim_Location`, `Dim_Date`, `Dim_Time`

## Suggested Folder Contents

```
02-data-engineering/
├── warehouse-ddl/        # CREATE TABLE for dims and facts
├── load-procedures/      # usp_Load_* and usp_Master_Load
├── pipeline/             # Exported Fabric pipeline JSON
└── diagrams/             # Galaxy schema diagram
```

## Setup

1. Create a Fabric workspace and a Warehouse named `FinTech_DW`.
2. Run the DDL, then create the load stored procedures.
3. Create a Fabric Pipeline: **Copy job** (Azure SQL → Warehouse) followed by a **Stored procedure** activity calling `usp_Master_Load`.
4. Set the schedule and run once to verify.

> Optional: Azure SQL also offers "Mirror database in Fabric (preview)" as an alternative ingestion path.
