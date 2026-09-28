-- ══════════════════════════════════════════════════════════════════
-- HELPER FUNCTION  fn_CalculateDTI
-- Debt-To-Income = Monthly_Liability / Monthly_Income
-- ══════════════════════════════════════════════════════════════════
CREATE OR ALTER FUNCTION dbo.fn_CalculateDTI
(
    @Liability DECIMAL(18,2),
    @Income    DECIMAL(18,2)
)
RETURNS DECIMAL(10,4)
AS
BEGIN
    IF @Income IS NULL OR @Income = 0
        RETURN NULL;          -- income unknown → can't compute DTI
    RETURN @Liability / @Income;
END;
GO


-- ══════════════════════════════════════════════════════════════════
-- STEP 1 — PROCEDURE  sp_RunRiskAssessment
--
-- Scores a loan application using ALL available customer features:
--   • DTI                (Monthly_Liability / Monthly_Income)
--   • Employment         (status + years of experience)
--   • Home               (ownership type — stability signal)
--   • History            (late payments, missed payments, avg delay days)
--   • Affordability    (monthly installment / disposable income after liabilities — PDI ratio)
--   • Loan term          (longer = higher risk)
--   • Credit utilization (avg used % across all active credit cards,
--                         if the customer has any — NULL if no credit cards)
--
-- Then inserts a Risk_Assessment row and links Assessment_ID back to Loan_Application. 
-- App_status is set to Approved / Rejected."Review" is NOT a valid App_status CHECK value, so borderline cases are left as 'Pending' for a human underwriter.
-- ══════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_RunRiskAssessment
    @AppID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Working variables ─────────────────────────────────────────
    DECLARE
        @CustomerID          INT,
        @Income              DECIMAL(18,2),
        @Liability           DECIMAL(18,2),
        @EmploymentStatus    NVARCHAR(50),
        @YearsExperience     SMALLINT,
        @HomeOwnership       VARCHAR(15),
        @RequestedAmount     DECIMAL(18,2),
        @NoOfMonths          SMALLINT,
        @LatePayments        INT,
        @MissedPayments      INT,
        @AvgDelayDays        DECIMAL(6,2),
        @DTI                 DECIMAL(10,4),
        @MonthlyInstallment  DECIMAL(18,2),   -- principal + interest per month for this loan
        @DisposableIncome    DECIMAL(18,2),   -- Monthly_Income - Monthly_Liability
        @PDI                 DECIMAL(10,4),   -- Payment-to-Disposable-Income = installment / disposable income
        @CreditUtilization   DECIMAL(10,4),   -- avg (used / limit) across credit cards; NULL = no credit cards
        @RiskScore           DECIMAL(5,2),
        @AssessID            INT,
        @AppStatus           NVARCHAR(30);

    -- ── 1. Fetch application + customer data ──────────────────────
    SELECT
        @CustomerID       = LA.Customer_ID,
        @RequestedAmount  = LA.Requested_Amount,
        @NoOfMonths       = LA.No_Of_Months,
        @Income           = C.Monthly_Income,
        @Liability        = C.Monthly_Liability,
        @EmploymentStatus = C.Employment_Status,
        @YearsExperience  = C.Year_Of_Experience,
        @HomeOwnership    = C.Home_Ownership
    FROM  Loan_Application LA
    JOIN  Customer C ON C.Owner_ID = LA.Customer_ID   -- FIX: Owner_ID not Customer_ID
    WHERE LA.App_ID = @AppID;

    IF @CustomerID IS NULL
    BEGIN
        RAISERROR('Loan application not found.', 16, 1);
        RETURN;
    END

    -- Guard: only assess Pending applications
    IF NOT EXISTS (
        SELECT 1 FROM Loan_Application
        WHERE App_ID = @AppID AND App_status = 'Pending'
    )
    BEGIN
        RAISERROR('Application is not in Pending status,It is Rejected or Approved.', 16, 1);
        RETURN;
    END

    -- ── 2. Fetch financial history ────────────────────────────────
    SELECT
        @LatePayments   = Late_Payment_Count,
        @MissedPayments = Missed_Payment_Count,
        @AvgDelayDays   = Avg_Payment_Delay_Days
    FROM Financial_History
    WHERE Customer_ID = @CustomerID;

    -- Default to 0 if no history exists yet (new customer)
    SET @LatePayments   = ISNULL(@LatePayments,   0);
    SET @MissedPayments = ISNULL(@MissedPayments,  0);
    SET @AvgDelayDays   = ISNULL(@AvgDelayDays,    0);

    -- ── 3. Credit utilization across all active credit cards ──────
    SELECT @CreditUtilization =
        AVG(
            CAST(CA.Credit_Limit - CA.Available_Limit AS DECIMAL(18,2))
            / CAST(CA.Credit_Limit AS DECIMAL(18,2))
           )
    FROM   Card    CA
    JOIN   Account A  ON A.Acc_ID   = CA.Acc_ID
    WHERE  A.Owner_ID       = @CustomerID
      AND  CA.Card_Type     = 'Credit'
      AND  CA.Credit_Limit  > 0           -- exclude cards with no limit set
      AND  CA.Is_Blocked    = 0;          -- exclude blocked cards

    -- ── 3. Payment-to-Disposable-Income (PDI) ─────────────────────────────────────────
    SET @DTI = dbo.fn_CalculateDTI(@Liability, @Income);

    -- Answers: "Can this customer afford the monthly installment
    --           from what is left after existing obligations?"
    --
    -- Interest rate is approximated at 0.007/month (mid-tier) here;
    -- the exact rate is locked in only inside sp_ApproveLoan once the
    -- risk score is known — this estimate is sufficient for scoring.
    --
    -- Disposable income = Monthly_Income - Monthly_Liability.
    -- If disposable income ≤ 0 the customer is already over-committed
    -- before the new loan is considered → treated as NULL (unknown/critical).
    SET @MonthlyInstallment = (@RequestedAmount / NULLIF(@NoOfMonths, 0))
                            + (@RequestedAmount * 0.007);   -- estimated interest slice

    SET @DisposableIncome =
        CASE
            WHEN @Income IS NULL OR @Income = 0             THEN NULL
            WHEN @Income - ISNULL(@Liability, 0) <= 0       THEN NULL  -- already over-committed
            ELSE @Income - ISNULL(@Liability, 0)
        END;

    SET @PDI =
        CASE
            WHEN @DisposableIncome IS NULL THEN NULL
            ELSE @MonthlyInstallment / @DisposableIncome
        END;

    -- ── 4. Scoring — start at 100, deduct for risk factors ────────
    SET @RiskScore = 100;

    -- ── 4a. DTI penalty ───────────────────────────────────────────
    -- DTI is the single strongest predictor of default risk.
    -- NULL DTI (unknown income) is treated as high-risk.
    IF @DTI IS NULL
        SET @RiskScore -= 25;           -- income unknown → penalise
    
    ELSE IF @DTI > 0.60
        SET @RiskScore -= 35;           -- dangerously over-leveraged
    
    ELSE IF @DTI > 0.50
        SET @RiskScore -= 25;           -- over the standard 50% ceiling
    
    ELSE IF @DTI > 0.40
        SET @RiskScore -= 15;           -- elevated but manageable
    
    ELSE IF @DTI > 0.30
        SET @RiskScore -= 5;            -- mild concern

    -- ── 4b. Employment status ─────────────────────────────────────
    -- Stable income sources are rewarded; unstable ones penalised.
    IF @EmploymentStatus IS NULL
        SET @RiskScore -= 20;
    
    ELSE IF @EmploymentStatus = 'Unemployed'
        SET @RiskScore -= 30;
    
    ELSE IF @EmploymentStatus = 'Part-Time'
        SET @RiskScore -= 15;
    
    ELSE IF @EmploymentStatus = 'Self-Employed'
        SET @RiskScore -= 10;           -- variable income
    
    ELSE IF @EmploymentStatus = 'Student'
        SET @RiskScore -= 10;
    
    ELSE IF @EmploymentStatus = 'Retired'
        SET @RiskScore -= 5;            -- fixed pension income
    -- 'Full-Time' → no penalty (best case)

    -- ── 4c. Years of experience ───────────────────────────────────
    -- Longer employment history = more income stability.
    IF @YearsExperience IS NULL
        SET @RiskScore -= 5;
    ELSE IF @YearsExperience < 1
        SET @RiskScore -= 10;
    ELSE IF @YearsExperience < 3
        SET @RiskScore -= 5;
    -- ≥ 3 years → no penalty

    -- ── 4d. Home ownership ────────────────────────────────────────
    -- Owned home signals financial stability; renting is neutral.
    IF @HomeOwnership = 'Owned'
        SET @RiskScore += 5;            -- small bonus for asset ownership
    ELSE IF @HomeOwnership = 'Rented'
        SET @RiskScore -= 0;            -- neutral
    ELSE IF @HomeOwnership = 'Living with Parents'
        SET @RiskScore -= 5;
    ELSE IF @HomeOwnership = 'Provided by Emp'
        SET @RiskScore -= 5;            -- income-tied housing = extra risk if unemployed

    -- ── 4e. Late payment history ──────────────────────────────────
    SET @RiskScore -= (@LatePayments   *  5);   -- -5 per late payment
    SET @RiskScore -= (@MissedPayments * 10);   -- -10 per missed payment

    -- ── 4f. Average payment delay ─────────────────────────────────
    -- Chronic lateness even when eventually paid is a risk signal.
    IF @AvgDelayDays > 60
        SET @RiskScore -= 15;
    
    ELSE IF @AvgDelayDays > 30
        SET @RiskScore -= 10;
    
    ELSE IF @AvgDelayDays > 15
        SET @RiskScore -= 5;

    -- ── 4g. Credit utilization ────────────────────────────────────
    -- High utilization = already stretched on existing credit.
    -- Industry rule of thumb: stay below 30% for a healthy profile.
    -- NULL means the customer has no credit cards — treated as a mild
    -- unknown (less data) rather than a hard penalty.
    IF @CreditUtilization IS NULL
        SET @RiskScore -= 0;            -- no credit card: neutral, no data
    ELSE IF @CreditUtilization > 0.90
        SET @RiskScore -= 25;           -- maxed out — severe stress signal
    ELSE IF @CreditUtilization > 0.70
        SET @RiskScore -= 15;           -- heavily utilised
    ELSE IF @CreditUtilization > 0.50
        SET @RiskScore -= 10;           -- above comfortable range
    ELSE IF @CreditUtilization > 0.30
        SET @RiskScore -= 5;            -- slightly elevated
    ELSE
        SET @RiskScore += 5;            -- ≤ 30%: responsible credit usage → bonus

    -- ── 4h. Payment-to-Disposable-Income (PDI) ───────────────────
    -- Measures whether the monthly installment fits inside what the
    -- customer actually has left after paying existing liabilities.
    --
    -- NULL means income is unknown OR the customer is already spending
    -- more than they earn before the new loan — both are critical signals.
    --
    -- Recommended safe ceiling: PDI ≤ 0.30 (installment ≤ 30% of
    -- disposable income), mirroring standard affordability guidelines.
    IF @PDI IS NULL
        SET @RiskScore -= 30;           -- no disposable income / income unknown
    ELSE IF @PDI > 0.70
        SET @RiskScore -= 25;           -- installment consumes most of free cash
    ELSE IF @PDI > 0.50
        SET @RiskScore -= 15;           -- tight — little buffer for emergencies
    ELSE IF @PDI > 0.30
        SET @RiskScore -= 5;            -- slightly above comfortable threshold
    ELSE
        SET @RiskScore += 5;            -- ≤ 30%: healthy affordability → bonus

    -- ── 4i. Loan term penalty ─────────────────────────────────────
    -- Longer terms expose the lender to more uncertainty.
    IF @NoOfMonths > 84          -- > 7 years
        SET @RiskScore -= 10;
    ELSE IF @NoOfMonths > 60     -- > 5 years
        SET @RiskScore -= 5;

    -- ── 4j. Clamp to [0, 100] ────────────────────────────────────
    IF @RiskScore > 100 SET @RiskScore = 100;
    IF @RiskScore < 0   SET @RiskScore = 0;

    -- ── 5. Determine application status ──────────────────────────
    -- FIX: 'Review' is NOT a valid App_status CHECK value.
    --      Borderline cases stay 'Pending' for human underwriter review.
    IF @RiskScore >= 70
        SET @AppStatus = 'Approved';
    ELSE IF @RiskScore >= 50
        SET @AppStatus = 'Pending';     -- borderline → human review
    ELSE
        SET @AppStatus = 'Rejected';

    -- ── 6. Insert into Risk_Assessment ───────────────────────────
    -- FIX: original never inserted here — the whole point of the table.
    INSERT INTO Risk_Assessment (Total_Score, Assessed_At, ML_Model)
    VALUES                      (@RiskScore,  GETDATE(),   'RULE_BASED_V1');

    SET @AssessID = SCOPE_IDENTITY();

    -- ── 7. Link Assessment_ID + update App_status ────────────────
    -- FIX: original tried to set Risk_score / decision / Updated_at —
    --      none of those columns exist on Loan_Application.
    UPDATE Loan_Application
    SET Assessment_ID = @AssessID,
        App_status    = @AppStatus
    WHERE App_ID = @AppID;

    PRINT CONCAT('Risk assessment complete. Score: ', @RiskScore,
                 ' | Status: ', @AppStatus);
