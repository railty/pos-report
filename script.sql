USE [hq]
GO
/****** Object:  StoredProcedure [dbo].[Check_Connections]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
Create PROCEDURE [dbo].[Check_Connections]
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @SQL nvarchar(500);
	DECLARE @ParmDefinition nvarchar(500);	
	DECLARE @Ct int;

	DECLARE @OFC nvarchar(10);
	DECLARE @OFMM nvarchar(10);
	DECLARE @ALP nvarchar(10);
	DECLARE @OHS nvarchar(10);	

	BEGIN TRY
		SET @SQL = N'SELECT @Ct = Count(*) FROM [PM].[MBPOSDB].[dbo].[Invoice]';
		SET @ParmDefinition = N'@Ct int OUTPUT';	
		execute [ALP].PRIS.dbo.sp_executesql @SQL, @ParmDefinition, @Ct = @Ct OUTPUT;
		Print @Ct;
		SET @ALP='CONNECTED'
	END TRY
	BEGIN CATCH
		SET @ALP='DISCONNECTED'
	END CATCH

	BEGIN TRY
		SET @SQL = N'SELECT @Ct = Count(*) FROM [PM].[MBPOSDB].[dbo].[Invoice]';
		SET @ParmDefinition = N'@Ct int OUTPUT';	
		execute [OFC].PRIS.dbo.sp_executesql @SQL, @ParmDefinition, @Ct = @Ct OUTPUT;
		Print @Ct;
		SET @OFC='CONNECTED'
	END TRY
	BEGIN CATCH
		SET @OFC='DISCONNECTED'
	END CATCH

	BEGIN TRY
		SET @SQL = N'SELECT @Ct = Count(*) FROM [PM].[MBPOSDB].[dbo].[Invoice]';
		SET @ParmDefinition = N'@Ct int OUTPUT';	
		execute [OFMM].PRIS.dbo.sp_executesql @SQL, @ParmDefinition, @Ct = @Ct OUTPUT;
		Print @Ct;
		SET @OFMM='CONNECTED'
	END TRY
	BEGIN CATCH
		SET @OFMM='DISCONNECTED'
	END CATCH

	BEGIN TRY
		SET @SQL = N'SELECT @Ct = Count(*) FROM [PM].[MBPOSDB].[dbo].[Invoice]';
		SET @ParmDefinition = N'@Ct int OUTPUT';	
		execute [OHS].PRIS.dbo.sp_executesql @SQL, @ParmDefinition, @Ct = @Ct OUTPUT;
		Print @Ct;
		SET @OHS='CONNECTED'
	END TRY
	BEGIN CATCH
		SET @OHS='DISCONNECTED'
	END CATCH

	Print @ALP
	Print @OFC
	Print @OFMM
	Print @OHS
	Insert Into connection_log(alp, ofc, ofmm, ohs) Values(@ALP, @OFC, @OFMM, @OHS);
END

GO
/****** Object:  StoredProcedure [dbo].[Create_Report_Data]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
/*
-- Statistics:    
SELECT Description=CASE [Action] WHEN '1' THEN 'Delete' WHEN '2' THEN 'Refund' WHEN '3' THEN 'Void' WHEN '9' THEN 'Discount' END, Count(*) "Count", Sum(Affected_Amt) "Amount" FROM ActionLog
where Act_Date = '2014/01/04' and ws='P2' Group by Action
--ActionLog table record the import actions, too bad it doesn't have invoice_num, I can join it with invoice table by date and time, it works well for delete and refund, but not for void, because the void action may be after the invoice time, so no guarantee
--for action 1, 2, 3 (delete and refund, void), the amount is also recorded in invoice_item table with a nigetive value
-- action 9, discount was caused by quantity sales and maybe something else, since the product table may changed, it would be difficult to recalculate the discount, it be be done by analyst the invoice_item table, ie, if in sale invoice, the same product has two difference price, it could be caused by the quantity sale. but there are other factors here, such as refund.
--void will be some other action, it is in to do list

--Transactions:                              
Select 
COUNT(*) "Num Of Sales Txn", 
SUM(TOTAL_AMOUNT) "Total Sales", 
SUM(TAX1) "Tax_1", 
SUM(TAX2) "Tax_2", 
SUM(TOTAL_AMOUNT)-SUM(TAX1)-SUM(TAX2) "Net Sales",
SUM(TOTAL_AMOUNT)/COUNT(*) "Avg Txn Amt"
From invoice where date_sent='2014/01/04' and ship_dest='P2'
--Sales:                                                                           
--                          Trans. Discount                                     0.00  
Select 
COUNT(*) "Num Of Sales Txn", 
SUM(TOTAL_AMOUNT) "Total Sales", 
SUM(TAX1) "Tax_1", 
SUM(TAX2) "Tax_2", 
SUM(TOTAL_AMOUNT)-SUM(TAX1)-SUM(TAX2) "Net Sales"
From invoice where date_sent='2014/01/04' and ship_dest='P2'
--   Sales Payment:    
Select Method, Sum(PayAmt) From Invoice JOIN InvPay on Invoice.Invoice_Num  = Invpay.Invoice_Num 
where date_sent='2014/01/04' and ship_dest='P2'
Group by Method

select Sum(PayAmt) "Tot.Sales Payment" From Invoice JOIN InvPay on Invoice.Invoice_Num  = Invpay.Invoice_Num 
where date_sent='2014/01/04' and ship_dest='P2'
--InvPay table record how the customer paid. 
--there will be multiple records for same invoice if customer pays partial by cash and other by card. in this case, the pay_method in invoice table will how mixed, and the detail will be recorded here.
--the PayAmt may be different with the invoice table, because we got rid of the 1 cent change. the PaymentDiscount record this

--Pay Out:
SELECT Sum(PayTotal) "Cash" FROM [MBPOSDB].[dbo].[PayOut] where PayDate = '2014/01/04'                                                                                    
--Prepay:
--Accnt Payment:
--In Drawer:                                                                       
--1403.41+587.68+1184.51==3175.60  

*/

