/*******************************************************************
 Autor: Landry Duailibe
 LIVE #139 Investigando o Log de Transações com FN_DBLOG e FN_DUMP_DBLOG

 Hands On: Entendendo Arquivos de Log no SQL Server
********************************************************************/
use master
go

/**************************
 Cria Banco HandsOn
***************************/
DROP DATABASE IF exists HandsOn
go
CREATE DATABASE HandsOn 

-- Altera Recovery Model
ALTER DATABASE HandsOn SET RECOVERY FULL


--  Cria tabela 
DROP TABLE IF exists HandsOn.dbo.Cliente
go
CREATE TABLE HandsOn.dbo.Cliente ( 
Cliente_ID int not null identity CONSTRAINT pk_Cliente PRIMARY KEY,
Nome char(1200) not null,
Renda bigint null)
go

-- Backup FULL
BACKUP DATABASE HandsOn TO DISK = 'E:\_Lives\Backup\HandsOn_Full.bak' WITH format, compression

/*******************************************
 Mostrar os Logs Virtuais e porção ativa
********************************************/
-- DBCC LOGINFO não documentado
DBCC LOGINFO ('HandsOn') 

/******************************************************************
 SYS.DM_DB_LOG_INFO
 - Disponível a partir do SQL Server 2016
 https://learn.microsoft.com/pt-br/sql/relational-databases/system-dynamic-management-views/sys-dm-db-log-info-transact-sql?view=sql-server-ver16

 - vlf_active (0 livre / 1 ativo)
 - vlf_status (0 livre / 1 inicializado mas sem uso / 2 em uso)
*******************************************************************/
SELECT * FROM sys.dm_db_log_info(db_id('HandsOn')) ORDER BY vlf_begin_offset

-- Verifica Status do Log Reuse
SELECT name as Banco, log_reuse_wait_desc 
FROM sys.databases WHERE name = 'HandsOn'

-- Tamanho do arquivo de Log
SELECT db.[name] as Banco, mf.[name] Arquivo, (mf.[size] * 8) / 1024 as Tamanho_MB
FROM sys.master_files mf
JOIN sys.databases db ON mf.database_id = db.database_id
WHERE mf.[type] = 1 and db.[name] = 'HandsOn'


/****************************************************
 Carga de 20.000 linhas para lotar o arquivo de Log
*****************************************************/
set nocount on
go

INSERT HandsOn.dbo.Cliente (Nome,Renda)
VALUES('Bla Bla Bla...',12345)
go 20000


-- Logs Virtuais
SELECT * FROM sys.dm_db_log_info(db_id('HandsOn')) ORDER BY vlf_begin_offset

-- Tamanho do arquivo de Log
SELECT db.[name] as Banco, mf.[name] Arquivo, (mf.[size] * 8) / 1024 as Tamanho_MB
FROM sys.master_files mf
JOIN sys.databases db ON mf.database_id = db.database_id
WHERE mf.[type] = 1 and db.[name] = 'HandsOn'

-- Verifica Status do Log Reuse
SELECT name as Banco, log_reuse_wait_desc FROM sys.databases WHERE name = 'HandsOn'

-- Backup Log trunca o arquivo internamente
BACKUP LOG HandsOn TO DISK = 'E:\_Lives\Backup\HandsOn.trn' WITH NOINIT, COMPRESSION

-- Porção ativa do Log no final do arquivo
SELECT * FROM sys.dm_db_log_info(db_id('HandsOn')) ORDER BY vlf_begin_offset

-- Carrega 15.000 linhas
INSERT HandsOn.dbo.Cliente (Nome,Renda)
VALUES('Bla Bla Bla...',12345)
go 15000


ALTER DATABASE HandsOn SET RECOVERY SIMPLE
go

-- Recovery Model SIMPLE truncou internamente o arquivo de Log
SELECT * FROM sys.dm_db_log_info(db_id('HandsOn')) ORDER BY vlf_begin_offset

-- Carrega 15.000 linhas
INSERT HandsOn.dbo.Cliente (Nome,Renda)
VALUES('Bla Bla Bla...',12345)
go 15000

/***********************************
 Executar transação em outra janela
 - Deixar transação em aberto
************************************/
BEGIN TRAN

INSERT HandsOn.dbo.Cliente (Nome,Renda)
VALUES('Bla Bla Bla...',12345)
go 15000

COMMIT

-- Abrir outra conexão: Verificar Status do Log Reuse
SELECT name as Banco, log_reuse_wait_desc FROM sys.databases WHERE name = 'HandsOn'

-- Com transação aberta mesmo no Recovery Model SIMPLE não trunca o arquivo de Log
SELECT * FROM sys.dm_db_log_info(db_id('HandsOn')) ORDER BY vlf_begin_offset

/*********************
 Remove o Banco
**********************/
use master
go
ALTER DATABASE HandsOn SET READ_ONLY WITH ROLLBACK IMMEDIATE
go
DROP DATABASE HandsOn
go
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = 'HandsOn'

