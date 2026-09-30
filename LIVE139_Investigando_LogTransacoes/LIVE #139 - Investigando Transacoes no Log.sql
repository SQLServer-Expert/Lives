/**********************************************************************************
 Autor: Landry Duailibe
 LIVE #139 Investigando o Log de Transações com FN_DBLOG e FN_DUMP_DBLOG

 Hands On: Investigação de trasações no Log com fn_dblog e fn_dump_dblog
 
 Rodar fn_dblog/fn_dump_dblog sem sysadmin retorna:
 - Msg 9010: "User does not have permission to query the virtual table, DBLog"
***********************************************************************************/
use master
go

/**************************
 Cria Banco HandsOn_Transacao
***************************/
DROP DATABASE IF EXISTS HandsOn_Transacao
go
CREATE DATABASE HandsOn_Transacao
go

ALTER DATABASE HandsOn_Transacao SET RECOVERY FULL
go

-- Tabela que sera "acidentalmente" excluida mais adiante
DROP TABLE IF EXISTS HandsOn_Transacao.dbo.Pedido
go
CREATE TABLE HandsOn_Transacao.dbo.Pedido (
PedidoId int not null identity CONSTRAINT pk_Pedido PRIMARY KEY,
ClienteNome varchar(200) not null,
ValorTotal decimal(10,2) not null,
DataPedido datetime not null CONSTRAINT df_Pedido_DataPedido DEFAULT(getdate()))
go

-- Backup FULL - linha baseline para Restore
BACKUP DATABASE HandsOn_Transacao TO DISK = 'E:\_Lives\Backup\HandsOn_Transacao_Full.bak'
WITH format, compression


-- Carga inicial
set nocount on
go

INSERT HandsOn_Transacao.dbo.Pedido (ClienteNome, ValorTotal)
VALUES ('Cliente', 1500.00)
go 500

/*******************************************************
 Backup de Log #1
 - Trunca a porção inativa
********************************************************/
BACKUP LOG HandsOn_Transacao TO DISK = 'E:\_Lives\Backup\HandsOn_Transacao_Log1.trn'
WITH noinit, compression



/*******************************************************************
 INCIDENTE
 - Excluir a tabela para simular o "acidente de produção"
********************************************************************/
DROP TABLE HandsOn_Transacao.dbo.Pedido
go

/*********************************************************************
 Atividade continua normalmente depois do incidente
 - Mostra que o log segue crescendo
**********************************************************************/
DROP TABLE IF EXISTS HandsOn_Transacao.dbo.Log_Auditoria
go
CREATE TABLE HandsOn_Transacao.dbo.Log_Auditoria (
Id int not null identity CONSTRAINT pk_Log_Auditoria PRIMARY KEY,
Mensagem varchar(200) not null)
go

INSERT HandsOn_Transacao.dbo.Log_Auditoria (Mensagem)
VALUES ('Atividade pos-incidente')
go 50


/****************************************************************************
 Achando o DROP na porção ATIVA do log com sys.fn_dblog
 - Só funciona enquanto ninguém rodou BACKUP LOG depois do incidente. 
*****************************************************************************/
use HandsOn_Transacao
go

/********************************************************************
 Função não documentada que lê o arquivo de log fn_dblog(NULL,NULL)
 - NULL, — Start LSN nvarchar(25)
 - NULL  — End LSN nvarchar(25)
*********************************************************************/
SELECT [Current LSN], [Operation], [Context], [Transaction ID], [Description], [Transaction Name]
FROM fn_dblog(NULL, NULL)
WHERE [Transaction Name] LIKE '%INSERT%'
-- 50 linhas

-- Trace Flag 2537: retorna também a porção INATIVA do log
DBCC TRACEON(2537, -1)

-- Agora fn_dblog(NULL, NULL) também retorna registros já truncados/reutilizáveis
SELECT count(*) as TotalRegistros FROM fn_dblog(NULL, NULL)
-- 598

DBCC TRACEOFF(2537, -1)


-- Localiza o início da transação do DROP
SELECT [Current LSN], [Operation], [Context], [Transaction ID], [Description], [Transaction Name]
FROM fn_dblog(NULL, NULL)
WHERE [Operation] = 'LOP_BEGIN_XACT' AND [Transaction Name] = 'DROPOBJ'
-- PEgar Current LSN: 0000002D:00000210:0001

-- Traz TODAS as operações da mesma transação (join por Transaction ID)
SELECT [Current LSN], [Operation], [Context], [Transaction ID], [Description], [Transaction Name]
FROM fn_dblog(NULL, NULL),
    (SELECT [Transaction ID] AS tid
     FROM fn_dblog(NULL, NULL)
     WHERE [Transaction Name] = 'DROPOBJ') fd
WHERE [Transaction ID] = fd.tid
ORDER BY [Current LSN]


-- Quem rodou o DROP (Transaction SID -> login)
SELECT [Current LSN], [Transaction SID], 
SUSER_SNAME([Transaction SID]) AS Executor, [Begin Time]
FROM fn_dblog(NULL, NULL)
WHERE [Operation] = 'LOP_BEGIN_XACT' AND [Transaction Name] = 'DROPOBJ'