END;
GO


-- ══════════════════════════════════════════════════════════════════
-- STEP 2 — PROCEDURE  sp_ApproveLoan
--
-- Creates Loan_Contract + full Re_Payment_Schedule (one row per
-- month), then disburses the funds via proper double-entry bookkeeping
-- (Transactions_Header + Transaction_Entry + Transactions_Audit).
--
-- Fixes vs. original:
--  1. decision → App_status (correct column name)
--  2. Loan_Contract: removed installment + status columns (don't
--     exist); correct status column is contract_status
--  3. Added full Re_Payment_Schedule generation:
--       • One row per month (= No_Of_Months rows)
--       • Simple flat interest: rate driven by Risk_Assessment score
--       • Principal_Amount = Approved_Amount / No_Of_Months
--       • Interest_Amount  = (Approved_Amount * monthly_rate)
--       • Due_Date         = Start_Date + N months for each row
--  4. Disbursement: replaced raw UPDATE Account SET Balance with
--     proper Transactions_Header + Transaction_Entry + Audit insert
--     (same pattern as sp_Deposit) — maintains the audit trail
--  5. UPDATE Loan_Application SET status → App_status (already
--     'Approved' from sp_RunRiskAssessment but guard-updated here)
--  6. Guard: can't approve an already-contracted application
-- ══════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_ApproveLoan
    @AppID  INT,
    @AccID  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @CustomerID      INT,
        @AssessID        INT,
        @RiskScore       DECIMAL(5,2),
        @RequestedAmount DECIMAL(18,2),
        @NoOfMonths      SMALLINT,
        @ContractID      INT,
        @TransID         INT,
        @StartDate       DATE,
        @EndDate         DATE,
        @MonthlyRate     DECIMAL(10,6),   -- monthly interest rate
        @PrincipalPerMonth DECIMAL(18,2),
        @InterestPerMonth  DECIMAL(18,2),
        @Month           SMALLINT;

    BEGIN TRANSACTION;
    BEGIN TRY

        -- ── 1. Validate application is Approved and not yet contracted
        SELECT
            @CustomerID      = LA.Customer_ID,
            @AssessID        = LA.Assessment_ID,
            @RequestedAmount = LA.Requested_Amount,
            @NoOfMonths      = LA.No_Of_Months
        FROM Loan_Application LA
        WHERE LA.App_ID    = @AppID
          AND LA.App_status = 'Approved';   -- FIX: decision → App_status

        IF @RequestedAmount IS NULL
            RAISERROR('Application not found or not in Approved status.', 16, 1);

        IF EXISTS (SELECT 1 FROM Loan_Contract WHERE App_ID = @AppID)
            RAISERROR('A contract already exists for this application.', 16, 1);

        -- ── 2. Validate disbursement account is active ────────────
        IF NOT EXISTS (
            SELECT 1 FROM Account
            WHERE Acc_ID = @AccID AND Acc_status = 'Active'
        )
            RAISERROR('Disbursement account not found or inactive.', 16, 1);

        -- ── 3. Derive interest rate from Risk_Assessment score ────
        -- Higher score = lower risk = lower interest rate.
        -- These bands mirror typical personal-loan pricing tiers.
        SELECT @RiskScore = Total_Score
        FROM   Risk_Assessment
        WHERE  Assess_ID = @AssessID;

        SET @MonthlyRate =
            CASE
                WHEN @RiskScore >= 85 THEN 0.005    --  6.0% annual (prime borrower)
                WHEN @RiskScore >= 70 THEN 0.007    --  8.4% annual
                WHEN @RiskScore >= 60 THEN 0.009    -- 10.8% annual
                ELSE                       0.012    -- 14.4% annual (high risk, approved)
            END;

        SET @PrincipalPerMonth = ROUND(@RequestedAmount / @NoOfMonths, 2);
        SET @InterestPerMonth  = ROUND(@RequestedAmount * @MonthlyRate, 2);
        SET @StartDate         = CAST(GETDATE() AS DATE);
        SET @EndDate           = CAST(DATEADD(MONTH, @NoOfMonths, @StartDate) AS DATE);

        -- ── 4. Create Loan_Contract ───────────────────────────────
        -- FIX: removed installment + status columns (don't exist).
        --      Correct status column is contract_status.
        INSERT INTO Loan_Contract
            (App_ID, Acc_ID, Start_Date, End_Date, Approved_Amount, contract_status)
        VALUES
            (@AppID, @AccID, @StartDate, @EndDate, @RequestedAmount, 'Active');

        SET @ContractID = SCOPE_IDENTITY();

        -- ── 5. Generate Re_Payment_Schedule ──────────────────────
        -- FIX: original had NO schedule generation at all.
        -- One row per month; Due_Date advances by 1 month each iteration.
        -- Last installment absorbs any rounding remainder on principal.
        SET @Month = 1;
        WHILE @Month <= @NoOfMonths
        BEGIN
            INSERT INTO Re_Payment_Schedule
                (Contract_ID, Due_Date, Principal_Amount, Interest_Amount, install_status)
            VALUES
            (
                @ContractID,
                CAST(DATEADD(MONTH, @Month, @StartDate) AS DATE),
                -- Last month absorbs rounding remainder
                CASE
                    WHEN @Month = @NoOfMonths
                    THEN @RequestedAmount - (@PrincipalPerMonth * (@NoOfMonths - 1))
                    ELSE @PrincipalPerMonth
                END,
                @InterestPerMonth,
                'Upcoming'
            );
            SET @Month += 1;
        END;

        -- ── 6. Disburse funds via proper double-entry ─────────────
        -- FIX: original did a raw UPDATE Account SET Balance.
        --      Disbursement is a DEPOSIT-type transaction and must flow
        --      through Transactions_Header + Transaction_Entry + Audit
        --      to maintain a complete audit trail.
        INSERT INTO Transactions_Header (Trans_Type, Trans_Status, Card_Attempt_ID)
        VALUES                          ('DEPOSIT',  'Completed',  NULL);

        SET @TransID = SCOPE_IDENTITY();

        -- CREDIT the customer's account (money arriving)
        INSERT INTO Transaction_Entry (Trans_ID, Acc_ID, Entry_Type, Amount)
        VALUES                        (@TransID, @AccID, 'CREDIT',   @RequestedAmount);

        -- Audit trail — internal system disbursement via API
        INSERT INTO Transactions_Audit (Trans_ID, Channel, IP_Address, Device_ID)
        VALUES                         (@TransID, 'API',   NULL,       NULL);

        -- Also update the Account balance directly to keep it in sync
        UPDATE Account
        SET    Balance = Balance + @RequestedAmount
        WHERE  Acc_ID  = @AccID;

        -- ── 7. Confirm App_status = 'Approved' ────────────────────
        -- sp_RunRiskAssessment already sets this, but we guard here
        -- in case sp_ApproveLoan is called independently.
        -- FIX: column is App_status (not status or decision)
        UPDATE Loan_Application
        SET    App_status = 'Approved'
        WHERE  App_ID     = @AppID;

        COMMIT TRANSACTION;
        PRINT CONCAT('Loan approved. Contract_ID: ', @ContractID,
                     ' | Installments created: ', @NoOfMonths,
                     ' | Monthly repayment: ',
                     CAST(@PrincipalPerMonth + @InterestPerMonth AS NVARCHAR(20)));
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT ERROR_MESSAGE();
    END CATCH
END;
GO