-- =============================================
CREATE PROCEDURE [dbo].[Create_Report_Data]
@STORE as varchar(10),
@Dt as varchar(10)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @SQL nvarchar(500);

	BEGIN TRY
		Print @Dt;

		--drop table rpt_a;
		--create table rpt_a(Store varchar(10), Dt Date, WS varchar(10), Action varchar(10), Count Int, Amount Decimal(10, 2));
		Delete From rpt_a Where Store=@Store And Dt = @Dt;
		--drop table rpt_b;
		--create table rpt_b(Store varchar(10), Dt Date, WS varchar(10), Num_Of_Sales_Txn Int, Total_Sales Decimal(10, 2), Tax_1 Decimal(10, 2), Tax_2 Decimal(10, 2), Net_Sales Decimal(10, 2), Avg_Txn_Amt Decimal(10, 2));
		Delete From rpt_b Where Store=@Store And  Dt = @Dt;
		--drop table rpt_c;
		--create table rpt_c(Store varchar(10), Dt Date, WS varchar(10), Method varchar(10), Amount Decimal(10, 2));
		Delete From rpt_c Where Store=@Store And  Dt = @Dt;
		--drop table rpt_d;
		--create table rpt_d(Store varchar(10), Dt Date, WS varchar(10), Payout Decimal(10, 2));
		Delete From rpt_d Where Store=@Store And  Dt = @Dt;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''' + @Dt + ''''', WS, Action=CASE [Action] WHEN ''''1'''' THEN ''''Delete'''' WHEN ''''2'''' THEN ''''Refund'''' WHEN ''''3'''' THEN ''''Void'''' WHEN ''''9'''' THEN ''''Discount'''' END, Count(*) Count, Sum(Affected_Amt) Amount FROM [MBPOSDB].[dbo].ActionLog Where Act_Date = ''''' + @Dt + ''''' Group by WS, Action'
		Print @SQL;
		--INSERT Into rpt_a execute [ALP].PRIS.dbo.sp_executesql @SQL;
		SET @SQL = N'INSERT Into rpt_a execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''' + @Dt + ''''', Ship_Dest WS, COUNT(*) Num_Of_Sales_Txn, SUM(TOTAL_AMOUNT) Total_Sales, SUM(TAX1) Tax_1, SUM(TAX2) Tax_2, SUM(TOTAL_AMOUNT)-SUM(TAX1)-SUM(TAX2) Net_Sales, SUM(TOTAL_AMOUNT)/COUNT(*) Avg_Txn_Amt From [MBPOSDB].[dbo].Invoice where date_sent=''''' + @Dt + ''''' Group By Ship_dest';
		Print @SQL;
		--INSERT Into rpt_b execute [ALP].PRIS.dbo.sp_executesql @SQL;
		SET @SQL = N'INSERT Into rpt_b execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''' + @Dt + ''''', Ship_Dest WS ,Method, Sum(PayAmt) From [MBPOSDB].[dbo].Invoice JOIN [MBPOSDB].[dbo].InvPay on Invoice.Invoice_Num  = Invpay.Invoice_Num Where date_sent=''''' + @Dt + ''''' Group by Ship_dest, Method';
		Print @SQL;
		--INSERT Into rpt_c execute [ALP].PRIS.dbo.sp_executesql @SQL;
		SET @SQL = N'INSERT Into rpt_c execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;
		
		SET @SQL = N'Select ''''' + @Store + ''''', ''''' + @Dt + ''''', WSID WS, Sum(PayTotal) FROM [MBPOSDB].[dbo].[PayOut] Where PayDate = ''''' + @Dt + ''''' Group By WSID';
		Print @SQL;
		--INSERT Into rpt_d execute [ALP].PRIS.dbo.sp_executesql @SQL;
		SET @SQL = N'INSERT Into rpt_d execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

	END TRY
	BEGIN CATCH
	END CATCH
END

GO
/****** Object:  StoredProcedure [dbo].[Create_Report2_Data]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
/*
declare @ws varchar(2)
select @ws='P1'
declare @dt datetime
select @dt='2014/01/02'

select EmpNum, Method, sum(PayAmt) from InvPay where PayDate = @dt and WorkStationID=@ws group by EmpNum, Method;

declare @payout Decimal(10, 2)
select @payout=sum(PayTotal) from PayOut where PayDate = @dt and WSID=@ws;
print 'payout=$' + Convert(varchar, @payout)

declare @RetailSales Decimal(10, 2)
select @RetailSales=sum(PayAmt)  from InvPay where PayDate = @dt and WorkStationID=@ws
print 'RetailSales=$' + Convert(varchar, @RetailSales)

declare @five_cent_round Decimal(10, 2)
select @five_cent_round=sum(PaymentDiscount) from InvPay where PayDate = @dt and WorkStationID=@ws
print 'five cent round=' + Convert(varchar, @five_cent_round)

declare @num_of_txn int
declare @start_time datetime
declare @tax1 Decimal(10, 2)
declare @tax2 Decimal(10, 2)
select @num_of_txn=count(*), @start_time=min(InvoiceTime), @tax1=sum(Tax1), @tax2=sum(Tax2) from Invoice where Date_Sent = @dt and SHIP_DEST=@ws
print 'num of txn=' + Convert(varchar, @num_of_txn)
print '@start_time=' + Convert(varchar, @start_time, 108)
print 'tax1=' + Convert(varchar, @tax1)
print 'tax2=' + Convert(varchar, @tax2)

declare @first_emp as varchar(15)
select top 1 @first_emp=Emp_Num from Invoice where Date_Sent = @dt and SHIP_DEST=@ws order by InvoiceTime
print 'first_emp=' + @first_emp
--or use subquery
Select A.SHIP_DEST, A.Emp_Num from Invoice A
Join (Select SHIP_DEST, Min(InvoiceTime) Tm from Invoice Where Date_Sent = '2014/01/02' group by SHIP_DEST) B
On A.SHIP_DEST = B.SHIP_DEST And A.InvoiceTime = B.Tm

declare @net_sales Decimal(10, 2)
select @net_sales=@RetailSales+@five_cent_round-@tax1-@tax2
print 'net_sales=' + Convert(varchar, @net_sales)

--select * from ActionLog where Act_Date=@dt and WS=@ws --group by Action
select OperatorID, Action, count(*), sum(Affected_Amt) from ActionLog where Act_Date=@dt and WS=@ws group by OperatorID, Action


SELECT [FieldValue] FROM [MBPOSDB].[dbo].[SystemParm] Where FieldID='COMP_POS';
SELECT [FieldValue] FROM [MBPOSDB].[dbo].[SystemParm] Where FieldID='COMP_CITY';
SELECT [FieldValue] FROM [MBPOSDB].[dbo].[SystemParm] Where FieldID='COMP_PROV';
SELECT [FieldValue] FROM [MBPOSDB].[dbo].[SystemParm] Where FieldID='COMP_PHONE_AREA';
SELECT [FieldValue] FROM [MBPOSDB].[dbo].[SystemParm] Where FieldID='COMP_PHONE_NUM';
SELECT [FieldValue] FROM [MBPOSDB].[dbo].[SystemParm] Where FieldID='GST NUMBER';
SELECT [FieldValue] FROM [MBPOSDB].[dbo].[SystemParm] Where FieldID='STANDARD_TC1';



EXEC sp_configure 'show advanced options', 1
GO
RECONFIGURE
GO
exec sp_configure 'xp_cmdshell', 1
GO
RECONFIGURE
GO

EXEC xp_cmdshell 'Sleep 5';
EXEC xp_cmdshell 'C:\sites\report_job.bat';

*/

-- =============================================
CREATE PROCEDURE [dbo].[Create_Report2_Data]
@STORE as varchar(10),
@Dt as varchar(10)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @SQL nvarchar(500);

	BEGIN TRY
		Print @Dt;
		--drop table rpt_2a;
		--create table rpt_2a(Store varchar(10), Dt Date, WS varchar(10), Emp varchar(15), Method varchar(15), PayAmt Money);
		Delete From rpt_2a Where Store=@Store And Dt = @Dt;

		--drop table rpt_2b;
		--create table rpt_2b(Store varchar(10), Dt Date, WS varchar(10), Cashier varchar(10), PayOut Money);
		Delete From rpt_2b Where Store=@Store And Dt = @Dt;

		--drop table rpt_2c;
		--create table rpt_2c(Store varchar(10), Dt Date, WS varchar(10), RetailSales Money, Five_Cent_Round Money);
		Delete From rpt_2c Where Store=@Store And Dt = @Dt;

		--drop table rpt_2d;
		--create table rpt_2d(Store varchar(10), Dt Date, WS varchar(10), Num_Of_Txn Int, Start_Time Time, Tax1 Money, Tax2 Money);
		Delete From rpt_2d Where Store=@Store And Dt = @Dt;

		--drop table rpt_2e;
		--create table rpt_2e(Store varchar(10), Dt Date, WS varchar(10), First_Emp varchar(15));
		Delete From rpt_2e Where Store=@Store And Dt = @Dt;

		--drop table rpt_2f;
		--create table rpt_2f(Store varchar(10), Dt Date, WS varchar(10), Emp varchar(15), Action varchar(10), Affected_Items Int, Affected_Amt Money);
		Delete From rpt_2f Where Store=@Store And Dt = @Dt;

		/*
		drop table rpt_2z;
		create table rpt_2z(Store varchar(10), Name nvarchar(80), Value nvarchar(80));
		insert into rpt_2z(Store) values('ALP');
		insert into rpt_2z(Store) values('OHS');
		insert into rpt_2z(Store) values('OFC');
		insert into rpt_2z(Store) values('OFMM');
		*/
		Delete From rpt_2z Where Store=@Store;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''' + @Dt + ''''', WorkStationID WS, EmpNum, Method, Sum(PayAmt) PayAmt From [MBPOSDB].[dbo].InvPay Where PayDate = ''''' + @Dt + ''''' Group By WorkStationID, EmpNum, Method';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2a execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''' + @Dt + ''''', WSID, Cashier, Sum(PayTotal) From [MBPOSDB].[dbo].PayOut Where PayDate = ''''' + @Dt + ''''' Group By WSID, Cashier';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2b execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''' + @Dt + ''''', WorkStationID, Sum(PayAmt), Sum(PaymentDiscount) From [MBPOSDB].[dbo].InvPay Where PayDate = ''''' + @Dt + ''''' Group By WorkStationID';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2c execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''' + @Dt + ''''', Ship_Dest, Count(*), Min(InvoiceTime), Sum(Tax1), Sum(Tax2) From [MBPOSDB].[dbo].Invoice Where Date_Sent = ''''' + @Dt + ''''' Group By Ship_Dest';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2d execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''' + @Dt + ''''', A.Ship_Dest, A.Emp_Num From [MBPOSDB].[dbo].Invoice A Join (Select SHIP_DEST, Min(InvoiceTime) Tm from [MBPOSDB].[dbo].Invoice Where Date_Sent = ''''' + @Dt + ''''' Group By SHIP_DEST) B On A.SHIP_DEST = B.SHIP_DEST And A.InvoiceTime = B.Tm';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2e execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''' + @Dt + ''''', WS, OperatorID, Action=CASE [Action] WHEN ''''1'''' THEN ''''Delete'''' WHEN ''''2'''' THEN ''''Refund'''' WHEN ''''3'''' THEN ''''Void'''' WHEN ''''9'''' THEN ''''Discount'''' END, Count(*), Sum(Affected_Amt) From [MBPOSDB].[dbo].ActionLog Where Act_Date = ''''' + @Dt + ''''' Group By WS, OperatorID, Action';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2f execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''COMP_HOMEPAGE'''', [FieldValue] From [MBPOSDB].[dbo].[SystemParm] Where FieldID = ''''STANDARD_TC1'''' ';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2z execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''COMP_PHONE_AREA'''', [FieldValue] From [MBPOSDB].[dbo].[SystemParm] Where FieldID = ''''COMP_PHONE_AREA'''' ';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2z execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''COMP_PHONE_NUM'''', [FieldValue] From [MBPOSDB].[dbo].[SystemParm] Where FieldID = ''''COMP_PHONE_NUM'''' ';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2z execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''COMP_STREET'''', [FieldValue] From [MBPOSDB].[dbo].[SystemParm] Where FieldID = ''''COMP_STREET'''' ';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2z execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''COMP_CITY'''', [FieldValue] From [MBPOSDB].[dbo].[SystemParm] Where FieldID = ''''COMP_CITY'''' ';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2z execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''COMP_PROV'''', [FieldValue] From [MBPOSDB].[dbo].[SystemParm] Where FieldID = ''''COMP_PROV'''' ';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2z execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''COMP_POS'''', [FieldValue] From [MBPOSDB].[dbo].[SystemParm] Where FieldID = ''''COMP_POS'''' ';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2z execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''GST_NUMBER'''', [FieldValue] From [MBPOSDB].[dbo].[SystemParm] Where FieldID = ''''GST NUMBER'''' ';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2z execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

		SET @SQL = N'Select ''''' + @Store + ''''', ''''COMP_TITLE'''', [FieldValue] From [MBPOSDB].[dbo].[SystemParm] Where FieldID = ''''COMP_TITLE'''' ';
		Print @SQL;
		SET @SQL = N'INSERT Into rpt_2z execute ' + @Store + N'.PRIS.dbo.sp_executesql N''' + @SQL + '''';
		Print @SQL;
		execute sp_executesql @SQL;

	END TRY
	BEGIN CATCH
	END CATCH
	SELECT WS  FROM rpt_2v where Store=@store and dt=@dt;
END

GO
/****** Object:  StoredProcedure [dbo].[Print_Receipt]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
/*

EXEC sp_configure 'show advanced options', 1
GO
RECONFIGURE
GO
exec sp_configure 'xp_cmdshell', 1
GO
RECONFIGURE
GO

EXEC xp_cmdshell 'Sleep 5';
EXEC xp_cmdshell 'C:\sites\report_job.bat';


rem schtasks /delete /tn "print-receipt" /f
rem schtasks /create /xml print-receipt.xml /tn "print-receipt" /ru sning /rp password
rem schtasks /run /tn "print-receipt"
*/

-- =============================================
CREATE PROCEDURE [dbo].[Print_Receipt]
@STORE as varchar(10),
@Dt as varchar(10)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @cmd nvarchar(500);
	DECLARE @Ct int;

	BEGIN TRY
		Print 'Print receipts for ' + @Store + ' at ' + @Dt;
		
		Select @Ct = Count(*) from report_queue where store=@STORE and dt=@DT;
		print @Ct

		if @Ct = 0
		Begin
			Insert Into report_queue(store, dt, ws, status, submitted_at, log) values(@STORE, @DT, '*', 'waiting', GETDATE(), '');
			Set @cmd = 'schtasks /run /tn "print-receipt';
			Print @Cmd
			EXEC xp_cmdshell @cmd
		End
	END TRY
	BEGIN CATCH
	END CATCH
END

GO
/****** Object:  StoredProcedure [dbo].[RunSQL]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
Create PROCEDURE [dbo].[RunSQL]
	@STORE nvarchar(32),
	@SQL nvarchar(4000)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @ParmDefinition nvarchar(500);
	SET @ParmDefinition = '@STORE nvarchar(10)';

	SELECT @SQL = 'EXEC ' + QuoteName(@STORE) + '.Pris.dbo.[RunSQL] @SQL = N''' + @SQL + ''''
	EXECUTE sp_executesql @SQL;
END



GO
/****** Object:  Table [dbo].[connection_log]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[connection_log](
	[time] [datetime] NULL,
	[ofc] [nvarchar](10) NULL,
	[alp] [nvarchar](10) NULL,
	[ofmm] [nvarchar](10) NULL,
	[id] [int] IDENTITY(1,1) NOT NULL,
	[ohs] [nvarchar](10) NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[report_queue]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[report_queue](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[store] [varchar](10) NULL,
	[dt] [varchar](10) NULL,
	[ws] [varchar](10) NULL,
	[status] [varchar](10) NULL,
	[submitted_at] [datetime] NULL,
	[run_at] [datetime] NULL,
	[completed_at] [datetime] NULL,
	[log] [varchar](4000) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rpt_2a]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rpt_2a](
	[Store] [varchar](10) NULL,
	[Dt] [date] NULL,
	[WS] [varchar](10) NULL,
	[Emp] [varchar](15) NULL,
	[Method] [varchar](15) NULL,
	[PayAmt] [money] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rpt_2b]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rpt_2b](
	[Store] [varchar](10) NULL,
	[Dt] [date] NULL,
	[WS] [varchar](10) NULL,
	[Cashier] [varchar](10) NULL,
	[PayOut] [money] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rpt_2c]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rpt_2c](
	[Store] [varchar](10) NULL,
	[Dt] [date] NULL,
	[WS] [varchar](10) NULL,
	[RetailSales] [money] NULL,
	[Five_Cent_Round] [money] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rpt_2d]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rpt_2d](
	[Store] [varchar](10) NULL,
	[Dt] [date] NULL,
	[WS] [varchar](10) NULL,
	[Num_Of_Txn] [int] NULL,
	[Start_Time] [time](7) NULL,
	[Tax1] [money] NULL,
	[Tax2] [money] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rpt_2e]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rpt_2e](
	[Store] [varchar](10) NULL,
	[Dt] [date] NULL,
	[WS] [varchar](10) NULL,
	[First_Emp] [varchar](15) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rpt_2f]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rpt_2f](
	[Store] [varchar](10) NULL,
	[Dt] [date] NULL,
	[WS] [varchar](10) NULL,
	[Emp] [varchar](15) NULL,
	[Action] [varchar](10) NULL,
	[Affected_Items] [int] NULL,
	[Affected_Amt] [money] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rpt_2z]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rpt_2z](
	[Store] [varchar](10) NULL,
	[Name] [nvarchar](80) NULL,
	[Value] [nvarchar](80) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rpt_a]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rpt_a](
	[Store] [varchar](10) NULL,
	[Dt] [date] NULL,
	[WS] [varchar](10) NULL,
	[Action] [varchar](10) NULL,
	[Count] [int] NULL,
	[Amount] [decimal](10, 2) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rpt_b]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rpt_b](
	[Store] [varchar](10) NULL,
	[Dt] [date] NULL,
	[WS] [varchar](10) NULL,
	[Num_Of_Sales_Txn] [int] NULL,
	[Total_Sales] [decimal](10, 2) NULL,
	[Tax_1] [decimal](10, 2) NULL,
	[Tax_2] [decimal](10, 2) NULL,
	[Net_Sales] [decimal](10, 2) NULL,
	[Avg_Txn_Amt] [decimal](10, 2) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rpt_c]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rpt_c](
	[Store] [varchar](10) NULL,
	[Dt] [date] NULL,
	[WS] [varchar](10) NULL,
	[Method] [varchar](10) NULL,
	[Amount] [decimal](10, 2) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rpt_d]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rpt_d](
	[Store] [varchar](10) NULL,
	[Dt] [date] NULL,
	[WS] [varchar](10) NULL,
	[Payout] [decimal](10, 2) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  View [dbo].[view_a]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [dbo].[view_a] as 
select p.Store Store, p.Dt 'Dt', p.WS WS, p.Refund Refund_Amount, p.Discount Discount_Amount, p.[Delete] Delete_Amount, p.Void Void_Amount,
ct.Refund Refund_Ct, ct.Discount Discount_Ct, ct.[Delete] Delete_Ct, ct.Void Void_Ct
from 
(
    select Store, Dt, Ws, Action, Amount from rpt_a
) x
pivot
(
    sum(Amount)
    for Action in (Refund, Discount, [Delete], Void)
) p
join (
select *
from 
(
    select Store, Dt, Ws, Action, Count from rpt_a
) x
pivot
(
    sum(Count)
    for Action in (Refund, Discount, [Delete], Void)
) q) ct
on p.Store = ct.store and p.Dt = ct.Dt and p.Ws=ct.Ws

GO
/****** Object:  View [dbo].[view_c]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [dbo].[view_c] as 
select *
from 
(
    select Store, Dt, Ws,Method, Amount from rpt_c
) x
pivot
(
    sum(Amount)
    for Method in (Cash, Credit, Debit)
) q



GO
/****** Object:  View [dbo].[view_report]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [dbo].[view_report] as
select rpt_b.Store, rpt_b.Dt, rpt_b.WS, Num_Of_Sales_Txn, Total_Sales, Tax_1, Tax_2, Net_Sales, Avg_Txn_Amt, 
Refund_Amount, Discount_Amount, Void_Amount, Delete_Amount, 
Refund_Ct, Discount_Ct, Void_Ct, Delete_Ct, 
Cash, Credit, Debit, Payout
from rpt_b
left join rpt_d on rpt_b.Store = rpt_d.store and rpt_b.Dt = rpt_d.Dt and rpt_b.Ws=rpt_d.Ws
left join view_a on rpt_b.Store = view_a.store and rpt_b.Dt = view_a.Dt and rpt_b.Ws=view_a.Ws
left join view_c on rpt_b.Store = view_c.store and rpt_b.Dt = view_c.Dt and rpt_b.Ws=view_c.Ws



GO
/****** Object:  View [dbo].[rpt_2v]    Script Date: 3/26/2014 10:32:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/
Create View [dbo].[rpt_2v] as (
SELECT Store, Dt, WS FROM rpt_2a
union SELECT Store, Dt, WS FROM rpt_2b
union SELECT Store, Dt, WS FROM rpt_2b
union SELECT Store, Dt, WS FROM rpt_2c
union SELECT Store, Dt, WS FROM rpt_2d
union SELECT Store, Dt, WS FROM rpt_2e
union SELECT Store, Dt, WS FROM rpt_2f)
GO
ALTER TABLE [dbo].[connection_log] ADD  CONSTRAINT [DF_connection_log]  DEFAULT (getdate()) FOR [time]
GO
