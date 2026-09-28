

-- FRAUD_DETECTION ENGINE :

-- ══════════════════════════════════════════════════════════════════
-- STEP 1 — TRIGGER  trg_RunFraudChecks
-- ══════════════════════════════════════════════════════════════════
CREATE OR ALTER TRIGGER trg_RunFraudChecks
ON Transactions_Header
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TransID INT;

    -- Cursor handles single-row and bulk inserts correctly.
    -- A plain "SELECT @TransID = Trans_ID FROM inserted" would
    -- silently drop all but the last row on a multi-row insert.
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT Trans_ID FROM inserted;

    OPEN cur;
    FETCH NEXT FROM cur INTO @TransID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sp_RunFraudChecks @TransID;
        FETCH NEXT FROM cur INTO @TransID;
    END;

    CLOSE cur;
    DEALLOCATE cur;
END;
GO


-- ══════════════════════════════════════════════════════════════════
-- STEP 2 — PROCEDURE  sp_RunFraudChecks
-- ══════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_RunFraudChecks
    @TransID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Working variables ─────────────────────────────────────────
    DECLARE
        @AccID           INT,
        @Amount          DECIMAL(18,2),
        @DeviceID        NVARCHAR(100),
        @TransType       NVARCHAR(50),
        @TransDateTime   DATETIME2,
        @TransHour       TINYINT,
        @TxnCount        INT,
        @DeviceAccCount  INT,
        @RuleID          INT,
        @RuleScore       DECIMAL(5,2),
        @RuleThreshold   DECIMAL(18,2);

    -- ── 1. Pull transaction data from the correct tables ──────────
    
    SELECT TOP 1
        @AccID  = te.Acc_ID,
        @Amount = te.Amount
    FROM Transaction_Entry te
    WHERE te.Trans_ID = @TransID
    ORDER BY CASE te.Entry_Type WHEN 'DEBIT' THEN 0 ELSE 1 END;

    SELECT
        @TransDateTime = Trans_DateTime,
        @TransType     = Trans_Type
    FROM Transactions_Header
    WHERE Trans_ID = @TransID;

    SELECT @DeviceID = Device_ID
    FROM   Transactions_Audit
    WHERE  Trans_ID = @TransID;

    SET @TransHour = DATEPART(HOUR, @TransDateTime);

    -- RULE 1 — HIGH_AMOUNT
    -- Fires when the transaction amount exceeds the rule threshold.

    SELECT @RuleID = Rule_ID, @RuleScore = Rule_Score, @RuleThreshold = Threshold
    FROM   Transaction_Rules
    WHERE  Rule_Name = 'HIGH_AMOUNT';

    IF @Amount > @RuleThreshold
        AND NOT EXISTS (
            SELECT 1 FROM Fraud_Alert
            WHERE Trans_ID = @TransID AND Rule_ID = @RuleID
        )
    BEGIN
        INSERT INTO Fraud_Alert (Trans_ID, Rule_ID, Alert_Score)
        VALUES                  (@TransID, @RuleID, @RuleScore);
    END;

    -- RULE 2 — VELOCITY_CHECK
    -- Fires when the same account has >= threshold transactions && within the last 60 seconds (including this one).
    
    SELECT @RuleID = Rule_ID, @RuleScore = Rule_Score, @RuleThreshold = Threshold
    FROM   Transaction_Rules
    WHERE  Rule_Name = 'VELOCITY_CHECK';

    SELECT @TxnCount = COUNT(DISTINCT th.Trans_ID)
    FROM   Transactions_Header th
    JOIN   Transaction_Entry   te ON te.Trans_ID = th.Trans_ID
    WHERE  te.Acc_ID = @AccID
      AND  DATEDIFF(SECOND, th.Trans_DateTime, @TransDateTime) BETWEEN 0 AND 60;

    IF @TxnCount >= @RuleThreshold
        AND NOT EXISTS (
            SELECT 1 FROM Fraud_Alert
            WHERE Trans_ID = @TransID AND Rule_ID = @RuleID
        )
    BEGIN
        INSERT INTO Fraud_Alert (Trans_ID, Rule_ID, Alert_Score)
        VALUES                  (@TransID, @RuleID, @RuleScore);
    END;

    -- RULE 3 — NEW_DEVICE
    -- Fires when the Device_ID seen in Transactions_Audit has never been associated with this account before.
    
    SELECT @RuleID = Rule_ID, @RuleScore = Rule_Score
    FROM   Transaction_Rules
    WHERE  Rule_Name = 'NEW_DEVICE';

    IF @DeviceID IS NOT NULL
        AND NOT EXISTS (
            SELECT 1
            FROM   Transactions_Audit  ta
            JOIN   Transactions_Header th  ON th.Trans_ID = ta.Trans_ID
            JOIN   Transaction_Entry   te  ON te.Trans_ID = th.Trans_ID
            WHERE  ta.Device_ID = @DeviceID
              AND  te.Acc_ID    = @AccID
              AND  th.Trans_ID <> @TransID   -- exclude the current transaction
        )
        AND NOT EXISTS (
            SELECT 1 FROM Fraud_Alert
            WHERE Trans_ID = @TransID AND Rule_ID = @RuleID
        )
    BEGIN
        INSERT INTO Fraud_Alert (Trans_ID, Rule_ID, Alert_Score)
        VALUES                  (@TransID, @RuleID, @RuleScore);
    END;

    -- RULE 4 — ODD_HOUR  (new)
    -- Fires when the transaction falls between 00:00 and 05:00 local

    SELECT @RuleID = Rule_ID, @RuleScore = Rule_Score
    FROM   Transaction_Rules
    WHERE  Rule_Name = 'ODD_HOUR';

    IF @TransHour BETWEEN 0 AND 5
        AND NOT EXISTS (
            SELECT 1 FROM Fraud_Alert
            WHERE Trans_ID = @TransID AND Rule_ID = @RuleID
        )
    BEGIN
        INSERT INTO Fraud_Alert (Trans_ID, Rule_ID, Alert_Score)
        VALUES                  (@TransID, @RuleID, @RuleScore);
    END;

    -- RULE 5 — MULTI_ACCOUNT_DEVICE  (new)
    -- Fires when the same Device_ID has been used to transact on more than N distinct accounts today. 
    -- A single device hitting many accounts is a strong mule/takeover signal.

    SELECT @RuleID = Rule_ID, @RuleScore = Rule_Score, @RuleThreshold = Threshold
    FROM   Transaction_Rules
    WHERE  Rule_Name = 'MULTI_ACCOUNT_DEVICE';

    IF @DeviceID IS NOT NULL
    BEGIN
        SELECT @DeviceAccCount = COUNT(DISTINCT te.Acc_ID)
        FROM   Transactions_Audit  ta
        JOIN   Transactions_Header th ON th.Trans_ID = ta.Trans_ID
        JOIN   Transaction_Entry   te ON te.Trans_ID = th.Trans_ID
        WHERE  ta.Device_ID        = @DeviceID
          AND  CAST(th.Trans_DateTime AS DATE) = CAST(@TransDateTime AS DATE);

        IF @DeviceAccCount > @RuleThreshold
            AND NOT EXISTS (
                SELECT 1 FROM Fraud_Alert
                WHERE Trans_ID = @TransID AND Rule_ID = @RuleID
            )
        BEGIN
            INSERT INTO Fraud_Alert (Trans_ID, Rule_ID, Alert_Score)
            VALUES                  (@TransID, @RuleID, @RuleScore);
        END;
    END;


    -- RULE 6 — RAPID_LOCATION_CHANGE  (new)
    -- Fires when this account had a transaction from a different IP address within the last 30 minutes. 
    -- Impossible travel / session hijack signal.

    SELECT @RuleID = Rule_ID, @RuleScore = Rule_Score
    FROM   Transaction_Rules
    WHERE  Rule_Name = 'RAPID_LOCATION_CHANGE';

    DECLARE @CurrentIP NVARCHAR(45);
    SELECT  @CurrentIP = IP_Address
    FROM    Transactions_Audit
    WHERE   Trans_ID = @TransID;

    IF @CurrentIP IS NOT NULL
        AND EXISTS (
            SELECT 1
            FROM   Transactions_Audit  ta
            JOIN   Transactions_Header th ON th.Trans_ID = ta.Trans_ID
            JOIN   Transaction_Entry   te ON te.Trans_ID = th.Trans_ID
            WHERE  te.Acc_ID              = @AccID
              AND  th.Trans_ID           <> @TransID
              AND  ta.IP_Address         <> @CurrentIP
              AND  ta.IP_Address          IS NOT NULL
              AND  DATEDIFF(MINUTE, th.Trans_DateTime, @TransDateTime) BETWEEN 0 AND 30
        )
        AND NOT EXISTS (
            SELECT 1 FROM Fraud_Alert
            WHERE Trans_ID = @TransID AND Rule_ID = @RuleID
        )
    BEGIN
        INSERT INTO Fraud_Alert (Trans_ID, Rule_ID, Alert_Score)
        VALUES                  (@TransID, @RuleID, @RuleScore);
    END;

    -- ── Final step: roll up all fired alerts into an assessment ───
    EXEC sp_CalculateFraudScore @TransID;
