-- =============================================================================
-- PART 1: ANALYTICAL & REPORTING PROCEDURES (rpt_)
-- =============================================================================

/* Object:  StoredProcedure [dbo].[rpt_CardAttempt_GeoCluster] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[rpt_CardAttempt_GeoCluster]
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ca.Card_ID,
        ca.ATM_ID,
        ca.Location_Lat,
        ca.Location_Lon,
        ca.Attempt_Time,

        COUNT(*) OVER (
            PARTITION BY ca.ATM_ID
        ) AS Failures_At_This_ATM,

        COUNT(*) OVER (
            PARTITION BY ca.Card_ID
        ) AS Failures_On_This_Card

    FROM Card_Attempt ca

    WHERE
        ca.Is_Success = 0
        AND ca.Location_Lat IS NOT NULL
        AND ca.Location_Lon IS NOT NULL

        AND (@StartDate IS NULL OR CAST(ca.Attempt_Time AS DATE) >= @StartDate)
        AND (@EndDate   IS NULL OR CAST(ca.Attempt_Time AS DATE) <= @EndDate)

    ORDER BY Failures_At_This_ATM DESC;
END
GO

/* Object:  StoredProcedure [dbo].[rpt_FailedLogin_SpikeSummary] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[rpt_FailedLogin_SpikeSummary]
(
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH LoginFailures AS
    (
        SELECT
            c.Owner_ID AS Customer_ID,
            c.FName + ' ' + c.LName AS Full_Name,
            c.Email,
            la.Attempt_Time,
            la.Device_ID,

            (
                SELECT COUNT(*)
                FROM Login_Attempt la2
                INNER JOIN User_Login ul2 ON la2.login_ID = ul2.login_ID
                WHERE
                    ul2.Customer_ID = c.Owner_ID
                    AND la2.Is_Success = 0
                    AND la2.Attempt_Time BETWEEN DATEADD(HOUR, -24, la.Attempt_Time) AND la.Attempt_Time
            ) AS Failures_Last_24hrs

        FROM Login_Attempt la
        INNER JOIN User_Login ul ON la.login_ID = ul.login_ID
        INNER JOIN Customer c ON ul.Customer_ID = c.Owner_ID
        WHERE
            la.Is_Success = 0
            AND (@StartDate IS NULL OR CAST(la.Attempt_Time AS DATE) >= @StartDate)
            AND (@EndDate   IS NULL OR CAST(la.Attempt_Time AS DATE) <= @EndDate)
    )
    SELECT
        Customer_ID,
        Full_Name,
        Email,
        MAX(Failures_Last_24hrs) AS Peak_Failures_24hrs,
        MAX(Attempt_Time) AS Last_Attempt_Time,
        CASE
            WHEN MAX(Failures_Last_24hrs) >= 10 THEN 'Critical'
            WHEN MAX(Failures_Last_24hrs) >= 5  THEN 'High'
            ELSE 'Watch'
        END AS Alert_Level
    FROM LoginFailures
    WHERE Failures_Last_24hrs >= 1
    GROUP BY
        Customer_ID,
        Full_Name,
        Email
    ORDER BY Peak_Failures_24hrs DESC;
END
GO

/* Object:  StoredProcedure [dbo].[rpt_FailedLoginCardAttempt] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description: Reports failed login and card attempts
--              with optional date, customer, and type filtering.
-- =============================================
CREATE PROCEDURE [dbo].[rpt_FailedLoginCardAttempt]
    @StartDate      DATE         = NULL,
    @EndDate        DATE         = NULL,
    @Customer_ID    INT          = NULL,
    @FailureType    NVARCHAR(20) = NULL   -- 'LOGIN', 'CARD', or NULL for both
AS
BEGIN
    SET NOCOUNT ON;

    -- SECTION 1: Failed Login Attempts
    SELECT
        'LOGIN'                             AS Failure_Type,
        la.Attempt_ID,
        la.Attempt_Time,
        la.Device_ID,
        ul.login_ID,
        ul.Username,
        ul.Is_Active                        AS Account_Is_Active,
        ul.Last_Login,
        c.Owner_ID,
        c.FName + ' ' + c.LName            AS Full_Name,
        c.Email,
        c.Phone,
        c.City,
        c.State,
        NULL                                AS Card_ID,
        NULL                                AS ATM_ID,
        NULL                                AS Location_Lat,
        NULL                                AS Location_Lon,
        COUNT(*) OVER (PARTITION BY ul.Customer_ID) AS Total_Failures_This_Customer
    FROM Login_Attempt la
    INNER JOIN User_Login ul ON la.login_ID = ul.login_ID
    INNER JOIN Customer c ON ul.Customer_ID = c.Owner_ID
    WHERE
        la.Is_Success = 0
        AND (@StartDate   IS NULL OR CAST(la.Attempt_Time AS DATE) >= @StartDate)
        AND (@EndDate     IS NULL OR CAST(la.Attempt_Time AS DATE) <= @EndDate)
        AND (@Customer_ID IS NULL OR c.Owner_ID = @Customer_ID)
        AND (@FailureType IS NULL OR @FailureType = 'LOGIN')

    UNION ALL

    -- SECTION 2: Failed Card Attempts
    SELECT
        'CARD'                              AS Failure_Type,
        ca.Attempt_ID,
        ca.Attempt_Time,
        NULL                                AS Device_ID,
        NULL                                AS login_ID,
        NULL                                AS Username,
        NULL                                AS Account_Is_Active,
        NULL                                AS Last_Login,
        NULL                                AS Customer_ID,
        NULL                                AS Full_Name,
        NULL                                AS Email,
        NULL                                AS Phone,
        NULL                                AS City,
        NULL                                AS State,
        ca.Card_ID,
        ca.ATM_ID,
        ca.Location_Lat,
        ca.Location_Lon,
        COUNT(*) OVER (PARTITION BY ca.Card_ID) AS Total_Failures_This_Customer
    FROM Card_Attempt ca
    WHERE
        ca.Is_Success = 0                   
        AND (@StartDate   IS NULL OR CAST(ca.Attempt_Time AS DATE) >= @StartDate)
        AND (@EndDate     IS NULL OR CAST(ca.Attempt_Time AS DATE) <= @EndDate)
        AND (@Customer_ID IS NULL)          
        AND (@FailureType IS NULL OR @FailureType = 'CARD')

    ORDER BY Attempt_Time DESC;
END
GO

/* Object:  StoredProcedure [dbo].[rpt_RiskAssessment_LoanApproval] */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[rpt_RiskAssessment_LoanApproval]
(
    @StartDate   DATE = NULL,
    @EndDate     DATE = NULL,
    @ML_Model    NVARCHAR(100) = NULL,
    @App_Status  NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.Owner_ID,
        c.FName + ' ' + c.LName AS FullName,
        c.Employment_Status,
        c.Monthly_Income,
        c.Monthly_Liability,
        a.App_ID,
        a.Requested_Amount,
        a.No_Of_Months,
        a.App_status,
        a.Created_At AS Application_Date,
        r.Total_Score,
        r.ML_Model,
        r.Assessed_At,
        CASE
            WHEN r.Total_Score < 40 THEN 'High Risk'
            WHEN r.Total_Score BETWEEN 40 AND 69 THEN 'Medium Risk'
            WHEN r.Total_Score >= 70 THEN 'Low Risk'
            ELSE 'Unscored'
        END AS Risk_Band,
        fh.Late_Payment_Count,
        fh.Missed_Payment_Count,
        fh.Avg_Payment_Delay_Days,
        lc.Contract_ID,
        lc.Approved_Amount,
        lc.Interest_Rate,
        lc.Contract_Status
    FROM Loan_Application a
    LEFT JOIN Risk_Assessment r ON a.Assessment_ID = r.Assess_ID
    LEFT JOIN Customer c ON a.Customer_ID = c.Owner_ID
    LEFT JOIN Financial_History fh ON a.Customer_ID = fh.Customer_ID
    LEFT JOIN Loan_Contract lc ON a.App_ID = lc.App_ID
    WHERE
        (@StartDate IS NULL OR CAST(a.Created_At AS DATE) >= @StartDate)
        AND (@EndDate IS NULL OR CAST(a.Created_At AS DATE) <= @EndDate)
        AND (@ML_Model IS NULL OR @ML_Model = '' OR r.ML_Model = @ML_Model)
        AND (@App_Status IS NULL OR @App_Status = '' OR a.App_status = @App_Status)
    ORDER BY r.Total_Score DESC;
END
GO

