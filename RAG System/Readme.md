# 04 · AI Analyst (Enterprise RAG System)

A natural-language-to-SQL assistant that lets non-technical users query the Fabric Data Warehouse and get tables, charts, and business summaries automatically.

## Architecture

```
Streamlit Chat UI ─► LangChain Agent (Llama-3 70B via Groq API)
                          │
                          ▼
              AI Guardrails & Schema Verification
                          │  (validated T-SQL)
                          ▼
              Microsoft Fabric Data Warehouse
                          │
                          ▼
        Auto-Visualization Engine (Plotly) + Insight summary
```

## Features

- **Natural language to T-SQL:** the LLM generates SQL from warehouse schema context
- **Guardrails:** generated SQL is validated against the warehouse schema before execution to reduce hallucinations
- **"White-box" AI:** the exact SQL is shown for engineering validation
- **Dynamic chart routing:** the agent picks Bar, Line, Pie/Donut, or Treemap based on data shape (time series → line, categories → bar, distributions → pie/treemap)
- **Business narrative:** an automatic insight summary of the results
- **Structured results:** clean dataframes, exportable to PDF/Excel

## Example Questions

- "Show me the total transaction amounts per month"
- "What is the total loan amount per branch?"
- "Credit vs. debit share of transaction amounts"

## Tech Stack

Streamlit · LangChain · Llama-3 70B (Groq API) · Plotly · pandas · Microsoft Fabric SQL endpoint

## Suggested Folder Contents

```
04-ai-assistant-rag/
├── app.py               # Streamlit UI
├── agent/               # LangChain agent + prompts + schema context
├── guardrails/          # SQL/schema validation
├── viz/                 # Chart routing logic
├── requirements.txt
└── .env.example
```

## Setup

```bash
pip install -r requirements.txt
cp .env.example .env     # add GROQ_API_KEY and Fabric connection details
streamlit run app.py     # http://localhost:8501
```

`.env.example`

```
GROQ_API_KEY=
FABRIC_SQL_ENDPOINT=
FABRIC_DATABASE=FinTech_DW
```

## Notes and Limitations

- Restrict the database login to **read-only** access.
- Guardrails should allow `SELECT` statements only.
- LLM-generated summaries should be checked against the displayed data.
