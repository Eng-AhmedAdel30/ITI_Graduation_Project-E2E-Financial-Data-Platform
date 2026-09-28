# 03 · ML Loan Risk Model & API

A machine learning credit-risk classifier deployed as a REST API on Azure and consumed by Power Apps.

## Pipeline

1. **Data collection:** customer financial, behavioral, and demographic features. Target: `Risk_Label` (0 = Low Risk, 1 = High Risk).
2. **Data preparation:**
   - Removed `App_status` (data leakage, 100% correlated with target)
   - Median imputation for missing numeric values
   - Label encoding for 5 categorical columns (encoders saved for API use)
   - 3 engineered features: Installment-to-Balance ratio, Total Payment Risk score, Loan-to-Balance ratio
3. **Training:** XGBoost and CatBoost with SMOTE oversampling and GridSearchCV (5-fold stratified CV)
4. **Evaluation and selection:** stratified 80/20 split (14,903 train / 3,726 test, `random_state=42`)
5. **Deployment:** FastAPI packaged and deployed to Azure App Service
6. **Integration:** Power Apps calls the API through a Custom Connector and Power Automate

## Results

| Metric | XGBoost (selected) | CatBoost |
|--------|-------------------|----------|
| F1 score | 98.33% | 98.33% |
| Recall (high risk) | **98.90%** | 98.57% |
| Precision | 97.78% | 98.10% |

XGBoost was selected because F1 was tied and it has higher recall, so it catches more high-risk customers. Top feature: `Previous_Risk_Score` (~58.8% importance).

## Artifacts

```
best_risk_model.pkl
encoders.pkl
feature_columns.pkl
```

## API

**Framework:** FastAPI (Swagger UI at `/docs`), Pydantic for validation, served with Uvicorn.

| Endpoint | Purpose |
|----------|---------|
| `POST /predict` | Single prediction |
| `POST /predict/batch` | Bulk prediction |

**Example request**

```json
{
  "Requested_Amount": 15000,
  "No_Of_Months": 24,
  "Monthly_Installment_Est": 680,
  "Gender": "M",
  "Education_Level": "Higher education",
  "Family_Members": 3,
  "Family_Status": "Married",
  "Home_Ownership": "Owned",
  "Balance": 5000,
  "Acc_Type": "Savings",
  "Debt_To_Balance_Ratio": 35,
  "Late_Payment_Count": 1,
  "Missed_Payment_Count": 0,
  "Avg_Payment_Delay_Days": 3.5,
  "Previous_Risk_Score": 45
}
```

**Example response**

```json
{ "risk_prediction": 0, "risk_probability": 0.3454, "risk_label": "Low Risk" }
```

## Suggested Folder Contents

```
03-ml-risk-model/
├── notebooks/       # Training workflow (load, clean, encode, split, evaluate, save)
├── api/             # main.py, requirements.txt
├── models/          # .pkl artifacts (or use Git LFS)
└── data/            # Sample data only
```

## Run Locally

```bash
pip install fastapi uvicorn pydantic joblib xgboost scikit-learn pandas
uvicorn main:app --reload
# open http://localhost:8000/docs
```

## Azure Deployment

- Azure App Service (Linux, Python 3.12), HTTPS endpoints
- Publish via code deployment
- Restrict CORS and add authentication (API key) before production use

> Note: the ML training data is labeled with a risk score derived from the system's own rules. Review for label leakage and bias before using in real lending decisions.
