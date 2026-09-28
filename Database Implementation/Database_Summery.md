# FINTECH GRADUATION PROJECT
## ERD → Relational Mapping Analysis + DDL (Microsoft SQL Server)

---

## STEP 1 – ERD SUMMARY (from XML)
### Entities, Attributes, and Relationships

#### ENTITIES & ATTRIBUTES

| Entity | Attributes | Notes |
| :--- | :--- | :--- |
| **E1: Re_Payment_Schedule** | `Schedule_ID` (PK), `Payment_date`, `Due_Date`, `Status`, `principal_Amount`, `interest_Amount` | |
| **E2: Loan_Contract** | `Contract_ID` (PK), `Start_Date`, `End_Date`, `Approved_amount`, `status`, `installment` | |
| **E3: Loan_Application** | `App_ID` (PK), `Requested_Amount`, `No_of_Months`, `Created_at`, `status`, `int_rate` *(derived)*, `Requested_Amount/Monthly_Income` *(derived)* | |
| **E4: Risk_Assessment** | `Assessment_ID` (PK), `loan_app_ID`, `score`, `decision`, `created_at`, `updated_at` | |
| **E5: Customer** | `Customer_ID` (PK), `FName`, `LName`, `Full_Name`, `Address` (`Street`, `City`, `State`, `Zip_Code`), `Email`, `Phone`, `National_ID`, `grade`, `Device_id`, `location` (`lat`, `lon`) | ↳ **MERGED** with `Financial_Profile` (E7) per instruction |
| **E7: Financial_Profile** | `Profile_ID`, `Cust_id`, `Monthly_income`, `Employment_Status`, `Employer_name`, `Year_of_experience`, `Job_Title`, `monthly_liability`, `Home_Ownership`, `Credit_Utilization` *(derived)*, `DTI` *(derived)*, `Created_at`, `Updated_at` | |
| **E8: Card** | `card_id` (PK), `Acc_id`, `Card_Number`, `CVV`, `Expiry_date`, `PIN_hash`, `Card_Type`, `is_blocked`, `Credit_limit`, `available_limit`, `issued_at` | |
| **E9: Transactions_Header** | `Trans_ID` (PK), `Trans_Type`, `Trans_Date_Time`, `unix_time`, `Amount`, `location`, `Device_id`, `Status` | |
| **E11: Fraud_Alert** | `Alert_id` (PK), `Alert_score`, `Rule_Code`, `Rule_Description`, `Trigger_Value`, `Timestamp` | |
| **E12: Fraud_Assessment** | `Assess_id` (PK), `Total_score`, `is_fraud`, `Risk_level`, `Assessment_Status`, `Created_at` | |
| **E13: Account** | `Acc_ID` (PK), `Owner_ID`, `owner_type`, `Balance`, `Currency`, `Type`, `Status`, `Created_at` | |
| **Financial_History** | `History_ID` (PK), `Cust_ID`, `Late_Payment_Count`, `missed_payment_count`, `Avg_Payment_delay_Days`, `last_update` | |
| **card_attempt** | `attempt_id` (PK), `Card_id`, `Attempt_Time`, `Is_Success`, `ATM_ID`, `Location` | |
| **User_Login** | `User_name` (PK or natural key), `Cust_id`, `pass_hash`, `last_login`, `Failed_attempts`, `lock_status` | |
| **Login_Attempt** | `attempt_id` (PK), `cust_id`, `attempt_time`, `device_id`, `is_success` | |
| **Transactions_entries**| `entry_ID` (PK), `Trans_ID`, `Acc_id`, `Debit`, `Credit` | |
| **Transactions_Audit** | `audit_ID` (PK), `Trans_ID`, `channel`, `trans_loc`, `Device_id`, `ip_address`, `Risk_score` | |
| **Merchant** | `Merchant_ID` (PK), `Name`, `merch_loc`, `Category` | |
| **Bank_System** | `institution_ID` (PK), `Name` | |

---

#### RELATIONSHIPS SUMMARY

