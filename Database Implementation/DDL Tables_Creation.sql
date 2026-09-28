/******************************************************************
Project : FinTech Platform
******************************************************************/

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ==========================================
-- SECTION 1: TABLE CREATIONS
-- ==========================================

-- 1. AccountOwner
CREATE TABLE [dbo].[AccountOwner](
    [Owner_ID] [int] IDENTITY(1,1) NOT NULL,
    [Owner_Type] [varchar](20) NOT NULL,
    CONSTRAINT [PK_AccountOwner] PRIMARY KEY CLUSTERED ([Owner_ID] ASC),
    CONSTRAINT [CHK_AccountOwner_Type] CHECK ([Owner_Type] IN ('Bank', 'Merchant', 'Customer'))
) ON [PRIMARY];
GO

-- 2. Bank
CREATE TABLE [dbo].[Bank](
    [Owner_ID] [int] NOT NULL,
    [Bank_Name] [nvarchar](200) NOT NULL,
    [Country] [nvarchar](100) NULL,
    CONSTRAINT [PK_Bank] PRIMARY KEY CLUSTERED ([Owner_ID] ASC)
) ON [PRIMARY];
GO

-- 3. Merchants
CREATE TABLE [dbo].[Merchants](
    [Owner_ID] [int] NOT NULL,
    [Merchant_Name] [nvarchar](200) NULL,
    [Category] [nvarchar](100) NULL,
    [merch_lat] [decimal](9, 6) NULL,
    [merch_long] [decimal](9, 6) NULL,
    CONSTRAINT [PK_Merchant] PRIMARY KEY CLUSTERED ([Owner_ID] ASC)
) ON [PRIMARY];
GO

-- 4. Customer
CREATE TABLE [dbo].[Customer](
    [Owner_ID] [int] IDENTITY(1000,1) NOT NULL,
    [FName] [nvarchar](50) NOT NULL,
    [LName] [nvarchar](50) NOT NULL,
    [Gender] [varchar](1) NULL,
    [National_ID] [nvarchar](14) NOT NULL,
    [Email] [nvarchar](50) NULL,
    [Phone] [nvarchar](11) NULL,
    [Education_Level] [nvarchar](50) NULL,
    [Device_ID] [nvarchar](50) NULL,
    [Cust_Loc_lat] [decimal](9, 6) NULL,
    [Cust_Loc_lon] [decimal](9, 6) NULL,
    [Street] [nvarchar](50) NULL,
    [City] [nvarchar](25) NULL,
    [State] [nvarchar](10) NULL,
    [Zip] [nvarchar](10) NULL,
    [Family_Members] [tinyint] NULL,
    [Family_Status] [varchar](15) NULL,
    [Home_Ownership] [varchar](15) NULL,
    [FLAG_OWN_CAR] [varchar](1) NULL,
    [Monthly_Income] [decimal](18, 2) NULL,
    [Monthly_Liability] [decimal](18, 2) NULL,
    [Job_Title] [nvarchar](max) NULL,
    [Employment_Status] [nvarchar](50) NULL,
    [Year_Of_Experience] [tinyint] NULL,
    [Employer_Name] [nvarchar](50) NULL,
    [DOB] [date] NULL,
    [Last_Updated] [date] NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_Customer] PRIMARY KEY CLUSTERED ([Owner_ID] ASC),
    CONSTRAINT [UQ_Customer_Email] UNIQUE NONCLUSTERED ([Email] ASC),
    CONSTRAINT [UQ_Customer_National_ID] UNIQUE NONCLUSTERED ([National_ID] ASC)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
GO

-- 5. User_Login
CREATE TABLE [dbo].[User_Login](
    [login_ID] [int] IDENTITY(1,1) NOT NULL,
    [Customer_ID] [int] NOT NULL,
    [Username] [nvarchar](100) NOT NULL,
    [Password_Hash] [nvarchar](256) NOT NULL,
    [Last_Login] [datetime2](7) NULL,
    [Is_Active] [bit] NOT NULL DEFAULT ((1)),
    [Created_At] [datetime2](7) NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_User_Login] PRIMARY KEY CLUSTERED ([login_ID] ASC),
    CONSTRAINT [UQ_UserLogin_Customer] UNIQUE NONCLUSTERED ([Customer_ID] ASC),
    CONSTRAINT [UQ_Username] UNIQUE NONCLUSTERED ([Username] ASC)
) ON [PRIMARY];
GO

