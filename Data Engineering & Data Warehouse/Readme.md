# Data Pipeline

A scheduled **Microsoft Fabric Data Pipeline** that extracts data from the Azure SQL OLTP database and loads it into the Fabric Data Warehouse (`FinTech_DW`) using incremental loading.

## Flow

```
Azure SQL Database ──► Copy job (incremental) ──► FinTech_DW (staging) ──► Master Orchestration ──► Facts & Dims
```

## 1. Incremental Copy Job

A scheduled copy job reads changes from the Azure SQL database and writes them to the warehouse.

![Fabric Copy Job](./1.pipeline.png)

| Setting | Value |
|---------|-------|
| Source | Azure SQL Database (`Fin-Tech`) |
| Destination | Fabric Warehouse `FinTech_DW` |
| Mode | Incremental copy |
| Schedule | Every 72 hours (current configuration) |

## 2. Pipeline Orchestration

The pipeline chains the copy job to a stored procedure that runs the whole transformation.

![Fabric Pipeline](./2.pipeline.png)

| Step | Activity type | Description |
|------|---------------|-------------|
| 1 | **Copy job** (`Get_data from Azure SQL…`) | Pulls delta changes from the OLTP database |
| 2 | **Stored procedure** (`Master Orchestration`) | Runs `usp_Master_Load`, which loads all dimensions and facts. Runs only if step 1 succeeds. |

## 3. ETL Logic

| Stage | What happens |
|-------|--------------|
| **Extract** | Delta changes are pulled from Azure SQL OLTP |
| **Transform** | Business rules, data cleansing, surrogate key generation |
| **Load** | Incremental load into warehouse staging and final tables (schema `dw`) |

## 4. Load Stored Procedures

![Warehouse Load Procedures](./images/load-procedures.png)

| Type | Procedures |
|------|-----------|
| Dimensions | `usp_Load_Dim_Account`, `usp_Load_Dim_Card`, `usp_Load_Dim_Customer`, `usp_Load_Dim_Loan_Contract`, `usp_Load_Dim_Location`, `usp_Load_Dim_Merchant`, `usp_Load_Dim_ML_Model`, `usp_Load_Dim_Txn_Rule` |
| Facts | `usp_Load_Fact_Card_Attempt`, `usp_Load_Fact_Fraud_Assessment`, `usp_Load_Fact_Loan`, `usp_Load_Fact_Loan_Repayment`, `usp_Load_Fact_Login_Attempt`, `usp_Load_Fact_Transaction` |
| Master | `usp_Master_Load` (calls the dimension loads first, then the facts) |

> Dimensions should load before facts so that surrogate keys exist when facts are resolved.

## Setup

1. Create a Fabric workspace and the `FinTech_DW` warehouse (see [Data Warehouse](../data-warehouse)).
2. Create the load stored procedures in the `dw` schema.
3. In Fabric, create a **Data Pipeline**:
   - Add a **Copy job** activity (Azure SQL → `FinTech_DW`, incremental).
   - Add a **Stored procedure** activity calling `dw.usp_Master_Load`, connected on success.
4. Set the schedule (currently 72 hours) and run once manually.
5. Check the run in **Monitor** and verify row counts in the warehouse.

## Monitoring & Troubleshooting

- Use Fabric **Monitor** to see run history, duration, and failures.
- If the copy succeeds but the loads fail, check the stored procedure output and any staging-table mismatches.
- Re-running is safe when loads are incremental, but check for duplicate keys on the first full load.

