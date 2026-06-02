/*
===========================================================================
Mini ETL Project: AdventureWorks2022 -> DWDB
Date: 2023-10-27
Author: [Your Name]
Description: Extracts data from OLTP, Transforms it, and Loads into DW.
===========================================================================
*/

-- 0. SETUP: Create the Data Warehouse Database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'DWDB')
BEGIN
    CREATE DATABASE DWDB;
END
GO

USE DWDB;
GO

/*
===========================================================================
TASK 1: CREATE THE 4 DW TABLES
===========================================================================
*/

-- 1.1 DimCustomer
IF OBJECT_ID('DimCustomer', 'U') IS NOT NULL DROP TABLE DimCustomer;
CREATE TABLE DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    CustomerID INT,                            -- Business Key (from Source)
    FullName NVARCHAR(150),
    Region NVARCHAR(50)
);

-- 1.2 DimProduct
IF OBJECT_ID('DimProduct', 'U') IS NOT NULL DROP TABLE DimProduct;
CREATE TABLE DimProduct (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    ProductID INT,                            -- Business Key
    ProductName NVARCHAR(50),
    SubCategoryName NVARCHAR(50),
    CategoryName NVARCHAR(50)
);

-- 1.3 DimDate
IF OBJECT_ID('DimDate', 'U') IS NOT NULL DROP TABLE DimDate;
CREATE TABLE DimDate (
    DateKey INT PRIMARY KEY, -- Format: YYYYMMDD
    FullDate DATE,
    Year INT,
    Month INT
);

-- 1.4 FactSales
IF OBJECT_ID('FactSales', 'U') IS NOT NULL DROP TABLE FactSales;
CREATE TABLE FactSales (
    SalesKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerKey INT FOREIGN KEY REFERENCES DimCustomer(CustomerKey),
    ProductKey INT FOREIGN KEY REFERENCES DimProduct(ProductKey),
    DateKey INT FOREIGN KEY REFERENCES DimDate(DateKey),
    OrderDate DATE,
    TotalAmount MONEY
);
GO

/*
===========================================================================
TASK 2 & 3 & 4: EXTRACT, TRANSFORM, AND LOAD (ETL)
Strategies used:
- INSERT INTO ... SELECT ... FROM Source
- Transformations applied directly in the SELECT list
===========================================================================
*/

PRINT 'Starting ETL Process...';

-- ---------------------------------------------------------
-- LOAD DimCustomer
-- Transformation: Join Customer+Person+Territory, Upper(Region), Concat Name
-- ---------------------------------------------------------
INSERT INTO DimCustomer (CustomerID, FullName, Region)
SELECT 
    c.CustomerID,
    ISNULL(p.FirstName, '') + ' ' + ISNULL(p.LastName, '') AS FullName,
    UPPER(st.Name) AS Region
FROM AdventureWorks2022.Sales.Customer c
LEFT JOIN AdventureWorks2022.Person.Person p 
    ON c.PersonID = p.BusinessEntityID
LEFT JOIN AdventureWorks2022.Sales.SalesTerritory st 
    ON c.TerritoryID = st.TerritoryID;

PRINT 'DimCustomer Loaded: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';


-- ---------------------------------------------------------
-- LOAD DimProduct
-- Transformation: Join Product+Sub+Cat, Trim Names
-- ---------------------------------------------------------
INSERT INTO DimProduct (ProductID, ProductName, SubCategoryName, CategoryName)
SELECT 
    p.ProductID,
    LTRIM(RTRIM(p.Name)) AS ProductName,
    ISNULL(ps.Name, 'N/A') AS SubCategoryName,
    ISNULL(pc.Name, 'N/A') AS CategoryName
FROM AdventureWorks2022.Production.Product p
LEFT JOIN AdventureWorks2022.Production.ProductSubcategory ps 
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN AdventureWorks2022.Production.ProductCategory pc 
    ON ps.ProductCategoryID = pc.ProductCategoryID;

PRINT 'DimProduct Loaded: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';


-- ---------------------------------------------------------
-- LOAD DimDate
-- Transformation: distinct dates from orders, formatted YYYYMMDD
-- ---------------------------------------------------------
INSERT INTO DimDate (DateKey, FullDate, Year, Month)
SELECT DISTINCT 
    CAST(CONVERT(VARCHAR(8), OrderDate, 112) AS INT) AS DateKey, -- YYYYMMDD
    CAST(OrderDate AS DATE) AS FullDate,
    YEAR(OrderDate) AS Year,
    MONTH(OrderDate) AS Month
FROM AdventureWorks2022.Sales.SalesOrderHeader;

PRINT 'DimDate Loaded: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';


-- ---------------------------------------------------------
-- LOAD FactSales
-- Transformation: Join Header+Detail, Calc Totals, Lookup Keys
-- ---------------------------------------------------------
INSERT INTO FactSales (CustomerKey, ProductKey, DateKey, OrderDate, TotalAmount)
SELECT 
    dc.CustomerKey,
    dp.ProductKey,
    dd.DateKey,
    h.OrderDate,
    d.LineTotal AS TotalAmount
FROM AdventureWorks2022.Sales.SalesOrderDetail d
JOIN AdventureWorks2022.Sales.SalesOrderHeader h 
    ON d.SalesOrderID = h.SalesOrderID
-- LOOKUP Customer Key
JOIN DimCustomer dc 
    ON h.CustomerID = dc.CustomerID
-- LOOKUP Product Key
JOIN DimProduct dp 
    ON d.ProductID = dp.ProductID
-- LOOKUP Date Key
JOIN DimDate dd 
    ON CAST(CONVERT(VARCHAR(8), h.OrderDate, 112) AS INT) = dd.DateKey;

PRINT 'FactSales Loaded: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';
GO

/*
===========================================================================
TASK 5: VALIDATE
===========================================================================
*/

PRINT '---------------------------------------------------'
PRINT 'VALIDATION REPORT'
PRINT '---------------------------------------------------'

-- 5.1 Row Counts
SELECT 'DimCustomer' AS TableName, COUNT(*) AS Count FROM DimCustomer
UNION ALL
SELECT 'DimProduct', COUNT(*) FROM DimProduct
UNION ALL
SELECT 'DimDate', COUNT(*) FROM DimDate
UNION ALL
SELECT 'FactSales', COUNT(*) FROM FactSales;

-- 5.2 Check for NULL Foreign Keys in Fact Table (Orphan check)
SELECT 
    COUNT(*) AS NullCustomerKeys
FROM FactSales 
WHERE CustomerKey IS NULL;

SELECT 
    COUNT(*) AS NullProductKeys
FROM FactSales 
WHERE ProductKey IS NULL;

-- 5.3 Preview Data (Top 10)
-- Select top 10 from DimCustomer
SELECT TOP 10 * FROM DimCustomer;
-- Select top 10 from DimProduct
SELECT TOP 10 * FROM DimProduct;
-- Select top 10 from FactSales
SELECT TOP 10 * FROM FactSales;

GO

/*
===========================================================================
REFLECTION
===========================================================================

Why do we separate data into Dimensions and Facts in a Data Warehouse?

We separate data into Dimensions and Facts to optimize for analytical query performance and simplicity, a concept known as the Star Schema. 
Fact tables contain the quantitative metrics (like sales amount) and grow very large, while Dimension tables store the descriptive attributes (like customer name or product category) used for filtering and grouping. 
This separation reduces data redundancy (normalization of attributes) and allows business users to easily slice and dice data without writing complex joins against a highly normalized transactional system.
*/