-- 6. Login_Attempt
CREATE TABLE [dbo].[Login_Attempt](
    [Attempt_ID] [int] IDENTITY(1,1) NOT NULL,
    [login_ID] [int] NOT NULL,
    [Attempt_Time] [datetime2](7) NOT NULL DEFAULT (getdate()),
    [Is_Success] [bit] NOT NULL DEFAULT ((0)),
    [Device_ID] [nvarchar](100) NULL,
    CONSTRAINT [PK_Login_Attempt] PRIMARY KEY CLUSTERED ([Attempt_ID] ASC)
) ON [PRIMARY];
GO

-- 7. Account
CREATE TABLE [dbo].[Account](
    [Acc_ID] [int] IDENTITY(1,1) NOT NULL,
    [Owner_ID] [int] NOT NULL,
    [Acc_Type] [nvarchar](50) NOT NULL DEFAULT ('Savings'),
    [Currency] [nchar](3) NOT NULL DEFAULT ('USD'),
    [Balance] [decimal](18, 2) NOT NULL DEFAULT ((0.00)),
    [Acc_status] [nvarchar](20) NOT NULL DEFAULT ('Pending_Verification'),
    [Created_At] [datetime2](7) NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_Account] PRIMARY KEY CLUSTERED ([Acc_ID] ASC),
    CONSTRAINT [CHK_Acc_Type] CHECK ([Acc_Type] IN ('Wallet', 'Credit', 'Savings', 'Business')),
    CONSTRAINT [CHK_Acc_Status] CHECK ([Acc_status] IN ('Suspended', 'Closed', 'Frozen', 'Under_Review', 'Pending_Verification', 'Active'))
) ON [PRIMARY];
GO

-- 8. Card
CREATE TABLE [dbo].[Card](
    [Card_ID] [int] IDENTITY(1,1) NOT NULL,
    [Acc_ID] [int] NOT NULL,
    [Card_Number] [nvarchar](16) NOT NULL,
    [CVV] [nchar](3) NOT NULL,
    [Expiry_Date] [date] NOT NULL,
    [Card_Type] [nvarchar](10) NOT NULL DEFAULT ('Debit'),
    [Is_Blocked] [bit] NOT NULL DEFAULT ((0)),
    [Credit_Limit] [decimal](18, 2) NULL,
    [Available_Limit] [decimal](18, 2) NULL,
    CONSTRAINT [PK_Card] PRIMARY KEY CLUSTERED ([Card_ID] ASC),
    CONSTRAINT [UQ_Card_Number] UNIQUE NONCLUSTERED ([Card_Number] ASC),
    CONSTRAINT [CHK_Card_Type] CHECK ([Card_Type] IN ('Credit', 'Debit'))
) ON [PRIMARY];
GO

-- 9. Card_Attempt
CREATE TABLE [dbo].[Card_Attempt](
    [Attempt_ID] [int] IDENTITY(1,1) NOT NULL,
    [Card_ID] [int] NOT NULL,
    [Attempt_Time] [datetime2](7) NOT NULL DEFAULT (getdate()),
    [Is_Success] [bit] NOT NULL DEFAULT ((0)),
    [ATM_ID] [nvarchar](50) NULL,
    [Location_Lat] [decimal](9, 6) NULL,
    [Location_Lon] [decimal](9, 6) NULL,
    CONSTRAINT [PK_Card_Attempt] PRIMARY KEY CLUSTERED ([Attempt_ID] ASC)
) ON [PRIMARY];
GO

-- 10. Transactions_Header
CREATE TABLE [dbo].[Transactions_Header](
    [Trans_ID] [int] IDENTITY(1,1) NOT NULL,
    [Trans_Type] [nvarchar](50) NOT NULL,
    [Trans_Status] [nvarchar](20) NOT NULL DEFAULT ('Pending'),
    [Card_Attempt_ID] [int] NULL,
    [Trans_DateTime] [datetime2](7) NOT NULL DEFAULT (getdate()),
    [Unix_Time] AS (datediff_big(second,'1970-01-01',[Trans_DateTime])),
    CONSTRAINT [PK_Transactions_Header] PRIMARY KEY CLUSTERED ([Trans_ID] ASC),
    CONSTRAINT [CHK_Trans_Type] CHECK ([Trans_Type] IN ('TRANSFER', 'PURCHASE', 'WITHDRAWAL', 'DEPOSIT')),
    CONSTRAINT [CHK_Trans_Status] CHECK ([Trans_Status] IN ('Reversed', 'Failed', 'Completed', 'Pending'))
) ON [PRIMARY];
GO

