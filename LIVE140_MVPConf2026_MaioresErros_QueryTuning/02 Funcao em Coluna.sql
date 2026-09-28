/**********************************************************************
 Palestra: Os Maiores Erros de Query Tuning no SQL Server:
           Nem Sempre é Falta de Índice

 Evento: MVP Conf 2026
 Palestrante: Prof. Landry Duailibe
 Tema deste script: Função em coluna

 Repositório:
 https://github.com/LandryDSF/MVPConf2026-Maiores-Erros-Query-Tuning

 Este script faz parte do material demonstrativo da palestra.
 Pode ser utilizado, modificado e distribuído conforme os termos 
 da licença MIT.

***********************************************************************/
use HandsOn_MVP2026
go

/***********************************************************
 Uso de Função em coluna
************************************************************/
set statistics io on

-- DROP INDEX dbo.Customer.IX_Customer_FirstName
CREATE INDEX IX_Customer_FirstName ON dbo.Customer (FirstName)
INCLUDE (CustomerID, LastName)







-- Função LEFT()
SELECT CustomerID, FirstName, LastName
FROM dbo.Customer WHERE left(FirstName,1) = 'A'
-- Clustered Index Scan = Table Scan -> Table 'Customer'. Scan count 7, logical reads 243983 x 8Kb = 1.951.864 Kb = 1,86 GB
-- Index Scan ------------------------> Table 'Customer'. Scan count 1, logical reads 4589 x 8kb = 36.712 Kb = 35 MB

-- Trocando por LIKE
SELECT CustomerID, FirstName, LastName --, DataCadastro
FROM dbo.Customer WHERE FirstName like 'A%'
-- Index Seek: Table 'Customer'. Scan count 1, logical reads 489 x 8kb = 3.912 KB

SELECT CustomerID, FirstName, LastName
FROM dbo.Customer WHERE FirstName like '%A%'
-- Index Scan: Table 'Customer'. Scan count 1, logical reads 4589 x 8kb = 36.712 Kb = 35 MB

-- UPPER()
SELECT CustomerID, FirstName, LastName
FROM dbo.Customer WHERE upper(FirstName) = 'LOLA'
-- Index Scan: Table 'Customer'. Scan count 1, logical reads 4589 x 8kb = 36.712 kb = 35 MB

SELECT CustomerID, FirstName, LastName
FROM dbo.Customer WHERE FirstName = 'Lola'
-- Index Seek: Table 'Customer'. Scan count 1, logical reads 4 x 8kb = 32 kb


DROP INDEX dbo.Customer.IX_Customer_FirstName

/***********************************************************
 - Uso de Função em coluna: CONVERT
************************************************************/

-- DROP INDEX dbo.SalesOrderHeader.IX_SalesOrderHeader_OrderDate
CREATE INDEX IX_SalesOrderHeader_OrderDate
ON dbo.SalesOrderHeader (OrderDate)
INCLUDE (SalesOrderID, CustomerID, TotalDue, ShipDate)

SELECT SalesOrderID, CustomerID, TotalDue, OrderDate, ShipDate
FROM dbo.SalesOrderHeader
WHERE OrderDate = '20110801'
-- zero linha

SELECT SalesOrderID, CustomerID, TotalDue, OrderDate, ShipDate
FROM dbo.SalesOrderHeader
WHERE convert(varchar(8),OrderDate,112) = '20110801'
-- 32.064 linhas
-- Index Scan -> Table 'SalesOrderHeader'. Scan count 7, logical reads 74.471 x 8kb = 595.768 Kb = 581 MB

SELECT SalesOrderID, CustomerID, TotalDue, OrderDate, ShipDate
FROM dbo.SalesOrderHeader
WHERE year(OrderDate) = 2011
-- 805.107 linhas
-- Index Scan: Table 'SalesOrderHeader'. Scan count 7, logical reads 74.786 x 8kb = 598.288 kb = 584 MB





-- Reescrita
SELECT SalesOrderID, CustomerID, TotalDue, OrderDate, ShipDate
FROM dbo.SalesOrderHeader
WHERE OrderDate >= '20110801' and OrderDate < '20110802'
-- 32.064 linhas
-- Table 'SalesOrderHeader'. Scan count 1, logical reads 154 x 8 kb = 1.232 kb


-- Reescrita
SELECT SalesOrderID, CustomerID, TotalDue, OrderDate, ShipDate
FROM dbo.SalesOrderHeader
WHERE OrderDate >= '20110101' and OrderDate < '20120101'
-- 805.107 linhas
-- Index Seek: Table 'SalesOrderHeader'. Scan count 1, logical reads 3792 x 8kb = 30.336 kb = 29 MB

DROP INDEX dbo.SalesOrderHeader.IX_SalesOrderHeader_OrderDate


