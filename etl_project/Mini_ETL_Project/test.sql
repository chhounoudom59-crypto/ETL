
SELECT 
    c.CustomerKey,
    c.FullName AS Customer,  -- You already combined names in your ETL script
    ROW_NUMBER() OVER (
        ORDER BY c.CustomerKey
    ) AS RowNum
FROM
    FactSales f              -- Use the table name you created
JOIN
    DimCustomer c ON f.CustomerKey = c.CustomerKey;


-- task 1
WITH CustomerOrder AS (
    SELECT 
        c.CustomerKey,
        c.FullName AS Customer,  -- You only have 'FullName' in your table
        f.OrderDate,
        f.TotalAmount,           -- You named this 'TotalAmount', not 'SalesAmount'
        ROW_NUMBER() OVER (
            PARTITION BY c.CustomerKey
            ORDER BY f.OrderDate -- You can order by the date directly
        ) AS RowNum
    FROM
        FactSales f              -- You named this 'FactSales'
    JOIN
        DimCustomer c ON f.CustomerKey = c.CustomerKey
)
SELECT * FROM CustomerOrder
WHERE RowNum = 1;





USE AdventureWorks2022;
GO

SELECT 
    c.CustomerID,
    p.FirstName + ' ' + p.LastName AS Customer,
    ROW_NUMBER() OVER (ORDER BY c.CustomerID) AS RowNum
FROM Sales.SalesOrderHeader h
INNER JOIN Sales.Customer c ON h.CustomerID = c.CustomerID
INNER JOIN Person.Person p ON c.PersonID = p.BusinessEntityID;


USE AdventureWorks2022; -- MUST run this first
GO

SELECT 
    c.CustomerID,
    p.FirstName + ' ' + p.LastName AS Customer,
    ROW_NUMBER() OVER (ORDER BY c.CustomerID) AS RowNum
FROM Sales.SalesOrderHeader h
INNER JOIN Sales.Customer c ON h.CustomerID = c.CustomerID
INNER JOIN Person.Person p ON c.PersonID = p.BusinessEntityID;




USE DWDB; -- MUST run this first
GO

SELECT 
    c.CustomerKey,
    c.FullName AS Customer,
    ROW_NUMBER() OVER (
        ORDER BY c.CustomerKey
    ) AS RowNum
FROM
    FactSales f
JOIN
    DimCustomer c ON f.CustomerKey = c.CustomerKey;



USE DWDB;
GO

SELECT TOP 3
    p.ProductName,
    SUM(f.TotalAmount) AS TotalSales
FROM 
    FactSales f
JOIN 
    DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY 
    p.ProductName
ORDER BY 
    TotalSales DESC;


-- task 1
SELECT TOP 3
    d.Year,
    DATENAME(month, DATEFROMPARTS(d.Year, d.Month, 1)) AS MonthName, -- Converts 12 -> 'December'
    SUM(f.TotalAmount) AS TotalSales
FROM FactSales f
JOIN DimDate d ON f.DateKey = d.DateKey
GROUP BY d.Year, d.Month
ORDER BY TotalSales DESC;


USE DWDB;
GO

SELECT TOP 3
    d.Year,
    d.Month,
    DATENAME(month, DATEFROMPARTS(d.Year, d.Month, 1)) AS MonthName,
    SUM(f.TotalAmount) AS TotalSales
FROM FactSales f
JOIN DimDate d ON f.DateKey = d.DateKey
GROUP BY d.Year, d.Month
-- Change is here: Sort by latest Date, not highest Sales
ORDER BY d.Year DESC, d.Month DESC;




-- 1. Find the very last date recorded in your data
DECLARE @MaxDate DATE;
SELECT @MaxDate = MAX(FullDate) 
FROM FactSales f
JOIN DimDate d ON f.DateKey = d.DateKey;

PRINT 'Filtering for 3 months ending on: ' + CAST(@MaxDate AS VARCHAR);

-- 2. Find the Top 10 Products in that range
SELECT TOP 10
    p.ProductName,
    SUM(f.TotalAmount) AS TotalSales
FROM 
    FactSales f
JOIN 
    DimProduct p ON f.ProductKey = p.ProductKey
JOIN 
    DimDate d ON f.DateKey = d.DateKey
WHERE 
    d.FullDate >= DATEADD(MONTH, -3, @MaxDate) -- The "Last 3 Months" Logic