-- 11. Transaction_Entry
CREATE TABLE [dbo].[Transaction_Entry](
    [Entry_ID] [int] IDENTITY(1,1) NOT NULL,
    [Trans_ID] [int] NOT NULL,
    [Acc_ID] [int] NOT NULL,
    [Entry_Type] [varchar](6) NOT NULL,
    [Amount] [decimal](18, 2) NOT NULL,
    CONSTRAINT [PK_Transaction_Entry] PRIMARY KEY CLUSTERED ([Entry_ID] ASC),
    CONSTRAINT [CHK_Entry_Amount_Positive] CHECK ([Amount] > (0)),
    CONSTRAINT [CHK_Entry_Type] CHECK ([Entry_Type] IN ('CREDIT', 'DEBIT'))
) ON [PRIMARY];
GO

-- 12. Transactions_Audit
CREATE TABLE [dbo].[Transactions_Audit](
    [Audit_ID] [int] IDENTITY(1,1) NOT NULL,
    [Trans_ID] [int] NOT NULL,
    [Channel] [nvarchar](20) NOT NULL,
    [Trans_Loc] [geography] NULL,
    [IP_Address] [nvarchar](45) NULL,
    [Device_ID] [nvarchar](100) NULL,
    [Created_At] [datetime2](7) NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_Transactions_Audit] PRIMARY KEY CLUSTERED ([Audit_ID] ASC),
    CONSTRAINT [UQ_Audit_Trans] UNIQUE NONCLUSTERED ([Trans_ID] ASC),
    CONSTRAINT [CHK_Audit_Channel] CHECK ([Channel] IN ('API', 'WEB', 'POS', 'APP', 'ATM'))
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
GO

-- 13. Transaction_Rules
CREATE TABLE [dbo].[Transaction_Rules](
    [Rule_ID] [int] IDENTITY(1,1) NOT NULL,
    [Rule_Name] [nvarchar](100) NOT NULL,
    [Rule_Description] [nvarchar](500) NULL,
    [Rule_Score] [decimal](5, 2) NOT NULL,
    [Threshold] [decimal](18, 2) NOT NULL,
    CONSTRAINT [PK_Transaction_Rules] PRIMARY KEY CLUSTERED ([Rule_ID] ASC)
) ON [PRIMARY];
GO

-- 14. Fraud_Alert
CREATE TABLE [dbo].[Fraud_Alert](
    [Alert_ID] [int] IDENTITY(1,1) NOT NULL,
    [Trans_ID] [int] NOT NULL,
    [Rule_ID] [int] NOT NULL,
    [Alert_Score] [decimal](5, 2) NOT NULL,
    [Triggered_At] [datetime2](7) NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_Fraud_Alert] PRIMARY KEY CLUSTERED ([Alert_ID] ASC),
    CONSTRAINT [UQ_Alert_Trans_Rule] UNIQUE NONCLUSTERED ([Trans_ID] ASC, [Rule_ID] ASC)
) ON [PRIMARY];
GO

-- 15. Fraud_Assessment
CREATE TABLE [dbo].[Fraud_Assessment](
    [Assess_ID] [int] IDENTITY(1,1) NOT NULL,
    [Trans_ID] [int] NOT NULL,
    [Total_Score] [decimal](6, 2) NOT NULL,
    [Risk_Level] [nvarchar](10) NOT NULL,
    [ML_Model] [nvarchar](30) NULL,
    [Is_Fraud] [bit] NOT NULL DEFAULT ((0)),
    [Assessed_At] [datetime2](7) NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_Fraud_Assessment] PRIMARY KEY CLUSTERED ([Assess_ID] ASC),
    CONSTRAINT [UQ_Assessment_Trans] UNIQUE NONCLUSTERED ([Trans_ID] ASC),
    CONSTRAINT [CHK_Risk_Level] CHECK ([Risk_Level] IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW'))
) ON [PRIMARY];
GO

-- 16. Financial_History
CREATE TABLE [dbo].[Financial_History](
    [History_ID] [int] IDENTITY(1,1) NOT NULL,
    [Customer_ID] [int] NOT NULL,
    [Late_Payment_Count] [int] NULL DEFAULT ((0)),
    [Missed_Payment_Count] [int] NULL DEFAULT ((0)),
    [Avg_Payment_Delay_Days] [decimal](6, 2) NULL DEFAULT ((0.00)),
    [Last_Update] [datetime2](7) NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_Financial_History] PRIMARY KEY CLUSTERED ([History_ID] ASC),
    CONSTRAINT [UQ_FinHistory_Customer] UNIQUE NONCLUSTERED ([Customer_ID] ASC)
) ON [PRIMARY];
GO

