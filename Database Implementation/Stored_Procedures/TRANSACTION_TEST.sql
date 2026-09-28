-- ── Step 1: Check Account ──────────────────────────────────────────────────────
SELECT Acc_ID, Owner_ID, Balance, Acc_status
FROM dbo.Account
WHERE Acc_ID IN (2,5,101);

-- ── Step 2: Test Deposit ──────────────────────────────────────────────────────
EXEC dbo.sp_Deposit
    @AccID     = 2,      
    @Amount    = 50.00,
    @Channel   = 'APP',
    @IPAddress = '192.168.1.1';

EXEC dbo.sp_Deposit
    @AccID     = 2,      
    @Amount    = -50.00

-- ── Step 3: Test Withdrawal  ───────────────────────────────────────────────────
EXEC dbo.sp_Withdraw
    @AccID     = 2,        
    @Amount    = 10055.00,
    @Channel   = 'ATM';

EXEC dbo.sp_Withdraw
    @AccID     = 2,        
    @Amount    = 50.00,
    @Channel   = 'ATM';

-- ── Step 4: Test Transfer ─────────────────────────────────────────────────────
EXEC dbo.sp_TransferMoney
    @FromAccID = 5,        
    @ToAccID   = 2,
    @Amount    = 600.00,
    @Channel   = 'APP',
    @IPAddress = '192.168.1.1';

EXEC dbo.sp_TransferMoney
    @FromAccID = 5,        
    @ToAccID   = 2,
    @Amount    = 50.00

-- ── Step 5: Test Online Purchase (card) ─────────────────────────────────────────────────────
EXEC [dbo].[sp_OnlinePurchase_card]
    @CustomerCardID = 2,
    @MerchantID     = 101,
    @Amount         = 250.00,
    @Channel        = 'Web',
    @IPAddress      = '196.218.10.55',
    @DeviceID       = 12;

-- ── Step 6: Test Online Purchase (card) ─────────────────────────────────────────────────────
EXEC sp_OnlinePurchaseByLogin
    @Username     = '3adel_25',
    @PasswordHash = '123', 
    @MerchantID   = 101,
    @Amount       = 250.00,
    @Channel      = 'Web'

-- ── Step 7: Verify full audit trail ──────────────────────────────────────────
SELECT top 10
    TH.Trans_ID, TH.Trans_Type, TH.Trans_Status, TH.Trans_DateTime,
    TE.Acc_ID,   TE.Entry_Type, TE.Amount,
    TA.Channel,  TA.IP_Address
FROM dbo.Transactions_Header TH
JOIN dbo.Transaction_Entry   TE ON TE.Trans_ID = TH.Trans_ID
JOIN dbo.Transactions_Audit  TA ON TA.Trans_ID = TH.Trans_ID
ORDER BY TH.Trans_ID DESC;

