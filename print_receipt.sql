USE [hq]
GO
/****** Object:  StoredProcedure [dbo].[Print_Receipt]    Script Date: 3/7/2014 3:48:03 PM ******/
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

*/

-- =============================================
ALTER PROCEDURE [dbo].[Print_Receipt]
@STORE as varchar(10),
@Dt as varchar(10)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @cmd nvarchar(500);

	BEGIN TRY
		Print 'Print receipts for ' + @Store + ' at ' + @Dt;
		Set @cmd = 'c:\sites\pos-report\report_job.bat ' + @Store + ' ' + @Dt;
		Print @Cmd
		EXEC xp_cmdshell @cmd
	END TRY
	BEGIN CATCH
	END CATCH
END