-- 17. Risk_Assessment
CREATE TABLE [dbo].[Risk_Assessment](
    [Assess_ID] [int] IDENTITY(1,1) NOT NULL,
    [Total_Score] [decimal](5, 2) NOT NULL,
    [Assessed_At] [datetime2](7) NOT NULL DEFAULT (getdate()),
    [ML_Model] [nvarchar](20) NULL,
    CONSTRAINT [PK_Risk_Assessment] PRIMARY KEY CLUSTERED ([Assess_ID] ASC)
) ON [PRIMARY];
GO

-- 18. Loan_Application
CREATE TABLE [dbo].[Loan_Application](
    [App_ID] [int] IDENTITY(1,1) NOT NULL,
    [Customer_ID] [int] NOT NULL,
    [Assessment_ID] [int] NULL,
    [Requested_Amount] [decimal](18, 2) NOT NULL,
    [No_Of_Months] [smallint] NOT NULL,
    [App_status] [nvarchar](30) NOT NULL DEFAULT ('Pending'),
    [Created_At] [datetime] NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_Loan_Application] PRIMARY KEY CLUSTERED ([App_ID] ASC)
) ON [PRIMARY];
GO

-- 19. Loan_Contract
CREATE TABLE [dbo].[Loan_Contract](
    [Contract_ID] [int] IDENTITY(1,1) NOT NULL,
    [App_ID] [int] NOT NULL,
    [Acc_ID] [int] NOT NULL,
    [Start_Date] [date] NOT NULL,
    [End_Date] [date] NOT NULL,
    [Approved_Amount] [decimal](18, 2) NOT NULL,
    [contract_status] [nvarchar](30) NOT NULL DEFAULT ('Active'),
    [interest_rate] [decimal](18, 2) NULL,
    CONSTRAINT [PK_Loan_Contract] PRIMARY KEY CLUSTERED ([Contract_ID] ASC),
    CONSTRAINT [UQ_Contract_Application] UNIQUE NONCLUSTERED ([App_ID] ASC)
) ON [PRIMARY];
GO

-- 20. Re_Payment_Schedule
CREATE TABLE [dbo].[Re_Payment_Schedule](
    [Schedule_ID] [int] IDENTITY(1,1) NOT NULL,
    [Contract_ID] [int] NOT NULL,
    [Due_Date] [date] NOT NULL,
    [Principal_Amount] [decimal](18, 2) NOT NULL,
    [Interest_Amount] [decimal](18, 2) NOT NULL,
    [install_status] [nvarchar](20) NOT NULL DEFAULT ('Upcoming'),
    CONSTRAINT [PK_Re_Payment_Schedule] PRIMARY KEY CLUSTERED ([Schedule_ID] ASC),
    CONSTRAINT [CHK_Install_Status] CHECK ([install_status] IN ('Overdue', 'Paid', 'Upcoming'))
) ON [PRIMARY];
GO


-- ==========================================
-- SECTION 2: FOREIGN KEY CONSTRAINTS
-- ==========================================

-- Bank & Merchant Links
ALTER TABLE [dbo].[Bank] WITH CHECK ADD CONSTRAINT [FK_Bank_Owner] FOREIGN KEY([Owner_ID]) REFERENCES [dbo].[AccountOwner] ([Owner_ID]);
ALTER TABLE [dbo].[Merchants] WITH CHECK ADD CONSTRAINT [FK_Merchant_Owner] FOREIGN KEY([Owner_ID]) REFERENCES [dbo].[AccountOwner] ([Owner_ID]);