* **R1:** `Re_Payment_Schedule` **"has"** `Loan_Contract` (`M:1`) *(Contract has M schedules)*
* **R2:** `Loan_Contract` **"Create"** `Loan_Application` (`1:1`) *(Optional on contract side)*
* **R3:** `Loan_Application` **"has"** `Risk_Assessment` (`1:1`) *(Both mandatory)*
* **R4:** `Customer` **"Apply for"** `Loan_Application` (`1:M`)
* **R5:** `Customer` **"has"** `Financial_Profile` (`1:1`) → **MERGED**
* **R6:** `Card` **"has"** `Account` (`M:1`) *(Card belongs to account; cardinality: Card(M) → Account(1))*
* **R7:** `Account` **"processes"** `Transactions_Header` (`M:M`) *(Merchant/Customer/Bank owner)*  
  ↳ *Handled via Owner_ID + owner_type in Transactions_Header*
* **R8:** **"Has"** (`Account` ↔ `Customer` / `Merchant` / `Bank`) `M:M` resolved via `owner_type`
* **R9:** `Transactions_Header` **"have"** `Fraud_Alert` (`1:M`)
* **R10:** `card_attempt` **"has"** `Card` (`M:1`)
* **R11:** `Account` **"for"** `Loan_Contract` (`1:M`)
* **R12:** `Card` **"has"** `card_attempt` (`1:M`) *(Via has diamond, M side = attempt)*
* **R13:** `card_attempt` **"produce"** `Transactions_Header` (`1:0..1`)
* **R14:** `Customer` **"has"** `User_Login` (`1:1`) *(Separated as requested)*
* **R15:** `Customer` **"has"** `Login_Attempt` (`1:M`)
* **R16:** `Customer` **"has"** `Financial_History` (`1:1`)
* **R17:** `Transactions_Header` **"have"** `Transactions_entries` (`1:M`)
* **R18:** `Transactions_Header` **"have"** `Transactions_Audit` (`1:M`) *(Audit log)*
* **R19:** `Fraud_Assessment` **"has"** `Fraud_Alert` (`1:M`)
* **R20:** `Transactions_Header` **"has"** `Fraud_Assessment` (`1:0..1`)
* **R21:** `Merchant` **"has"** `Account` (`1:M`)
* **R22:** `Bank_System` **"has"** `Account` (`1:M`)

---

## STEP 2 – MAPPING DECISIONS (rule-by-rule)

> **SPECIAL INSTRUCTION:**
> - Merge `Customer` + `Financial_Profile`
> - Keep `Customer` + `User_Login` separated

### 1. Merged Entities
* **Customer + Financial_Profile → MERGED into one table (`Customer`)**  
  * **Rule:** `Customer` "has" `Financial_Profile` is 1:1 mandatory on both sides. All `Financial_Profile` columns are added directly to the `Customer` table.

### 2. Separated 1:1 Entities
* **Customer ←→ User_Login:** 1:1 OPTIONAL on `User_Login` side (not every customer is guaranteed to have an account instantly, and they are conceptually separate). Per instruction: keep as **SEPARATE** tables.  
  * **Mapping Rule (2-case):** Add FK (`Cust_id`) in `User_Login` (total participation side).

---

### REGULAR ENTITIES
*(Each receives its own table)*

1. `Customer` *(merged with Financial_Profile)*
2. `Loan_Application`
3. `Loan_Contract`
4. `Re_Payment_Schedule`
5. `Risk_Assessment`
6. `Account`
7. `Card`
8. `card_attempt`
9. `Transactions_Header`
10. `Transactions_entries`
11. `Transactions_Audit`
12. `Fraud_Alert`
13. `Fraud_Assessment`
14. `Financial_History`
15. `User_Login`
16. `Login_Attempt`
17. `Merchant`
18. `Bank_System`

---

### BINARY 1:1 RELATIONSHIPS

