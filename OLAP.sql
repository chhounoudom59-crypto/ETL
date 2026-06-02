-- Change this to your actual database name
USE AdventureWorks2022; 
GO

SELECT
    YEAR(OrderDate) AS OrderYear,
    MONTH(OrderDate) AS OrderMonth,
    pc.Name AS ProductCategory,
    p.Name AS ProductName,
    st.Name AS Territory,
    SUM(sod.LineTotal) AS SalesAmount,
    SUM(sod.OrderQty) AS OrderQuantity
FROM Sales.SalesOrderDetail sod
JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
GROUP BY
    YEAR(OrderDate),
    MONTH(OrderDate),
    pc.Name,
    p.Name,
    st.Name
ORDER BY OrderYear, OrderMonth;


SELECT name FROM sys.databases;