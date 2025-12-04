/************************************************************
 Autor: Landry Duailibe
 LIVE #005

 - Permissões
*************************************************************/
USE master
go


CREATE LOGIN Ana WITH PASSWORD=N'1234', CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
CREATE LOGIN Jose WITH PASSWORD=N'1234', CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF

/**********************************************
 1o Nível: Instância
***********************************************/

-- Role
ALTER SERVER ROLE dbcreator ADD MEMBER Ana

ALTER SERVER ROLE dbcreator DROP MEMBER Ana

-- Troca o contexto da conexão para o Login Ana
EXECUTE AS LOGIN = 'Ana'
SELECT SUSER_SNAME()

CREATE DATABASE DB_Ana

-- Retorna o contexto da conexão para o Login original
REVERT

DROP DATABASE DB_Ana

-- Atribui direito para cirar novos bancos para Login Ana
GRANT CREATE ANY DATABASE TO Ana


-- Troca o contexto da conexão para o Login Ana
EXECUTE AS LOGIN = 'Ana'
SELECT SUSER_SNAME()

CREATE DATABASE DB_Ana

-- Retorna o contexto da conexão para o Login original
REVERT

/**********************************************
 2o Nível: Banco de Dados
***********************************************/
use DB_Ana
go

DROP TABLE IF exists dbo.Funcionarios
go
CREATE TABLE dbo.Funcionarios (PK int Primary key, Nome varchar(50), Descricao varchar(100), Status char(1),Salario decimal(10,2))
INSERT Funcionarios VALUES (1,'Fernando','Gerente','B',5600.00)
INSERT Funcionarios VALUES (2,'Ana Maria','Diretor','A',7500.00)
INSERT Funcionarios VALUES (3,'Lucia','Gerente','B',5600.00)
INSERT Funcionarios VALUES (4,'Pedro','Operacional','C',2600.00)
INSERT Funcionarios VALUES (5,'Carlos','Diretor','A',7500.00)
INSERT Funcionarios VALUES (6,'Carol','Operacional','C',2600.00)
INSERT Funcionarios VALUES (7,'Luana','Operacional','C',2600.00)
INSERT Funcionarios VALUES (8,'Lula','Diretor','A',7500.00)
INSERT Funcionarios VALUES (9,'Erick','Operacional','C',2600.00)
INSERT Funcionarios VALUES (10,'Joana','Operacional','C',2600.00)
go




GRANT SELECT ON dbo.Funcionarios TO Jose


-- Troca o contexto da conexão para o Login Jose
EXECUTE AS LOGIN = 'Jose'
SELECT SUSER_SNAME()

SELECT * FROM dbo.Funcionarios

-- Retorna o contexto da conexão para o Login original
REVERT

-- Exclui Logins
use master
go
DROP DATABASE DB_Ana
DROP LOGIN Ana
DROP LOGIN Jose
