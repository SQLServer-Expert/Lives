/**********************************************************************
 Palestra: Os Maiores Erros de Query Tuning no SQL Server:
           Nem Sempre é Falta de Índice

 Evento: MVP Conf 2026
 Palestrante: Prof. Landry Duailibe
 Tema deste script: Criando Tabelas

 Repositório:
 https://github.com/LandryDSF/MVPConf2026-Maiores-Erros-Query-Tuning

 Este script faz parte do material demonstrativo da palestra.
 Pode ser utilizado, modificado e distribuído conforme os termos 
 da licença MIT.

 Este script utiliza os dados do Banco AdventureWorks, utilizar
 o link abaixo para obter o banco:
 https://learn.microsoft.com/pt-br/sql/samples/adventureworks-install-configure

***********************************************************************/
USE master
go
CREATE DATABASE HandsOn_MVP2026
go
ALTER DATABASE HandsOn_MVP2026 SET RECOVERY simple
go


/******************************
 Cria tabelas para o Hands On
*******************************/
use HandsOn_MVP2026
go

set nocount on

/*********************
 Customer
**********************/
DROP TABLE IF exists dbo.Customer
go
CREATE TABLE dbo.Customer(
CustomerID int IDENTITY NOT NULL CONSTRAINT pk_Customer PRIMARY KEY,
FirstName nvarchar(50) NULL,
MiddleName nvarchar(50) NULL,
Lastname nvarchar(50) NULL,
PersonType nchar(900) NULL,
EmailPromotion int NULL,
Region varchar(2) NULL,
DataCadastro datetime NULL) 
go

INSERT dbo.Customer
(FirstName, MiddleName, Lastname, PersonType, EmailPromotion, Region, DataCadastro)

SELECT FirstName, MiddleName, Lastname, PersonType,
EmailPromotion, 'RJ' as Region, 
dateadd(d,-BusinessEntityID,getdate()) DataCadastro 
FROM AdventureWorks.Sales.Customer c 
JOIN AdventureWorks.Person.Person p ON p.BusinessEntityID = c.PersonID
go

INSERT dbo.Customer
(FirstName, MiddleName, Lastname, PersonType, EmailPromotion, Region, DataCadastro)

SELECT FirstName, MiddleName, Lastname, PersonType,
EmailPromotion, 'RJ' as Region, 
dateadd(d,-BusinessEntityID,getdate()) DataCadastro 
FROM AdventureWorks.Sales.Customer c 
JOIN AdventureWorks.Person.Person p ON p.BusinessEntityID = c.PersonID
WHERE FirstName not like 'G%'
go 50

/*********************
 SalesOrderHeader
**********************/
DROP TABLE IF exists dbo.SalesOrderHeader
go
CREATE TABLE dbo.SalesOrderHeader (
SalesOrderID int IDENTITY NOT NULL CONSTRAINT pk_SalesOrderHeader PRIMARY KEY,
RevisionNumber tinyint NOT NULL,
OrderDate datetime NOT NULL,
DueDate datetime NOT NULL,
ShipDate datetime NULL,
Status tinyint NOT NULL,
OnlineOrderFlag bit NOT NULL,
SalesOrderNumber nvarchar(25) NOT NULL,
PurchaseOrderNumber nvarchar(25) NULL,
AccountNumber nvarchar(15) NULL,
CustomerID int NOT NULL,
SalesPersonID int NULL,
SubTotal money NOT NULL,
TaxAmt money NOT NULL,
Freight money NOT NULL,
TotalDue money NOT NULL,
Comment nvarchar(128) NULL,
rowguid uniqueidentifier NOT NULL,
ModifiedDate datetime NOT NULL)
go

INSERT dbo.SalesOrderHeader
(RevisionNumber, 
OrderDate, DueDate, ShipDate, Status, OnlineOrderFlag, 
SalesOrderNumber, PurchaseOrderNumber, AccountNumber, CustomerID, SalesPersonID, SubTotal, TaxAmt, Freight, TotalDue, Comment, rowguid, ModifiedDate)
SELECT RevisionNumber, 
dateadd(second,abs(checksum(newid())) % 86400, OrderDate) as OrderDate, 
DueDate, ShipDate, Status, OnlineOrderFlag, 
replace(SalesOrderNumber,'SO','') as SalesOrderNumber, 
PurchaseOrderNumber, h.AccountNumber, h.CustomerID, 
SalesPersonID, SubTotal, TaxAmt, Freight, TotalDue, Comment, h.rowguid, h.ModifiedDate
FROM AdventureWorks.Sales.SalesOrderHeader h
go

INSERT dbo.SalesOrderHeader
(RevisionNumber, OrderDate, DueDate, ShipDate, Status, OnlineOrderFlag, SalesOrderNumber, PurchaseOrderNumber, AccountNumber, CustomerID, SalesPersonID, SubTotal, TaxAmt, Freight, TotalDue, Comment, rowguid, ModifiedDate)
SELECT RevisionNumber, 
dateadd(second,abs(checksum(newid())) % 86400, OrderDate) as OrderDate, 
DueDate, ShipDate, Status, OnlineOrderFlag, 
replace(SalesOrderNumber,'SO','') as SalesOrderNumber, 
PurchaseOrderNumber, h.AccountNumber, h.CustomerID, 
SalesPersonID, SubTotal, TaxAmt, Freight, TotalDue, Comment, h.rowguid, h.ModifiedDate
FROM AdventureWorks.Sales.SalesOrderHeader h
WHERE SalesOrderNumber not in ('43659','43660','43661','43662','43663')
go 500

/********************** Fim Cria Tabelas **************************/

EXEC sp_spaceused 'dbo.Customer'
-- 945.669 linhas / 1,8 GB

EXEC sp_spaceused 'dbo.SalesOrderHeader'
-- 15.763.965 linhas 2,3 GB


