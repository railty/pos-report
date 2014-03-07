USE [hq]
GO
/****** Object:  StoredProcedure [dbo].[Create_Report2_Data]    Script Date: 3/7/2014 3:48:01 PM ******/
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
ALTER PROCEDURE [dbo].[Create_Report2_Data]
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