GROUP BY 
    p.ProductName
ORDER BY 
    TotalSales DESC;




-- 1. Find the Last Date in your data
DECLARE @LastDate DATE = (SELECT MAX(FullDate) FROM DimDate 
                          WHERE DateKey IN (SELECT DISTINCT DateKey FROM FactSales));

-- 2. Calculate the Start Date (3 months back)
DECLARE @StartDate DATE = DATEADD(MONTH, -3, @LastDate);

-- 3. Display the range
PRINT '--------------------------------------------------';
PRINT 'CHECKING TIME RANGE';
PRINT 'Data Ends On: '   + CAST(@LastDate AS VARCHAR);
PRINT '3 Months Back: '  + CAST(@StartDate AS VARCHAR);
PRINT '--------------------------------------------------';

-- 4. List the specific months found in that gap
SELECT DISTINCT 
    d.Year, 
    d.Month, 
    DATENAME(MONTH, d.FullDate) AS MonthName
FROM FactSales f
JOIN DimDate d ON f.DateKey = d.DateKey
WHERE d.FullDate > @StartDate 
  AND d.FullDate <= @LastDate
ORDER BY d.Year DESC, d.Month DESC;


SELECT TOP 10 
    p.ProductName, 
    SUM(f.TotalAmount) AS TotalSales
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
JOIN DimDate d    ON f.DateKey = d.DateKey
WHERE d.FullDate >= DATEADD(MONTH, -3, (SELECT MAX(d2.FullDate) FROM FactSales f2 JOIN DimDate d2 ON f2.DateKey = d2.DateKey))
GROUP BY p.ProductName
ORDER BY TotalSales DESC;


USE DWDB;
GO

SELECT TOP 5 PERCENT 
    c.FullName,
    SUM(f.TotalAmount) AS TotalSpent
FROM 
    FactSales f
JOIN 
    DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY 
    c.FullName
ORDER BY 
    TotalSpent DESC;


-- 1. Find the total sales amount across all customers
USE DWDB;
GO

WITH CustomerSpending AS (
    -- 1. Calculate Total Spend per Customer
    SELECT 
        c.FullName,
        SUM(f.TotalAmount) AS TotalSpent
    FROM 
        FactSales f
    JOIN 
        DimCustomer c ON f.CustomerKey = c.CustomerKey
    GROUP BY 
        c.FullName
),
RankedCustomers AS (
    -- 2. Calculate the Percentile Rank
    SELECT 
        FullName,
        TotalSpent,
        -- Returns a value between 0 and 1 (1 = Highest Spender)
        PERCENT_RANK() OVER (ORDER BY TotalSpent ASC) AS PctRank
    FROM 
        CustomerSpending
)
-- 3. Filter for the Top 5% (Rank >= 0.95)
SELECT 
    FullName,
    TotalSpent,
    PctRank
FROM 
    RankedCustomers
WHERE 
    PctRank >= 0.95
ORDER BY 
    TotalSpent DESC;



USE DWDB;
GO

SELECT * FROM (
    SELECT 
        c.FullName,
        SUM(f.TotalAmount) AS TotalSpent,
        PERCENT_RANK() OVER (ORDER BY SUM(f.TotalAmount) ASC) AS PctRank
    FROM FactSales f
    JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey
    GROUP BY c.FullName
) AS RankedData
WHERE PctRank >= 0.95
ORDER BY TotalSpent DESC;


USE DWDB;
GO

SELECT TOP 5
    p1.ProductName AS Product_A,
    p2.ProductName AS Product_B,
    COUNT(*) AS TimesBoughtTogether
FROM 
    FactSales f1
-- 1. Self-Join: Connect the table to itself
JOIN 
    FactSales f2 
    ON f1.CustomerKey = f2.CustomerKey -- Same Customer
    AND f1.DateKey = f2.DateKey        -- Same Day
    AND f1.ProductKey < f2.ProductKey  -- Vital: Prevents duplicates (A-B vs B-A) and self-matches (A-A)
-- 2. Get Product Names
JOIN 
    DimProduct p1 ON f1.ProductKey = p1.ProductKey
JOIN 
    DimProduct p2 ON f2.ProductKey = p2.ProductKey
-- 3. Group and Count
GROUP BY 
    p1.ProductName, 
    p2.ProductName
ORDER BY 
    TimesBoughtTogether DESC;