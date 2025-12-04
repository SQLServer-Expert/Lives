/************************************************************
 Autor: Landry
 LIVE #005

 Usuário de Banco de Dados sem login associado
 - Até SQL 2005 SP2 resolvia com sp_change_users_login,
   nas versões seguintes utilizar ALTER USER

 ALTER USER dbuser WITH LOGIN = loginname

 Criar o Login com SID: CREATE LOGIN ... WITH SID
*************************************************************/
USE Master
go

-- Cria Login para Hands On "TesteLogin"
CREATE LOGIN [TesteLogin] WITH	PASSWORD = 'Pa$$w0rd', CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF


-- Cria Usuário de Banco de Dados para o Login "TesteLogin"
Use Aula
go
CREATE USER [TesteLogin] FOR LOGIN [TesteLogin]
go
-- Atribui permissão de Ler e Escrever em Tabelas ou Views
ALTER ROLE [db_datareader] ADD MEMBER [TesteLogin]
ALTER ROLE [db_datawriter] ADD MEMBER [TesteLogin]


-- Faz Backup do Banco de Dados Aula
BACKUP DATABASE Aula TO DISK = 'C:\Backup\Aula.bak' WITH compression,format,stats=5




/****************************************************
 Restore Banco Aula em outra Instância do SQL Server
*****************************************************/
RESTORE DATABASE Aula FROM  DISK = N'C:\Backup\Aula.bak' WITH recovery, replace, stats=5,
MOVE N'Aula' TO N'C:\MSSQL_Data_SQL02\Aula.mdf', 
MOVE N'Aula_Log' TO N'C:\MSSQL_Data_SQL02\Aula_log.ldf'
go
ALTER AUTHORIZATION ON DATABASE::Aula TO [sa]

-- Lista usuários sem login associado
use Aula
go
EXEC sp_change_users_login 'Report'
go
/*
UserName	UserSID
appuser1	0x8EC210217FB5C64FB9DC8F08E0BAF728
reportuser1	0x4489DB6EF75A26488BD427DFA24CA5EF
*/

-- Cria Login "TesteLogin"
CREATE LOGIN [TesteLogin] WITH	PASSWORD = 'Pa$$w0rd'

-- Mostrar SIDs diferentes
SELECT name, SID from sys.server_principals WHERE [name] = 'TesteLogin'

SELECT [type_desc] Tipo, [SID],
[name] as Usuario_Nome,principal_id as Usuario_ID,
authentication_type_desc as Tipo_Autenticacao,
create_date as Data_Criacao, modify_date as Data_Alteracao
FROM sys.database_principals
WHERE [type] <> 'R'
and [name] = 'TesteLogin'
ORDER BY Tipo,Usuario_Nome


-- Resolvendo no método até SQL 2005
EXEC sp_change_users_login @Action = 'Update_One', @UserNamePattern = 'TesteLogin', @LoginName = 'TesteLogin'

-- Resolvendo no método após SQL 2005
ALTER USER TesteLogin WITH LOGIN = TesteLogin

-- Cria Login com SID correto
DROP LOGIN [TesteLogin]

CREATE LOGIN [TesteLogin] WITH	PASSWORD = 'Pa$$w0rd', SID=0x8BEACE8E71699D4F9BD4D065A3F7F305

-- Apaga Banco e Login
use master
go
DROP DATABASE Aula
DROP LOGIN [TesteLogin]
