/* ===========================================================================
   MINI ETL PROJECT: STEP-BY-STEP (Create -> Insert -> Select)
   =========================================================================== */
-- 0. CLEANUP: Drop all tables first so we can start fresh
IF OBJECT_ID('FactSales') IS NOT NULL DROP TABLE FactSales;
IF OBJECT_ID('DimCustomer') IS NOT NULL DROP TABLE DimCustomer;
IF OBJECT_ID('DimProduct') IS NOT NULL DROP TABLE DimProduct;
IF OBJECT_ID('DimDate') IS NOT NULL DROP TABLE DimDate;
GO

PRINT '==================================================';
PRINT '1. PROCESSING CUSTOMER TABLE';
PRINT '==================================================';

-- 1A. Create DimCustomer
CREATE TABLE DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT,
    FullName NVARCHAR(150),
    Region NVARCHAR(50)
);

-- 1B. Insert Data into DimCustomer
INSERT INTO DimCustomer (CustomerID, FullName, Region)
SELECT 
    c.CustomerID,
    ISNULL(p.FirstName, '') + ' ' + ISNULL(p.LastName, ''),
    UPPER(st.Name)
FROM AdventureWorks2022.Sales.Customer c
LEFT JOIN AdventureWorks2022.Person.Person p ON c.PersonID = p.BusinessEntityID
LEFT JOIN AdventureWorks2022.Sales.SalesTerritory st ON c.TerritoryID = st.TerritoryID;

-- 1C. Select Data from DimCustomer (Show Result)
SELECT * FROM DimCustomer;
GO


PRINT '==================================================';
PRINT '2. PROCESSING PRODUCT TABLE';
PRINT '==================================================';

-- 2A. Create DimProduct
CREATE TABLE DimProduct (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT,
    ProductName NVARCHAR(50),
    SubCategoryName NVARCHAR(50),
    CategoryName NVARCHAR(50)
);

-- 2B. Insert Data into DimProduct
INSERT INTO DimProduct (ProductID, ProductName, SubCategoryName, CategoryName)
SELECT 
    p.ProductID,
    LTRIM(RTRIM(p.Name)),
    ISNULL(ps.Name, 'N/A'),
    ISNULL(pc.Name, 'N/A')
FROM AdventureWorks2022.Production.Product p
LEFT JOIN AdventureWorks2022.Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN AdventureWorks2022.Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID;

-- 2C. Select Data from DimProduct (Show Result)
SELECT * FROM DimProduct;
GO


PRINT '==================================================';
PRINT '3. PROCESSING DATE TABLE';
PRINT '==================================================';

-- 3A. Create DimDate
CREATE TABLE DimDate (
    DateKey INT PRIMARY KEY,
    FullDate DATE,
    Year INT,
    Month INT
);

-- 3B. Insert Data into DimDate
INSERT INTO DimDate (DateKey, FullDate, Year, Month)
SELECT DISTINCT 
    CAST(CONVERT(VARCHAR(8), OrderDate, 112) AS INT),
    CAST(OrderDate AS DATE),
    YEAR(OrderDate),
    MONTH(OrderDate)
FROM AdventureWorks2022.Sales.SalesOrderHeader;

-- 3C. Select Data from DimDate (Show Result)
SELECT * FROM DimDate;
GO


PRINT '==================================================';
PRINT '4. PROCESSING FACT SALES TABLE';
PRINT '==================================================';

-- 4A. Create FactSales
CREATE TABLE FactSales (
    SalesKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerKey INT FOREIGN KEY REFERENCES DimCustomer(CustomerKey),
    ProductKey INT FOREIGN KEY REFERENCES DimProduct(ProductKey),
    DateKey INT FOREIGN KEY REFERENCES DimDate(DateKey),
    OrderDate DATE,
    TotalAmount MONEY
);

-- 4B. Insert Data into FactSales
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

-- 4C. Select Data from FactSales (Show Result)
SELECT TOP 10 * FROM FactSales;
GO