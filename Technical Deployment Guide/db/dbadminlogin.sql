use master;
go

CREATE LOGIN [dbadmin] WITH PASSWORD = 'db1Admin''sPass';
go

use pricingdemo;
go

CREATE USER [dbadmin] FOR LOGIN [dbadmin];
go

EXEC sp_addrolemember 'db_owner', 'dbadmin';
go