-- Customer & Auth Links
ALTER TABLE [dbo].[Customer] WITH CHECK ADD CONSTRAINT [FK_Customer_AccountOwner] FOREIGN KEY([Owner_ID]) REFERENCES [dbo].[AccountOwner] ([Owner_ID]);
ALTER TABLE [dbo].[User_Login] WITH CHECK ADD CONSTRAINT [FK_User_Login_Customer] FOREIGN KEY([Customer_ID]) REFERENCES [dbo].[Customer] ([Owner_ID]);
ALTER TABLE [dbo].[Login_Attempt] WITH CHECK ADD CONSTRAINT [FK_LoginAttempt_UserLogin] FOREIGN KEY([login_ID]) REFERENCES [dbo].[User_Login] ([login_ID]) ON DELETE CASCADE;
ALTER TABLE [dbo].[Financial_History] WITH CHECK ADD CONSTRAINT [FK_Financial_History_Customer] FOREIGN KEY([Customer_ID]) REFERENCES [dbo].[Customer] ([Owner_ID]) ON DELETE CASCADE;

-- Account & Card Links
ALTER TABLE [dbo].[Account] WITH CHECK ADD CONSTRAINT [FK_Account_AccountOwner] FOREIGN KEY([Owner_ID]) REFERENCES [dbo].[AccountOwner] ([Owner_ID]);
ALTER TABLE [dbo].[Card] WITH CHECK ADD CONSTRAINT [FK_Card_Account] FOREIGN KEY([Acc_ID]) REFERENCES [dbo].[Account] ([Acc_ID]) ON DELETE CASCADE;
ALTER TABLE [dbo].[Card_Attempt] WITH CHECK ADD CONSTRAINT [FK_CardAttempt_Card] FOREIGN KEY([Card_ID]) REFERENCES [dbo].[Card] ([Card_ID]) ON DELETE CASCADE;

-- Transactions Engine Links
ALTER TABLE [dbo].[Transactions_Header] WITH CHECK ADD CONSTRAINT [FK_Transaction_CardAttempt] FOREIGN KEY([Card_Attempt_ID]) REFERENCES [dbo].[Card_Attempt] ([Attempt_ID]) ON DELETE CASCADE;
ALTER TABLE [dbo].[Transaction_Entry] WITH CHECK ADD CONSTRAINT [FK_Entry_Account] FOREIGN KEY([Acc_ID]) REFERENCES [dbo].[Account] ([Acc_ID]);
ALTER TABLE [dbo].[Transaction_Entry] WITH CHECK ADD CONSTRAINT [FK_Entry_Header] FOREIGN KEY([Trans_ID]) REFERENCES [dbo].[Transactions_Header] ([Trans_ID]) ON DELETE CASCADE;
ALTER TABLE [dbo].[Transactions_Audit] WITH CHECK ADD CONSTRAINT [FK_Audit_Header] FOREIGN KEY([Trans_ID]) REFERENCES [dbo].[Transactions_Header] ([Trans_ID]) ON DELETE CASCADE;

-- Fraud Check Links
ALTER TABLE [dbo].[Fraud_Alert] WITH CHECK ADD CONSTRAINT [FK_Alert_Header] FOREIGN KEY([Trans_ID]) REFERENCES [dbo].[Transactions_Header] ([Trans_ID]) ON DELETE CASCADE;
ALTER TABLE [dbo].[Fraud_Alert] WITH CHECK ADD CONSTRAINT [FK_Alert_Rule] FOREIGN KEY([Rule_ID]) REFERENCES [dbo].[Transaction_Rules] ([Rule_ID]);
ALTER TABLE [dbo].[Fraud_Assessment] WITH CHECK ADD CONSTRAINT [FK_Assessment_Header] FOREIGN KEY([Trans_ID]) REFERENCES [dbo].[Transactions_Header] ([Trans_ID]);

-- Loans Engine Links
ALTER TABLE [dbo].[Loan_Application] WITH CHECK ADD CONSTRAINT [FK_Loan_Application_Customer] FOREIGN KEY([Customer_ID]) REFERENCES [dbo].[Customer] ([Owner_ID]);
ALTER TABLE [dbo].[Loan_Application] WITH CHECK ADD CONSTRAINT [FK_LoanApp_RiskAssessment] FOREIGN KEY([Assessment_ID]) REFERENCES [dbo].[Risk_Assessment] ([Assess_ID]) ON DELETE SET NULL;
ALTER TABLE [dbo].[Loan_Contract] WITH CHECK ADD CONSTRAINT [FK_LoanContract_Account] FOREIGN KEY([Acc_ID]) REFERENCES [dbo].[Account] ([Acc_ID]);
ALTER TABLE [dbo].[Loan_Contract] WITH CHECK ADD CONSTRAINT [FK_LoanContract_Application] FOREIGN KEY([App_ID]) REFERENCES [dbo].[Loan_Application] ([App_ID]);
ALTER TABLE [dbo].[Re_Payment_Schedule] WITH CHECK ADD CONSTRAINT [FK_Re_Payment_Schedule_Loan_Contract] FOREIGN KEY([Contract_ID]) REFERENCES [dbo].[Loan_Contract] ([Contract_ID]);
GO

