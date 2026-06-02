USE master;
GO

RESTORE DATABASE AdventureWorks2022
FROM DISK = '/var/opt/mssql/backup/AdventureWorks2022.bak'
WITH MOVE 'AdventureWorks2022' TO '/var/opt/mssql/data/AdventureWorks2022.mdf',
MOVE 'AdventureWorks2022_Log' TO '/var/opt/mssql/data/AdventureWorks2022_log.ldf';
GO

/* ===========================================================================
   MINI ETL PROJECT: AdventureWorks2022 -> DWDB
   Student Name: [Your Name]
   =========================================================================== */



-- 0. CLEANUP (Start Fresh)
IF OBJECT_ID('FactSales') IS NOT NULL DROP TABLE FactSales;
IF OBJECT_ID('DimCustomer') IS NOT NULL DROP TABLE DimCustomer;
IF OBJECT_ID('DimProduct') IS NOT NULL DROP TABLE DimProduct;
IF OBJECT_ID('DimDate') IS NOT NULL DROP TABLE DimDate;
GO

-- ===========================================================================
-- TASK 1: CREATE TABLES
-- ===========================================================================

-- 1. DimCustomer
CREATE TABLE DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT,
    FullName NVARCHAR(150),
    Region NVARCHAR(50)
);

SELECT * FROM DimCustomer;

-- 2. DimProduct
CREATE TABLE DimProduct (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT,
    ProductName NVARCHAR(50),
    SubCategoryName NVARCHAR(50),
    CategoryName NVARCHAR(50)
);

SELECT * FROM DimProduct;
-- 3. DimDate
CREATE TABLE DimDate (
    DateKey INT PRIMARY KEY,
    FullDate DATE,
    Year INT,
    Month INT
);

SELECT * FROM DimDate;

CREATE TABLE FactSales (
    SalesKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerKey INT FOREIGN KEY REFERENCES DimCustomer(CustomerKey),
    ProductKey INT FOREIGN KEY REFERENCES DimProduct(ProductKey),
    DateKey INT FOREIGN KEY REFERENCES DimDate(DateKey),
    OrderDate DATE,
    TotalAmount MONEY
);
GO
SELECT * FROM FactSales;
-- TASK 2, 3, 4: EXTRACT, TRANSFORM, LOAD

-- A. CUSTOMER (Join, Concat Name, Upper Region)
INSERT INTO DimCustomer (CustomerID, FullName, Region)
SELECT 
    c.CustomerID,
    ISNULL(p.FirstName, '') + ' ' + ISNULL(p.LastName, ''),
    UPPER(st.Name)
FROM AdventureWorks2022.Sales.Customer c
LEFT JOIN AdventureWorks2022.Person.Person p ON c.PersonID = p.BusinessEntityID
LEFT JOIN AdventureWorks2022.Sales.SalesTerritory st ON c.TerritoryID = st.TerritoryID;

-- SCREENSHOT 1: First 10 rows of DimCustomer
SELECT TOP 10 * FROM DimCustomer;
GO

-- B. PRODUCT (Join, Trim Name, Handle Nulls)
INSERT INTO DimProduct (ProductID, ProductName, SubCategoryName, CategoryName)
SELECT 
    p.ProductID,
    LTRIM(RTRIM(p.Name)),
    ISNULL(ps.Name, 'N/A'),
    ISNULL(pc.Name, 'N/A')
FROM AdventureWorks2022.Production.Product p
LEFT JOIN AdventureWorks2022.Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN AdventureWorks2022.Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID;

-- SCREENSHOT 2: First 10 rows of DimProduct
SELECT TOP 10 * FROM DimProduct;
GO

-- C. DATE (Extract DateKey, Year, Month)
INSERT INTO DimDate (DateKey, FullDate, Year, Month)
SELECT DISTINCT 
    CAST(CONVERT(VARCHAR(8), OrderDate, 112) AS INT),
    CAST(OrderDate AS DATE),
    YEAR(OrderDate),
    MONTH(OrderDate)
FROM AdventureWorks2022.Sales.SalesOrderHeader;

-- SCREENSHOT 3: First 10 rows of DimDate
SELECT TOP 10 * FROM DimDate;
GO

-- D. FACT SALES (Join Header+Detail, Calc Total, Lookups)
INSERT INTO FactSales (CustomerKey, ProductKey, DateKey, OrderDate, TotalAmount)
SELECT 
    dc.CustomerKey,
    dp.ProductKey,
    dd.DateKey,
    h.OrderDate,
    d.LineTotal
FROM AdventureWorks2022.Sales.SalesOrderDetail d
JOIN AdventureWorks2022.Sales.SalesOrderHeader h ON d.SalesOrderID = h.SalesOrderID
JOIN DimCustomer dc ON h.CustomerID = dc.CustomerID
JOIN DimProduct dp ON d.ProductID = dp.ProductID
JOIN DimDate dd ON CAST(CONVERT(VARCHAR(8), h.OrderDate, 112) AS INT) = dd.DateKey;

-- SCREENSHOT 4: First 10 rows of FactSales
SELECT TOP 10 * FROM FactSales;
GO


-- TASK 5: VALIDATION (Row Counts & Null Checks)

SELECT 'Row Counts' as Validation_Type, 
(SELECT COUNT(*) FROM DimCustomer) as Customers,
(SELECT COUNT(*) FROM DimProduct) as Products,
(SELECT COUNT(*) FROM FactSales) as Sales;

-- Ensure NO NULL Foreign Keys (Should be 0)
SELECT 'Null Key Check' as Validation_Type,
(SELECT COUNT(*) FROM FactSales WHERE CustomerKey IS NULL) as Null_Customers,
(SELECT COUNT(*) FROM FactSales WHERE ProductKey IS NULL) as Null_Products,
(SELECT COUNT(*) FROM FactSales WHERE DateKey IS NULL) as Null_Dates;
GO

