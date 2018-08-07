﻿CREATE PROCEDURE [dbo].[CollectSrvPrincipals]
@SRVID INT NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Connstr AS NVARCHAR (100);
    DECLARE @SQLStr AS NVARCHAR (MAX);
    DECLARE @ACTIONTYPE AS INT;
    SET @ACTIONTYPE = 9;
    DECLARE @ERROR_CODE AS INT;
    DECLARE @ERROR_MESS AS NVARCHAR (400);
    SET @Connstr = (SELECT connstr
                    FROM   Servers AS s
                    WHERE  s.ServID = @SRVID);
    SET @SQLStr = '
DECLARE @ID uniqueidentifier = (SELECT NEWID())

INSERT INTO [dbo].[SrvLogins]
           (
           [ID]
           ,[srvid]
		   ,[sid]
		   ,[LoginName]
           ,[Pass]
		  )

SELECT
 @ID
	 ,' + CAST (@SRVID AS NVARCHAR (50)) + '
	,[sid]
	,[loginname]
	,[password]


FROM OPENROWSET(''SQLNCLI'',' + '''' + @Connstr + '''' + ', ' + '''
select  [sid]
	,[loginname]
	,[password]
from sys.syslogins
WHERE hasaccess=1
''' + ')

INSERT INTO [dbo].[SrvRoleMembers]
           (batch_id
		   ,SrvID
		   ,[CollectionDate]
           ,[RoleType]
           ,[Role]
           ,[Member]
           ,[Login]
           ,[SID])
     
SELECT @ID
		,' + CAST (@SRVID AS NVARCHAR (50)) + '
		,getdate()
		,[RoleType]
           ,[Role]
           ,[Member]
           ,[Login]
           ,[SID]

	FROM OPENROWSET(''SQLNCLI'',' + '''' + @Connstr + '''' + ', ' + '''
	
select ''''MSDB role'''' as [RoleType],dbp1.name as [Role],dbp2.name as [Member],sl.name as [Login], sl.sid as [SID] 
 from msdb.sys.database_role_members dbrm
join msdb.sys.database_principals dbp1 on dbp1.principal_id = dbrm.role_principal_id and dbp1.type= ''''R''''
join msdb.sys.database_principals dbp2 on dbp2.principal_id = dbrm.member_principal_id
join msdb.sys.syslogins sl on sl.sid = dbp2.sid

UNION ALL

select ''''Server Role'''' as [RoleType],dbp1.name as [Role],dbp2.name as [Member],sl.name as [Login], sl.sid as [SID]  from sys.server_role_members dbrm
join sys.server_principals dbp1 on dbp1.principal_id = dbrm.role_principal_id and dbp1.type= ''''R''''
join sys.server_principals dbp2 on dbp2.principal_id = dbrm.member_principal_id
join sys.syslogins sl on sl.sid = dbp2.sid
	''' + ')

';
    BEGIN TRY
        EXECUTE sp_executesql @SQLStr;
    END TRY
    BEGIN CATCH
        SET @ERROR_CODE = ERROR_NUMBER();
        SET @ERROR_MESS = ERROR_MESSAGE();
        PRINT @ERROR_MESS;
        PRINT @sqlStr;
        EXECUTE dbo.WriteErrorLog 9, @SRVID, @ERROR_CODE, @ERROR_MESS;
    END CATCH
    DECLARE @D AS INT;
    SELECT @D = IntValue
    FROM   dbo.Settings
    WHERE  [name] = 'ConfRetentionDays';
    DELETE [dbo].[SrvLogins]
    WHERE  SrvID = @SRVID
           AND CollectionDate < DATEADD(DD, -@D, GETDATE());
	DELETE FROM dbo.SrvRoleMembers
		WHERE SrvID = @SRVID
		AND CollectionDate < DATEADD(DD, -@D, GETDATE());
END