END;
GO


-- ══════════════════════════════════════════════════════════════════
-- STEP 3 — PROCEDURE  sp_CalculateFraudScore
-- Sums Alert_Score for all Fraud_Alert rows for this transaction,assigns a Risk_Level, and writes one Fraud_Assessment row.
-- ══════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_CalculateFraudScore
    @TransID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @TotalScore DECIMAL(6,2),
        @RiskLevel  NVARCHAR(10),
        @IsFraud    BIT = 0;

    -- ── Sum all alert scores for this transaction ─────────────────
    SELECT @TotalScore = ISNULL(SUM(Alert_Score), 0)
    FROM   Fraud_Alert
    WHERE  Trans_ID = @TransID;

    -- ── Determine risk level ──────────────────────────────────────
    IF @TotalScore < 30
        SET @RiskLevel = 'LOW';

    ELSE IF @TotalScore < 60
        SET @RiskLevel = 'MEDIUM';

    ELSE IF @TotalScore < 80
    BEGIN
        SET @RiskLevel = 'HIGH';
        SET @IsFraud   = 1;
    END

    ELSE
    BEGIN
        SET @RiskLevel = 'CRITICAL';
        SET @IsFraud   = 1;
    END

    -- ── Insert fraud assessment ───────────────────────────────────
    IF NOT EXISTS (SELECT 1 FROM Fraud_Assessment WHERE Trans_ID = @TransID)
    BEGIN
        INSERT INTO Fraud_Assessment (Trans_ID, Total_Score, Risk_Level, Is_Fraud,ML_Model)
        VALUES                       (@TransID, @TotalScore, @RiskLevel, @IsFraud,'sp_CalculateFraudScore');
    END
    ELSE
    BEGIN
        -- Re-running after new alerts fired — update the existing row.
        UPDATE Fraud_Assessment
        SET    Total_Score = @TotalScore,
               Risk_Level  = @RiskLevel,
               Is_Fraud    = @IsFraud,
               Assessed_At = GETDATE()
        WHERE  Trans_ID = @TransID;
    END

    -- ── Block fraudulent transactions ─────────────────────────────
    IF @IsFraud = 1
    BEGIN
        UPDATE Transactions_Header
        SET    Trans_Status = 'Reversed'
        WHERE  Trans_ID = @TransID;
    END
END;
GO