-- Enable Checked Constraints
ALTER TABLE [dbo].[Bank] CHECK CONSTRAINT [FK_Bank_Owner];
ALTER TABLE [dbo].[Merchants] CHECK CONSTRAINT [FK_Merchant_Owner];
ALTER TABLE [dbo].[Customer] CHECK CONSTRAINT [FK_Customer_AccountOwner];
ALTER TABLE [dbo].[User_Login] CHECK CONSTRAINT [FK_User_Login_Customer];
ALTER TABLE [dbo].[Login_Attempt] CHECK CONSTRAINT [FK_LoginAttempt_UserLogin];
ALTER TABLE [dbo].[Financial_History] CHECK CONSTRAINT [FK_Financial_History_Customer];
ALTER TABLE [dbo].[Account] CHECK CONSTRAINT [FK_Account_AccountOwner];
ALTER TABLE [dbo].[Card] CHECK CONSTRAINT [FK_Card_Account];
ALTER TABLE [dbo].[Card_Attempt] CHECK CONSTRAINT [FK_CardAttempt_Card];
ALTER TABLE [dbo].[Transactions_Header] CHECK CONSTRAINT [FK_Transaction_CardAttempt];
ALTER TABLE [dbo].[Transaction_Entry] CHECK CONSTRAINT [FK_Entry_Account];
ALTER TABLE [dbo].[Transaction_Entry] CHECK CONSTRAINT [FK_Entry_Header];
ALTER TABLE [dbo].[Transactions_Audit] CHECK CONSTRAINT [FK_Audit_Header];
ALTER TABLE [dbo].[Fraud_Alert] CHECK CONSTRAINT [FK_Alert_Header];
ALTER TABLE [dbo].[Fraud_Alert] CHECK CONSTRAINT [FK_Alert_Rule];
ALTER TABLE [dbo].[Fraud_Assessment] CHECK CONSTRAINT [FK_Assessment_Header];
ALTER TABLE [dbo].[Loan_Application] CHECK CONSTRAINT [FK_Loan_Application_Customer];
ALTER TABLE [dbo].[Loan_Application] CHECK CONSTRAINT [FK_LoanApp_RiskAssessment];
ALTER TABLE [dbo].[Loan_Contract] CHECK CONSTRAINT [FK_LoanContract_Account];
ALTER TABLE [dbo].[Loan_Contract] CHECK CONSTRAINT [FK_LoanContract_Application];
ALTER TABLE [dbo].[Re_Payment_Schedule] CHECK CONSTRAINT [FK_Re_Payment_Schedule_Loan_Contract];
GO


-- ==========================================
-- SECTION 3: NAMED CUSTOM CHECK CONSTRAINTS
-- ==========================================

ALTER TABLE [dbo].[Customer] WITH CHECK ADD CONSTRAINT [CK_Customer_Employment_Status] CHECK ([Employment_Status] IN ('Student', 'Retired', 'Unemployed', 'Self-Employed', 'Part-Time', 'Full-Time'));
ALTER TABLE [dbo].[Customer] WITH CHECK ADD CONSTRAINT [CK_Customer_Home_Ownership] CHECK ([Home_Ownership] IN ('Provided by Emp', 'Living with Parents', 'Rented', 'Owned'));
ALTER TABLE [dbo].[Loan_Application] WITH CHECK ADD CONSTRAINT [CK_Loan_Application_Status] CHECK ([App_status] IN ('Rejected', 'Approved', 'Pending'));
ALTER TABLE [dbo].[Loan_Contract] WITH CHECK ADD CONSTRAINT [CK_Loan_Contract_Status] CHECK ([contract_status] IN ('Defaulted', 'Fully Paid', 'Active'));
GO

ALTER TABLE [dbo].[Customer] CHECK CONSTRAINT [CK_Customer_Employment_Status];
ALTER TABLE [dbo].[Customer] CHECK CONSTRAINT [CK_Customer_Home_Ownership];
ALTER TABLE [dbo].[Loan_Application] CHECK CONSTRAINT [CK_Loan_Application_Status];
ALTER TABLE [dbo].[Loan_Contract] CHECK CONSTRAINT [CK_Loan_Contract_Status];
GO