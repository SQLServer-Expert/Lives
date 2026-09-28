/**********************************************************************
 Palestra: Os Maiores Erros de Query Tuning no SQL Server:
           Nem Sempre é Falta de Índice

 Evento: MVP Conf 2026
 Palestrante: Prof. Landry Duailibe
 Tema deste script: Conversão implícita

 Repositório:
 https://github.com/LandryDSF/MVPConf2026-Maiores-Erros-Query-Tuning

 Este script faz parte do material demonstrativo da palestra.
 Pode ser utilizado, modificado e distribuído conforme os termos 
 da licença MIT.

***********************************************************************/
use HandsOn_MVP2026
go

set statistics io on


/***********************************************************
 - Problema de desempenho com conversão implícita
************************************************************/
--DROP INDEX dbo.SalesOrderHeader.IX_SalesOrderHeader_SalesOrderNumber
CREATE INDEX IX_SalesOrderHeader_SalesOrderNumber
ON dbo.SalesOrderHeader (SalesOrderNumber)
INCLUDE (SalesOrderID, OrderDate, Status)


SELECT SalesOrderID, OrderDate, Status
FROM dbo.SalesOrderHeader
WHERE SalesOrderNumber = 53683
-- Index Scan: Table 'SalesOrderHeader'. Scan count 7, logical reads 65101 x 8kb = 520.808 kb = 508 MB

SELECT SalesOrderID, OrderDate, Status
FROM dbo.SalesOrderHeader
WHERE SalesOrderNumber = N'53683'
-- Index Seek: Table 'SalesOrderHeader'. Scan count 1, logical reads 6 x 8kb = 48 kb

DROP INDEX dbo.SalesOrderHeader.IX_SalesOrderHeader_SalesOrderNumber


/***********************************************************
 Operação Aritmética em Coluna
************************************************************/
--DROP INDEX dbo.SalesOrderHeader.IX_SalesOrderHeader_Freight
CREATE INDEX IX_SalesOrderHeader_Freight
ON dbo.SalesOrderHeader (Freight)
INCLUDE (SalesOrderNumber, OrderDate, Status)


-- Consulta
SELECT SalesOrderID, Freight * 2.5 as Freight_Formula,SalesOrderNumber, 
OrderDate, Status
FROM dbo.SalesOrderHeader
WHERE Freight * 2.5 >= 10000
-- Index Scan: Table 'SalesOrderHeader'. Scan count 7, logical reads 80650 x 8kb = 645.200 kb = 630 MB

-- Reescrita
SELECT SalesOrderID, Freight * 2.5 as Freight_Formula,SalesOrderNumber, 
OrderDate, Status
FROM dbo.SalesOrderHeader
WHERE Freight >= 10000 / 2.5
-- Index Seek: Table 'SalesOrderHeader'. Scan count 1, logical reads 22 x 8kb = 176 kb

DROP INDEX dbo.SalesOrderHeader.IX_SalesOrderHeader_Freight



/**************************************
 Expressão com mais de uma coluna
***************************************/
CREATE INDEX IX_SalesOrderHeader_SubTotal_Freight
ON dbo.SalesOrderHeader (SubTotal,Freight)
INCLUDE (SalesOrderNumber, OrderDate, Status)


SELECT SalesOrderID, SubTotal + Freight as Total,SalesOrderNumber, 
OrderDate, Status
FROM dbo.SalesOrderHeader
WHERE SubTotal + Freight  < 2
-- 501
-- Index Scan: Table 'SalesOrderHeader'. Scan count 7, logical reads 96883 x 8kb = 775.064 kb = 756 MB


ALTER TABLE dbo.SalesOrderHeader ADD Total as (SubTotal + Freight) --persisted

CREATE INDEX IX_SalesOrderHeader_Total
ON dbo.SalesOrderHeader (Total)
INCLUDE (SalesOrderNumber, OrderDate, Status)

SELECT SalesOrderID, SubTotal + Freight as Total,SalesOrderNumber, 
OrderDate, Status
FROM dbo.SalesOrderHeader
WHERE SubTotal + Freight  < 2
-- Table 'SalesOrderHeader'. Scan count 1, logical reads 6 x 8kb = 48 kb

