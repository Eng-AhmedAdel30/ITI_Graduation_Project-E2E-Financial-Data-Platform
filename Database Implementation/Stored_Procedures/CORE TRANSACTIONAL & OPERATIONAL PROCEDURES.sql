-- =============================================================================
-- PART 2: CORE TRANSACTIONAL & OPERATIONAL PROCEDURES (sp_)
-- =============================================================================

/* Object:  StoredProcedure [dbo].[sp_CreateCustomerAccount] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- Flow: Creates Customer, Account, User Login & Financial History atomically.
-- ============================================================
CREATE PROCEDURE [dbo].[sp_CreateCustomerAccount]
    @FName              NVARCHAR(100),
    @LName              NVARCHAR(100),
    @Gender             NVARCHAR(10)   = NULL,
    @National_ID        NVARCHAR(50),
    @Email              NVARCHAR(255),
    @Phone              NVARCHAR(20)   = NULL,
    @Education_Level    NVARCHAR(50)   = NULL,
    @Employment_Status  NVARCHAR(50)   = NULL,
    @Monthly_Income     DECIMAL(18,2)  = NULL,
    @Monthly_Liability  DECIMAL(18,2)  = 0,
    @Job_Title          NVARCHAR(100)  = NULL,
    @Year_Of_Experience INT            = NULL,
    @Employer_Name      NVARCHAR(255)  = NULL,
    @City               NVARCHAR(100)  = NULL,
    @State              NVARCHAR(100)  = NULL,
    @Street             NVARCHAR(255)  = NULL,
    @Zip                NVARCHAR(20)   = NULL,
    @Family_Members     INT            = NULL,
    @Family_Status      NVARCHAR(50)   = NULL,
    @Home_Ownership     NVARCHAR(50)   = NULL,
    @FLAG_OWN_CAR       BIT            = 0,
    @Acc_Type           NVARCHAR(50)   = 'Savings',  
    @Currency           NVARCHAR(10)   = 'EGP',
    @Initial_Balance    DECIMAL(18,2)  = 0,
    @Create_Card        BIT            = 0,
    @Card_Number        NVARCHAR(20)   = NULL,
    @Card_Type          NVARCHAR(50)   = NULL,       
    @Expiry_Date        DATE           = NULL,
    @CVV                NVARCHAR(5)    = NULL,
    @Credit_Limit       DECIMAL(18,2)  = 0,
    @Username           NVARCHAR(100),
    @Password_Hash      NVARCHAR(255),               
    @Device_ID          NVARCHAR(255)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Required fields validation
        IF @FName IS NULL OR @LName IS NULL OR @National_ID IS NULL OR @Email IS NULL OR @Username IS NULL OR @Password_Hash IS NULL
        BEGIN
            RAISERROR('All required fields must be supplied.', 16, 1);
            RETURN;
        END

        -- Duplicate Checks
        IF EXISTS (SELECT 1 FROM dbo.Customer WHERE National_ID = @National_ID) OR EXISTS (SELECT 1 FROM dbo.Customer WHERE Email = @Email)
        BEGIN
            RAISERROR('Customer with this National ID or Email already exists.', 16, 1);
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM dbo.User_Login WHERE Username = @Username)
        BEGIN
            RAISERROR('This username is already taken.', 16, 1);
            RETURN;
        END

        -- Step 1: INSERT Customer
        INSERT INTO dbo.Customer (
            FName, LName, Gender, National_ID, Email, Phone, Education_Level, Employment_Status, 
            Monthly_Income, Monthly_Liability, Job_Title, Year_Of_Experience, Employer_Name, 
            City, State, Street, Zip, Family_Members, Family_Status, Home_Ownership, FLAG_OWN_CAR
        ) VALUES (
            @FName, @LName, @Gender, @National_ID, @Email, @Phone, @Education_Level, @Employment_Status, 
            @Monthly_Income, @Monthly_Liability, @Job_Title, @Year_Of_Experience, @Employer_Name, 
            @City, @State, @Street, @Zip, @Family_Members, @Family_Status, @Home_Ownership, @FLAG_OWN_CAR
        );
        DECLARE @New_Owner_ID INT = SCOPE_IDENTITY();

        -- Step 2: INSERT AccountOwner
        INSERT INTO dbo.AccountOwner (Owner_ID, Owner_Type) VALUES (@New_Owner_ID, 'Customer');

        -- Step 3: INSERT Account
        INSERT INTO dbo.Account (Owner_ID, Acc_Type, Currency, Balance, Acc_status, Created_At)
        VALUES (@New_Owner_ID, @Acc_Type, @Currency, @Initial_Balance, 'Active', GETDATE());
        DECLARE @New_Acc_ID INT = SCOPE_IDENTITY();

        -- Step 4: INSERT Card (Optional)
        DECLARE @New_Card_ID INT = NULL;
        IF @Create_Card = 1
        BEGIN
            INSERT INTO dbo.Card (Acc_ID, Card_Number, Card_Type, Expiry_Date, CVV, Is_Blocked, Credit_Limit, Available_Limit)
            VALUES (@New_Acc_ID, @Card_Number, @Card_Type, @Expiry_Date, @CVV, 0, @Credit_Limit, @Credit_Limit);
            SET @New_Card_ID = SCOPE_IDENTITY();
        END

        -- Step 5: INSERT User_Login
        INSERT INTO dbo.User_Login (Customer_ID, Username, Password_Hash, Is_Active, Created_At)
        VALUES (@New_Owner_ID, @Username, @Password_Hash, 1, GETDATE());
        DECLARE @New_Login_ID INT = SCOPE_IDENTITY();

        -- Step 6: INSERT Financial_History
        INSERT INTO dbo.Financial_History (Customer_ID, Late_Payment_Count, Missed_Payment_Count, Avg_Payment_Delay_Days, Last_Update)
        VALUES (@New_Owner_ID, 0, 0, 0, GETDATE());

        COMMIT TRANSACTION;

        SELECT 1 AS Result, 'Account created successfully.' AS Message, @New_Owner_ID AS Owner_ID, @New_Acc_ID AS Acc_ID, @New_Login_ID AS Login_ID, @New_Card_ID AS Card_ID;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT -1 AS Result, ERROR_MESSAGE() AS Message, NULL AS Owner_ID, NULL AS Acc_ID, NULL AS Login_ID, NULL AS Card_ID;
    END CATCH;
END;
GO

/* Object:  StoredProcedure [dbo].[sp_ApproveLoan] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_ApproveLoan]
    @AppID  INT,
    @AccID  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CustomerID INT, @AssessID INT, @RiskScore DECIMAL(5,2), @RequestedAmount DECIMAL(18,2), @NoOfMonths SMALLINT, @ContractID INT, @TransID INT, @StartDate DATE, @EndDate DATE, @MonthlyRate DECIMAL(10,6), @PrincipalPerMonth DECIMAL(18,2), @InterestPerMonth DECIMAL(18,2), @Month SMALLINT;

    BEGIN TRANSACTION;
    BEGIN TRY
        SELECT @CustomerID = LA.Customer_ID, @AssessID = LA.Assessment_ID, @RequestedAmount = LA.Requested_Amount, @NoOfMonths = LA.No_Of_Months, @StartDate = CAST(LA.Created_At AS DATE)
        FROM Loan_Application LA WHERE LA.App_ID = @AppID AND LA.App_status = 'Approved';

        IF @RequestedAmount IS NULL RAISERROR('Application not found or not approved.', 16, 1);
        IF EXISTS (SELECT 1 FROM Loan_Contract WHERE App_ID = @AppID) RAISERROR('Contract already exists.', 16, 1);
        IF NOT EXISTS (SELECT 1 FROM Account WHERE Acc_ID = @AccID AND Acc_status = 'Active') RAISERROR('Account inactive.', 16, 1);

        SELECT @RiskScore = Total_Score FROM Risk_Assessment WHERE Assess_ID = @AssessID;
        SET @MonthlyRate = CASE WHEN @RiskScore >= 85 THEN 0.005 WHEN @RiskScore >= 70 THEN 0.007 WHEN @RiskScore >= 60 THEN 0.009 ELSE 0.012 END;

        SET @PrincipalPerMonth = ROUND(@RequestedAmount / @NoOfMonths, 2);
        SET @InterestPerMonth  = ROUND(@RequestedAmount * @MonthlyRate, 2);
        SET @EndDate           = CAST(DATEADD(MONTH, @NoOfMonths, @StartDate) AS DATE);

        INSERT INTO Loan_Contract (App_ID, Acc_ID, Start_Date, End_Date, Approved_Amount, contract_status, interest_rate)
        VALUES (@AppID, @AccID, @StartDate, @EndDate, @RequestedAmount, 'Active', @MonthlyRate * 100 * 12);
        SET @ContractID = SCOPE_IDENTITY();

        SET @Month = 1;
        WHILE @Month <= @NoOfMonths
        BEGIN
            INSERT INTO Re_Payment_Schedule (Contract_ID, Due_Date, Principal_Amount, Interest_Amount, install_status)
            VALUES (@ContractID, CAST(DATEADD(MONTH, @Month, @StartDate) AS DATE), CASE WHEN @Month = @NoOfMonths THEN @RequestedAmount - (@PrincipalPerMonth * (@NoOfMonths - 1)) ELSE @PrincipalPerMonth END, @InterestPerMonth, 'Upcoming');
            SET @Month += 1;
        END;

        INSERT INTO Transactions_Header (Trans_Type, Trans_Status, Card_Attempt_ID) VALUES ('DEPOSIT', 'Completed', NULL);
        SET @TransID = SCOPE_IDENTITY();
        INSERT INTO Transaction_Entry (Trans_ID, Acc_ID, Entry_Type, Amount) VALUES (@TransID, @AccID, 'CREDIT', @RequestedAmount);
        INSERT INTO Transactions_Audit (Trans_ID, Channel, IP_Address, Device_ID) VALUES (@TransID, 'API', NULL, NULL);

        UPDATE Account SET Balance = Balance + @RequestedAmount WHERE Acc_ID = @AccID;
        COMMIT TRANSACTION;
        PRINT CONCAT('Loan approved. Contract_ID: ', @ContractID);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT ERROR_MESSAGE();
    END CATCH
END;
GO

/* Object:  StoredProcedure [dbo].[sp_Deposit] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_Deposit]
    @AccID      INT,
    @Amount     DECIMAL(18,2),
    @Channel    NVARCHAR(20)  = 'ATM',
    @DeviceID   NVARCHAR(100) = NULL,
    @IPAddress  NVARCHAR(45)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @TransID INT, @AccStatus NVARCHAR(50);

    BEGIN TRANSACTION;
    BEGIN TRY
        IF @Amount <= 0 RAISERROR('Amount must be greater than zero.', 16, 1);
        IF @Channel NOT IN ('ATM', 'APP', 'POS', 'WEB', 'API') RAISERROR('Invalid channel.', 16, 1);

        SELECT @AccStatus = Acc_status FROM dbo.Account WHERE Acc_ID = @AccID;
        IF @AccStatus IS NULL OR @AccStatus != 'Active' RAISERROR('Account not active or not found.', 16, 1);

        UPDATE dbo.Account SET Balance = Balance + @Amount WHERE Acc_ID = @AccID;
        INSERT INTO dbo.Transactions_Header (Trans_Type, Trans_Status, Card_Attempt_ID) VALUES ('DEPOSIT', 'Completed', NULL);
        SET @TransID = SCOPE_IDENTITY();
        INSERT INTO dbo.Transaction_Entry (Trans_ID, Acc_ID, Entry_Type, Amount) VALUES (@TransID, @AccID, 'CREDIT', @Amount);
        INSERT INTO dbo.Transactions_Audit (Trans_ID, Channel, IP_Address, Device_ID) VALUES (@TransID, @Channel, @IPAddress, @DeviceID);

        COMMIT TRANSACTION;
        PRINT CONCAT('✔ Deposit completed. Trans_ID: ', @TransID);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT ERROR_MESSAGE();
    END CATCH
END;
GO

/* Object:  StoredProcedure [dbo].[sp_CalculateFraudScore] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_CalculateFraudScore]
    @TransID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TotalScore DECIMAL(6,2), @RiskLevel NVARCHAR(10), @IsFraud BIT = 0;

    SELECT @TotalScore = ISNULL(SUM(Alert_Score), 0) FROM Fraud_Alert WHERE Trans_ID = @TransID;

    IF @TotalScore < 30 SET @RiskLevel = 'LOW';
    ELSE IF @TotalScore < 60 SET @RiskLevel = 'MEDIUM';
    ELSE IF @TotalScore < 80 BEGIN SET @RiskLevel = 'HIGH'; SET @IsFraud = 1; END
    ELSE BEGIN SET @RiskLevel = 'CRITICAL'; SET @IsFraud = 1; END

    IF NOT EXISTS (SELECT 1 FROM Fraud_Assessment WHERE Trans_ID = @TransID)
        INSERT INTO Fraud_Assessment (Trans_ID, Total_Score, Risk_Level, Is_Fraud, ML_Model)
        VALUES (@TransID, @TotalScore, @RiskLevel, @IsFraud, 'sp_CalculateFraudScore');
    ELSE
        UPDATE Fraud_Assessment SET Total_Score = @TotalScore, Risk_Level = @RiskLevel, Is_Fraud = @IsFraud, Assessed_At = GETDATE() WHERE Trans_ID = @TransID;

    IF @IsFraud = 1
        UPDATE Transactions_Header SET Trans_Status = 'Reversed' WHERE Trans_ID = @TransID;
END;
GO

/* Object:  StoredProcedure [dbo].[sp_BlockCard] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_BlockCard]
    @Card_ID INT,
    @Acc_ID  INT        
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Card WHERE Card_ID = @Card_ID AND Acc_ID = @Acc_ID)
    BEGIN
        SELECT -1 AS Result, 'Card not found or ownership mismatch.' AS Message;
        RETURN;
    END;

    UPDATE dbo.Card SET Is_Blocked = 1 WHERE Card_ID = @Card_ID;
    SELECT 1 AS Result, 'Card blocked successfully.' AS Message;
END;
GO

/* Object:  StoredProcedure [dbo].[sp_GetAccountSummary] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_GetAccountSummary]
    @Acc_ID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.Acc_ID, a.Acc_Type, a.Currency, a.Balance, a.Acc_status, ao.Owner_Type, cd.Card_ID, cd.Card_Number, cd.Card_Type, cd.Is_Blocked, cd.Credit_Limit, cd.Available_Limit, cd.Expiry_Date
    FROM dbo.Account a
    INNER JOIN dbo.AccountOwner ao ON ao.Owner_ID = a.Owner_ID
    LEFT JOIN dbo.Card cd ON cd.Acc_ID = a.Acc_ID
    WHERE a.Acc_ID = @Acc_ID;
END;
GO

/* Object:  StoredProcedure [dbo].[sp_GetCardDetails] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_GetCardDetails]
    @Acc_ID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.Card_ID, c.Acc_ID, CONCAT('**** **** **** ', RIGHT(c.Card_Number, 4)) AS Masked_Card_Number, c.Card_Type, c.Expiry_Date, c.CVV, c.Is_Blocked, c.Credit_Limit, c.Available_Limit, ca.Attempt_ID, ca.Attempt_Time, ca.Is_Success, ca.ATM_ID, ca.Location_Lat AS Attempt_Lat, ca.Location_Lon AS Attempt_Lon
    FROM dbo.Card c
    LEFT JOIN dbo.Card_Attempt ca ON ca.Card_ID = c.Card_ID
    WHERE c.Acc_ID = @Acc_ID
    ORDER BY ca.Attempt_Time DESC;
END;
GO

/* Object:  StoredProcedure [dbo].[sp_GetCustomerProfile] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_GetCustomerProfile]
    @Customer_ID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.Owner_ID, CONCAT(c.FName,' ',c.LName) AS [Full Name], c.Email, c.Phone, c.Gender, c.National_ID, c.Education_Level, c.Employment_Status, c.Monthly_Income, c.Monthly_Liability, c.Job_Title, c.City, c.State, a.Acc_ID, a.Acc_Type, a.Currency, a.Balance, a.Acc_status, a.Created_At, ao.Owner_Type, ul.Username, ul.Last_Login, ul.Is_Active
    FROM dbo.Customer c
    INNER JOIN dbo.AccountOwner ao ON ao.Owner_ID = c.Owner_ID
    INNER JOIN dbo.Account a ON a.Owner_ID = ao.Owner_ID
    INNER JOIN dbo.User_Login ul ON ul.Customer_ID = c.Owner_ID
    WHERE c.Owner_ID = @Customer_ID AND a.Acc_status = 'Active';

    SELECT fh.Late_Payment_Count, fh.Missed_Payment_Count, fh.Avg_Payment_Delay_Days, fh.Last_Update 
    FROM dbo.Financial_History fh WHERE fh.Customer_ID = @Customer_ID;
END;
GO

/* Object:  StoredProcedure [dbo].[sp_GetDashboardKPIs] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_GetDashboardKPIs]
    @DateFrom DATETIME = NULL,
    @DateTo DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @DateFrom = ISNULL(@DateFrom, DATEADD(DAY, -30, GETDATE()));
    SET @DateTo = ISNULL(@DateTo, GETDATE());

    SELECT COUNT(DISTINCT th.Trans_ID) AS Total_Transactions, SUM(te.Amount) AS Total_Volume, AVG(te.Amount) AS Avg_Transaction, SUM(CASE WHEN fa.Is_Fraud = 1 THEN 1 ELSE 0 END) AS Fraud_Count, SUM(CASE WHEN fa.Is_Fraud = 1 THEN te.Amount ELSE 0 END) AS Fraud_Volume, COUNT(DISTINCT te.Acc_ID) AS Active_Accounts
    FROM dbo.Transactions_Header th
    INNER JOIN dbo.Transaction_Entry te ON te.Trans_ID = th.Trans_ID
    LEFT JOIN dbo.Fraud_Assessment fa ON fa.Trans_ID = th.Trans_ID
    WHERE th.Trans_DateTime BETWEEN @DateFrom AND @DateTo;

    SELECT COUNT(*) AS Total_Applications, SUM(CASE WHEN la.App_status = 'Approved' THEN 1 ELSE 0 END) AS Approved_Loans, SUM(CASE WHEN la.App_status = 'Rejected' THEN 1 ELSE 0 END) AS Rejected_Loans, SUM(CASE WHEN la.App_status = 'Pending' THEN 1 ELSE 0 END) AS Pending_Loans, AVG(ra.Total_Score) AS Avg_Risk_Score, SUM(lc.Approved_Amount) AS Total_Approved_Amount
    FROM dbo.Loan_Application la
    LEFT JOIN dbo.Risk_Assessment ra ON ra.Assess_ID = la.Assessment_ID
    LEFT JOIN dbo.Loan_Contract lc ON lc.App_ID = la.App_ID
    WHERE la.Created_At BETWEEN @DateFrom AND @DateTo;
END;
GO

/* Object:  StoredProcedure [dbo].[sp_GetFraudAlerts] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_GetFraudAlerts]
    @DateFrom DATETIME = NULL,
    @DateTo DATETIME = NULL,
    @Risk_Level NVARCHAR(20) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT fal.Alert_ID, fal.Trans_ID, fal.Rule_ID, fal.Alert_Score, fal.Triggered_At, th.Trans_Type, th.Trans_Status, th.Trans_DateTime, ta.Trans_Loc, ta.IP_Address, ta.Device_ID, te.Amount, te.Acc_ID, fa.Total_Score, fa.Risk_Level, fa.Is_Fraud, fa.ML_Model, tr.Rule_Name, tr.Rule_Description, tr.Threshold
    FROM dbo.Fraud_Alert fal
    INNER JOIN dbo.Fraud_Assessment fa ON fa.Assess_ID = fal.Alert_ID
    INNER JOIN dbo.Transactions_Header th ON th.Trans_ID = fal.Trans_ID
    INNER JOIN dbo.Transactions_Audit ta ON ta.Trans_ID = fal.Trans_ID
    INNER JOIN dbo.Transaction_Entry te ON te.Trans_ID = th.Trans_ID
    LEFT JOIN dbo.Transaction_Rules tr ON tr.Rule_ID = fal.Rule_ID
    WHERE (@DateFrom IS NULL OR fal.Triggered_At >= @DateFrom) AND (@DateTo IS NULL OR fal.Triggered_At <= @DateTo) AND (@Risk_Level IS NULL OR fa.Risk_Level = @Risk_Level)
    ORDER BY fal.Triggered_At DESC OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT COUNT(*) AS Total_Alerts, SUM(CASE WHEN fa.Is_Fraud = 1 THEN 1 ELSE 0 END) AS Confirmed_Fraud, SUM(CASE WHEN fa.Risk_Level = 'High' THEN 1 ELSE 0 END) AS High_Risk, SUM(CASE WHEN fa.Risk_Level = 'Medium' THEN 1 ELSE 0 END) AS Medium_Risk, SUM(CASE WHEN fa.Risk_Level = 'Low' THEN 1 ELSE 0 END) AS Low_Risk, AVG(fa.Total_Score) AS Avg_Risk_Score
    FROM dbo.Fraud_Alert fal
    INNER JOIN dbo.Fraud_Assessment fa ON fa.Assess_ID = fal.Alert_ID
    WHERE (@DateFrom IS NULL OR fal.Triggered_At >= @DateFrom) AND (@DateTo IS NULL OR fal.Triggered_At <= @DateTo);
END;
GO

/* Object:  StoredProcedure [dbo].[sp_GetLoanStatus] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_GetLoanStatus]
    @Customer_ID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT la.App_ID, la.Requested_Amount, la.No_Of_Months, la.App_status, la.Created_At, ra.Total_Score AS Risk_Score, ra.ML_Model, ra.Assessed_At
    FROM dbo.Loan_Application la LEFT JOIN dbo.Risk_Assessment ra ON ra.Assess_ID = la.Assessment_ID
    WHERE la.Customer_ID = @Customer_ID ORDER BY la.Created_At DESC;

    SELECT lc.Contract_ID, lc.App_ID, lc.Acc_ID, lc.Start_Date, lc.End_Date, lc.Approved_Amount, lc.contract_status, lc.interest_rate, rps.Schedule_ID, rps.Due_Date, rps.Principal_Amount, rps.Interest_Amount, rps.install_status
    FROM dbo.Loan_Contract lc INNER JOIN dbo.Loan_Application la ON la.App_ID = lc.App_ID LEFT JOIN dbo.Re_Payment_Schedule rps ON rps.Contract_ID = lc.Contract_ID
    WHERE la.Customer_ID = @Customer_ID ORDER BY lc.Start_Date DESC, rps.Due_Date ASC;
END;
GO

/* Object:  StoredProcedure [dbo].[sp_GetMerchantInfo] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_GetMerchantInfo]
    @Owner_ID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT m.Owner_ID, m.Merchant_Name, m.Category, m.merch_lat, m.merch_long, a.Acc_ID, a.Balance, a.Currency, a.Acc_status
    FROM dbo.Merchants m INNER JOIN dbo.AccountOwner ao ON ao.Owner_ID = m.Owner_ID INNER JOIN dbo.Account a ON a.Owner_ID = ao.Owner_ID
    WHERE m.Owner_ID = @Owner_ID;

    SELECT th.Trans_Type, COUNT(*) AS Trans_Count, SUM(te.Amount) AS Total_Amount, AVG(te.Amount) AS Avg_Amount, MAX(te.Amount) AS Max_Amount
    FROM dbo.Transactions_Header th INNER JOIN dbo.Transaction_Entry te ON te.Trans_ID = th.Trans_ID INNER JOIN dbo.Account a ON a.Acc_ID = te.Acc_ID
    WHERE a.Owner_ID = @Owner_ID AND th.Trans_DateTime >= DATEADD(DAY, -30, GETDATE())
    GROUP BY th.Trans_Type;
END;
GO

/* Object:  StoredProcedure [dbo].[sp_Customer360Profile] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_Customer360Profile]
(
    @CustomerID INT,
    @AsOfDate DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    IF @AsOfDate IS NULL SET @AsOfDate = GETDATE();

    SELECT c.Owner_ID, c.FName + ' ' + c.LName AS FullName, c.Email, c.Phone, c.National_ID, c.Gender, c.DOB, c.Employment_Status, c.Job_Title, c.Monthly_Income, c.City, c.State, c.Zip, a.Acc_ID, a.Acc_Type, a.Currency, a.Balance, a.Acc_Status, fh.Late_Payment_Count, fh.Missed_Payment_Count, fh.Avg_Payment_Delay_Days, ul.Username, ul.Last_Login, ul.Is_Active
    FROM Customer c
    LEFT JOIN Account a ON a.Owner_ID = c.Owner_ID
    LEFT JOIN Financial_History fh ON fh.Customer_ID = c.Owner_ID
    LEFT JOIN User_Login ul ON ul.Customer_ID = c.Owner_ID
    WHERE c.Owner_ID = @CustomerID;
END
GO

/* Object:  StoredProcedure [dbo].[sp_GetTransactionHistory] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_GetTransactionHistory]
    @Acc_ID INT,
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @DateFrom DATETIME = NULL,
    @DateTo DATETIME = NULL,
    @Trans_Type NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT th.Trans_ID, th.Trans_Type, th.Trans_Status, th.Trans_DateTime, ta.IP_Address, ta.Device_ID, th.Card_Attempt_ID, te.Entry_ID, te.Entry_Type, te.Amount, ISNULL(fa.Is_Fraud, 0) AS Is_Fraud, fa.Total_Score AS Fraud_Score
    FROM dbo.Transactions_Header th
    INNER JOIN dbo.Transaction_Entry te ON te.Trans_ID = th.Trans_ID
    INNER JOIN dbo.Transactions_Audit ta ON ta.Trans_ID = th.Trans_ID
    LEFT JOIN dbo.Fraud_Assessment fa ON fa.Trans_ID = th.Trans_ID
    WHERE te.Acc_ID = @Acc_ID AND (@DateFrom IS NULL OR th.Trans_DateTime >= @DateFrom) AND (@DateTo IS NULL OR th.Trans_DateTime <= @DateTo) AND (@Trans_Type IS NULL OR th.Trans_Type = @Trans_Type)
    ORDER BY th.Trans_DateTime DESC OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT COUNT(*) AS Total_Records FROM dbo.Transactions_Header th INNER JOIN dbo.Transaction_Entry te ON te.Trans_ID = th.Trans_ID
    WHERE te.Acc_ID = @Acc_ID AND (@DateFrom IS NULL OR th.Trans_DateTime >= @DateFrom) AND (@DateTo IS NULL OR th.Trans_DateTime <= @DateTo) AND (@Trans_Type IS NULL OR th.Trans_Type = @Trans_Type);
END;
GO