/****************************************************************************
 Convertendo a LSN do formato fn_dblog (hex "vlf:offset:slot")
 - para o formato decimal exigido por RESTORE ... WITH STOPBEFOREMARK
   só aceita 'lsn:<decimal>'.
*****************************************************************************/

-- Substitua pela LSN da coluna [Current LSN] retornada na Parte 1
DECLARE @LSN_Hex varchar(30) = '0000002D:00000210:0001' -- <<< AJUSTAR

DECLARE @VLFSeqNo varchar(8), @LogBlockOffset varchar(8), @SlotNo varchar(4)

SELECT
@VLFSeqNo       = PARSENAME(REPLACE(@LSN_Hex, ':', '.'), 3),
@LogBlockOffset = PARSENAME(REPLACE(@LSN_Hex, ':', '.'), 2),
@SlotNo         = PARSENAME(REPLACE(@LSN_Hex, ':', '.'), 1)

DECLARE @LSN_Restore varchar(30)
SELECT @LSN_Restore =
  RIGHT('0000000000' + CAST(CONVERT(bigint, CONVERT(varbinary(8), @VLFSeqNo, 2)) AS varchar(10)), 10) +
  RIGHT('0000000000' + CAST(CONVERT(bigint, CONVERT(varbinary(8), @LogBlockOffset, 2)) AS varchar(10)), 10) +
  RIGHT('00000'      + CAST(CONVERT(bigint, CONVERT(varbinary(8), @SlotNo, 2)) AS varchar(5)), 5)

SELECT @LSN_Hex AS LSN_fn_dblog, 'lsn:' + @LSN_Restore AS LSN_Para_StopBeforeMark
go
-- lsn:0000000045000000052800001

/****************************************************************************
 Restaurando ATÉ ANTES do DROP (point-in-time via STOPBEFOREMARK)
 - Rodar sempre em cópia separada, jamais sobrescrever produção!
*****************************************************************************/

-- Fecha a cadeia com um segundo log backup (agora inclui o DROP)
BACKUP LOG HandsOn_Transacao TO DISK = 'E:\_Lives\Backup\HandsOn_Transacao_Log2.trn'
WITH noinit, compression
go

-- Restore
RESTORE DATABASE HandsOn_Transacao_Restaurado FROM DISK = 'E:\_Lives\Backup\HandsOn_Transacao_Full.bak' 
WITH norecovery, replace,
MOVE 'HandsOn_Transacao' TO 'E:\MSSQL_Data\HandsOn_Transacao_Restaurado.mdf',
MOVE 'HandsOn_Transacao_log' TO 'F:\MSSQL_Data\HandsOn_Transacao_Restaurado_log.ldf'
go

RESTORE LOG HandsOn_Transacao_Restaurado FROM DISK = 'E:\_Lives\Backup\HandsOn_Transacao_Log1.trn' 
WITH norecovery
go

-- Ponto crítico: parar ANTES da LSN do DROP (usar o valor gerado na Parte 2)
RESTORE LOG HandsOn_Transacao_Restaurado FROM DISK = 'E:\_Lives\Backup\HandsOn_Transacao_Log2.trn'
WITH norecovery, 
stopbeforemark = 'lsn:0000000045000000052800001' -- <<< SUBSTITUIR por @LSN_Restore
go

RESTORE DATABASE HandsOn_Transacao_Restaurado WITH recovery
go

-- Validação: a tabela Pedido deve existir novamente, com os 500 registros originais
SELECT count(*) AS QtdPedidos FROM HandsOn_Transacao_Restaurado.dbo.Pedido



/****************************************************************************
 Lendo o CONTEÚDO DO BACKUP diretamente com sys.fn_dump_dblog
 - Útil quando a porção ativa já foi truncada)

 ATENÇÃO:
 - fn_dump_dblog é bem mais lenta/pesada que fn_dblog;
 - A quantidade de parâmetros DEFAULT varia por build/versão;
*****************************************************************************/

SELECT [Current LSN], [Operation], [Context], [Transaction ID], [Description], [Transaction Name]
FROM fn_dump_dblog(
  NULL, NULL, N'DISK', 1, N'E:\_Lives\Backup\HandsOn_Transacao_Log2.trn',
  DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,
  DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,
  DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,
  DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,
  DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,
  DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,
  DEFAULT,DEFAULT,DEFAULT)
WHERE [Transaction Name] = 'DROPOBJ'


/*********************
 Remove bancos
**********************/
use master
go

ALTER DATABASE HandsOn_Transacao SET READ_ONLY WITH ROLLBACK IMMEDIATE
go
DROP DATABASE HandsOn_Transacao
go
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = 'HandsOn_Transacao'
go

ALTER DATABASE HandsOn_Transacao_Restaurado SET READ_ONLY WITH ROLLBACK IMMEDIATE
go
DROP DATABASE HandsOn_Transacao_Restaurado
go
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = 'HandsOn_Transacao_Restaurado'
go