* **R2: Loan_Contract "Create" Loan_Application** (`1:1`)
  * `Loan_Application` MANDATORY, `Loan_Contract` OPTIONAL (rejected apps have no contract).
  * **Mapping:** Add FK `App_ID` into `Loan_Contract` (total-participation side = `Loan_Contract` once created must reference an app). Contract is an optional outcome.
* **R3: Loan_Application "has" Risk_Assessment** (`1:1`, BOTH mandatory)
  * **Merge?** No — they are conceptually and temporally distinct processes. Merge only when both sides are mandatory AND it makes semantic sense. Here `Risk_Assessment` is a separate engine output.
  * **Mapping:** Add FK `App_ID` in `Risk_Assessment` (`Risk_Assessment` total participation).
* **R14: Customer "has" User_Login**
  * Separated per instruction.
  * **Mapping:** Add FK `Cust_id` in `User_Login`.
* **R16: Customer "has" Financial_History** (`1:1` mandatory both sides)
  * Since `Financial_History` is a distinct tracking record, keep separate.
  * **Mapping:** Add FK `Cust_id` in `Financial_History`.
* **R20: Transactions_Header "has" Fraud_Assessment** (`1:0..1` optional)
  * **Mapping:** Add FK `Trans_ID` in `Fraud_Assessment`.

---

### BINARY 1:N RELATIONSHIPS

* **R1:** `Loan_Contract`(1) → `Re_Payment_Schedule`(M)  
  ↳ Add FK `Contract_ID` in `Re_Payment_Schedule`
* **R4:** `Customer`(1) → `Loan_Application`(M)  
  ↳ Add FK `Cust_id` in `Loan_Application`
* **R6:** `Account`(1) → `Card`(M)  
  ↳ Add FK `Acc_id` in `Card`
* **R11:** `Account`(1) → `Loan_Contract`(M)  
  ↳ Add FK `Acc_id` in `Loan_Contract`
* **R12:** `Card`(1) → `card_attempt`(M)  
  ↳ Add FK `Card_id` in `card_attempt`
* **R15:** `Customer`(1) → `Login_Attempt`(M)  
  ↳ Add FK `Cust_id` in `Login_Attempt`
* **R17:** `Transactions_Header`(1) → `Transactions_entries`(M)  
  ↳ Add FK `Trans_ID` in `Transactions_entries`
* **R18:** `Transactions_Header`(1) → `Transactions_Audit`(M)  
  ↳ Add FK `Trans_ID` in `Transactions_Audit`
* **R19:** `Fraud_Assessment`(1) → `Fraud_Alert`(M)  
  ↳ Add FK `Assess_id` in `Fraud_Alert`
* **R9:** `Transactions_Header`(1) → `Fraud_Alert`(M)  
  ↳ Add FK `Trans_ID` in `Fraud_Alert`  
  * **Note:** `Fraud_Alert` references BOTH its parent transaction (for context) AND the `Fraud_Assessment` that contains it. `Trans_ID` is the FK to Header; `Assess_id` is the FK to `Fraud_Assessment`.
* **R21:** `Merchant`(1) → `Account`(M)  
  ↳ Add FK `Merchant_ID` (nullable) in `Account`
* **R22:** `Bank_System`(1) → `Account`(M)  
  ↳ Add FK `institution_ID` (nullable) in `Account`

---

### BINARY M:N RELATIONSHIPS

* **R7 / R8: Account ↔ Transactions_Header (processes)**
  * The owner of an account can be `Customer`, `Merchant`, or `Bank_System`.
  * `Account` is already tied to its owner via `Owner_ID` + `owner_type`.
  * `Transactions_Header` is linked to `Account` via the "processes" relationship.
  * Cardinality from XML: `Account`(M) ↔ `Transactions_Header`(M).
  * **Mapping:** Create junction table `Account_Transaction` (`Acc_ID` FK, `Trans_ID` FK, composite PK).
* **R13: card_attempt(1) → Transactions_Header(0..1) [produce]**
  * Treated as `1:0..1` (not M:N). Add FK `attempt_id` (nullable) in `Transactions_Header` to reference the originating card attempt.
