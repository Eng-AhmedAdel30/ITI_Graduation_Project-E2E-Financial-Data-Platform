# 05 · Power Apps Front-End

A low-code banking interface for customers and staff, integrated with the Azure SQL database and the ML risk API.

## Screens

| Screen | Purpose |
|--------|---------|
| Login / Create Account | Authentication and access control (backed by `sp_UserLogin` and `sp_CreateCustomerAccount`) |
| Home | Client info: username, user ID, customer ID, last login, created date |
| Transaction Management | Shows balance; Deposit, Withdraw, Purchase, Transfer |
| Loan Application | Loan, personal, account, and credit-history inputs, then **Predict Risk** |
| History | Transaction history |

## ML Integration Flow

```
Power Apps (Canvas) ─► Power Automate flow ─► HTTP via Custom Connector ─► FastAPI on Azure App Service
                                                                                  │
                     Risk label + probability shown instantly ◄───────────────────┘
```

- Communication over HTTPS with an API key configured in the Custom Connector
- JSON request/response (see [`03-ml-risk-model`](../03-ml-risk-model))
