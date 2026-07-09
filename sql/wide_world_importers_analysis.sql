/*
  Project: SQL Data Analysis
  Dataset: WideWorldImporters sample database
  Context: This script was completed as part of a Data Analyst course project.
  Note: The assignment allowed partial task completion/submission.
  Public version: personal details were removed and comments were cleaned for GitHub.
  SQL logic: the query code below is kept in the original learning style.
*/

-- Task 1: Annual net income, yearly linear income, and growth rate
WITH YearAgg AS
(SELECT YEAR(I.InvoiceDate) AS [Year],
SUM(IL.ExtendedPrice - IL.TaxAmount) AS[IncomePerYear],
COUNT(DISTINCT MONTH(I.InvoiceDate)) AS [NumberOfDistinctMonths]
FROM Sales.Invoices I
JOIN Sales.InvoiceLines IL ON IL.InvoiceID = I.InvoiceID
GROUP BY YEAR(I.InvoiceDate)),
YearCalc AS
(SELECT [Year],IncomePerYear,NumberOfDistinctMonths,
CAST(IncomePerYear * 12.0 / NULLIF(NumberOfDistinctMonths, 0) AS decimal(18,2)) AS [YearlyLinearIncome]
FROM YearAgg)
SELECT [Year],IncomePerYear,NumberOfDistinctMonths,YearlyLinearIncome,
CAST(100.0 * (YearlyLinearIncome - LAG(YearlyLinearIncome) OVER (ORDER BY [Year])) / NULLIF(LAG(YearlyLinearIncome) OVER (ORDER BY [Year]), 0) AS decimal(18,2)) AS [GrowthRate]
FROM YearCalc
ORDER BY [Year]
/*
Task 1 explanation:
1. I used GROUP BY YEAR(InvoiceDate) to aggregate invoice line income by year.
2. I joined Sales.Invoices with Sales.InvoiceLines to calculate yearly net income using ExtendedPrice - TaxAmount.
3. I used COUNT(DISTINCT MONTH(InvoiceDate)) to count the number of active months in each year.
4. I used CTEs to keep the aggregation step and calculation step separated and easier to read.
5. I calculated YearlyLinearIncome by converting partial-year income into a 12-month estimate.
6. I used NULLIF to avoid division by zero and CAST to format numeric results as decimal values.
7. I used LAG to compare each year's linear income with the previous year and calculate GrowthRate.
8. The final result is ordered by year.
*/

-- Task 2: Top 5 customers by quarter based on net income
WITH SalesAgg AS
(SELECT YEAR(I.InvoiceDate) AS [TheYear],
DATEPART(QUARTER, I.InvoiceDate) AS [TheQuarter], I.CustomerID,
SUM(IL.ExtendedPrice - IL.TaxAmount) AS [NetAmount]
FROM Sales.Invoices I
JOIN Sales.InvoiceLines IL ON IL.InvoiceID = I.InvoiceID
GROUP BY YEAR(I.InvoiceDate),DATEPART(QUARTER, I.InvoiceDate), I.CustomerID),
RankedSales AS
(SELECT SA.[TheYear],SA.[TheQuarter],C.CustomerName,SA.[NetAmount],
DENSE_RANK() OVER(PARTITION BY SA.[TheYear],SA.[TheQuarter] ORDER BY SA.[NetAmount] DESC) AS [DNR]
FROM SalesAgg SA
LEFT JOIN Sales.Customers C ON C.CustomerID = SA.CustomerID)
SELECT [TheYear],[TheQuarter],CustomerName,[NetAmount],[DNR]
FROM RankedSales
WHERE [DNR] <=5
ORDER BY [TheYear],[TheQuarter],[DNR]
/*
Task 2 explanation:
1. I used YEAR(InvoiceDate) and DATEPART(QUARTER, InvoiceDate) to group sales by year and quarter.
2. I joined Sales.Invoices with Sales.InvoiceLines to calculate NetAmount using ExtendedPrice - TaxAmount.
3. I grouped the data by year, quarter, and customer to calculate one net income value per customer per quarter.
4. I used a CTE to separate the aggregation step from the ranking step.
5. I used LEFT JOIN with Sales.Customers to return the customer name.
6. I used DENSE_RANK() with PARTITION BY year and quarter to rank customers inside each quarter.
7. I filtered the result with WHERE DNR <= 5 to keep the top five customers per quarter.
8. The final result is ordered by year, quarter, and rank.
*/

-- Task 3: Top 10 products by total profit
SELECT TOP 10 SI.StockItemID,SI.StockItemName,SUM(IL.ExtendedPrice - IL.TaxAmount) AS [TotalProfit]
FROM Warehouse.StockItems SI
JOIN Sales.InvoiceLines IL ON SI.StockItemID=IL.StockItemID
GROUP BY SI.StockItemID,SI.StockItemName
ORDER BY [TotalProfit] DESC
/*
Task 3 explanation:
1. I used SELECT TOP 10 to return the ten highest-profit products.
2. I joined Warehouse.StockItems with Sales.InvoiceLines to connect each product with its sold invoice lines.
3. I calculated TotalProfit using SUM(ExtendedPrice - TaxAmount).
4. I grouped the result by StockItemID and StockItemName to aggregate profit per product.
5. The final result is ordered by TotalProfit in descending order.
*/

-- Task 4: Valid stock items ranked by nominal product profit
WITH ValidItems AS
(SELECT StockItemID,StockItemName,UnitPrice,RecommendedretailPrice,(RecommendedRetailPrice - UnitPrice) AS [NominalProductProfit]
FROM Warehouse.StockItems
WHERE ValidTo > GETDATE())
SELECT ROW_NUMBER()OVER(ORDER BY [NominalProductProfit] DESC) AS [Rn],
StockItemID,StockItemName,UnitPrice,RecommendedretailPrice,[NominalProductProfit],
DENSE_RANK() OVER (ORDER BY NominalProductProfit DESC) AS [DNR]
FROM ValidItems
ORDER BY [NominalProductProfit] DESC
/*
Task 4 explanation:
1. I used WHERE ValidTo > GETDATE() to select only stock items that are still valid.
2. I calculated NominalProductProfit as RecommendedRetailPrice - UnitPrice.
3. I used a CTE to separate the filtering and profit calculation step.
4. I used ROW_NUMBER() to create a unique row number ordered by nominal profit.
5. I used DENSE_RANK() to rank products by nominal profit without gaps in the ranking.
6. The final result is ordered by NominalProductProfit in descending order.
*/

-- Task 5: Supplier product list aggregation
SELECT CAST(S.SupplierID AS varchar(10)) + '-' + S.SupplierName AS [SupplierDetails],
STRING_AGG(CAST(SI.StockItemID AS varchar(10)) + ' ' + SI.StockItemName, '/, ') AS [ProductDetails]
FROM Purchasing.Suppliers S
JOIN Warehouse.StockItems SI ON S.SupplierID = SI.SupplierID
GROUP BY S.SupplierID,S.SupplierName
/*
Task 5 explanation:
1. I combined SupplierID and SupplierName into one SupplierDetails column using CAST and string concatenation.
2. I joined Purchasing.Suppliers with Warehouse.StockItems to connect each supplier with its products.
3. I used STRING_AGG to return all products for each supplier in a single row.
4. I used CAST on StockItemID before concatenating it with StockItemName.
5. I grouped the result by SupplierID and SupplierName to return one row per supplier.
*/

-- Task 6: Top 5 customers by total spending with geographic details
SELECT TOP 5 I.CustomerID,CI.CityName,CO.CountryName,CO.Continent,CO.Region,SUM(IL.ExtendedPrice) AS [TotalExtendedPrice]
FROM Sales.InvoiceLines IL
JOIN Sales.Invoices I ON I.InvoiceID=IL.InvoiceID
JOIN Sales.Customers C ON I.CustomerID=C.CustomerID
JOIN Application.Cities CI ON CI.CityID=C.DeliveryCityID
JOIN Application.StateProvinces SP ON SP.StateProvinceID=CI.StateProvinceID
JOIN Application.Countries CO ON CO.CountryID=SP.CountryID
GROUP BY I.CustomerID, CI.CityName, CO.CountryName,CO.Continent,CO.Region
ORDER BY [TotalExtendedPrice] DESC
/*
Task 6 explanation:
1. I used SELECT TOP 5 to return the five customers with the highest total spending.
2. I joined invoice line data with invoice and customer data to connect sales with customers.
3. I joined Customers, Cities, StateProvinces, and Countries to include geographic details.
4. I calculated TotalExtendedPrice using SUM(ExtendedPrice).
5. I grouped the result by CustomerID, CityName, CountryName, Continent, and Region.
6. The final result is ordered by TotalExtendedPrice in descending order.
*/

-- Task 8: Monthly order count matrix by year
SELECT OrderMonth,ISNULL([2013], 0) AS [2013],ISNULL([2014], 0) AS [2014],ISNULL([2015], 0) AS [2015],ISNULL([2016], 0) AS [2016]
FROM (SELECT MONTH(O.OrderDate) AS OrderMonth,YEAR(O.OrderDate) AS OrderYear,O.OrderID FROM Sales.Orders O
WHERE YEAR(O.OrderDate) IN (2013, 2014, 2015, 2016)) AS S
PIVOT (COUNT(OrderID) FOR OrderYear IN ([2013], [2014], [2015], [2016])) AS P
ORDER BY OrderMonth
/*
Public portfolio note:
Task 7 is not included in this script. This was a school project, and partial task completion was allowed.
*/

/*
Task 8 explanation:
1. I used MONTH(OrderDate) to return the order month number.
2. I used YEAR(OrderDate) to separate the order data by year.
3. I filtered the data to include only the years 2013, 2014, 2015, and 2016.
4. I used PIVOT to transform yearly order counts from rows into columns.
5. Inside the PIVOT, I used COUNT(OrderID) to count orders per month per year.
6. I used ISNULL to replace missing values with 0.
7. The final result is ordered by month.
*/

-- Task 9: Potential customer churn detection
WITH OrderWithPrev AS
(SELECT C.CustomerID,C.CustomerName,O.OrderDate, LAG(O.OrderDate) OVER(PARTITION BY C.CustomerID ORDER BY O.OrderDate) AS [PreviousOrderDate]
FROM Sales.Customers C
JOIN Sales.Orders O ON C.CustomerID=O.CustomerID),
OrderWithCalc AS
(SELECT CustomerID,CustomerName,OrderDate,PreviousOrderDate,AVG(DATEDIFF(day,PreviousOrderDate,OrderDate))OVER(PARTITION BY CustomerID) AS [AvgDaysBetweenOrders],
MAX(OrderDate) OVER(PARTITION BY CustomerID) AS [LastCustomerOrderDate], MAX(OrderDate) OVER () AS [LastOrderDateAll]
FROM OrderWithPrev)
SELECT CustomerID,CustomerName,OrderDate,PreviousOrderDate,AvgDaysBetweenOrders,LastOrderDateAll,
DATEDIFF(day,LastCustomerOrderDate,LastOrderDateAll) AS [DaysSinceLastOrder],
CASE WHEN AvgDaysBetweenOrders IS NULL THEN 'Active'
WHEN DATEDIFF(day, LastCustomerOrderDate, LastOrderDateAll) > 2 * AvgDaysBetweenOrders THEN 'Potential Churn' ELSE 'Active' END AS[CustomerStatus]
FROM OrderWithCalc
/*
Task 9 explanation:
1. I used LAG(OrderDate) to get the previous order date for each customer.
2. I used a CTE to separate the previous-order calculation from the next calculations.
3. I used DATEDIFF to calculate the number of days between customer orders.
4. I used AVG() OVER(PARTITION BY CustomerID) to calculate the average number of days between orders for each customer.
5. I used MAX(OrderDate) OVER(PARTITION BY CustomerID) to get each customer's last order date.
6. I used MAX(OrderDate) OVER() to get the latest order date in the full orders table.
7. I calculated DaysSinceLastOrder by comparing the customer's last order date with the latest order date in the dataset.
8. I used CASE to classify customers as Potential Churn when DaysSinceLastOrder is greater than twice their average time between orders.
*/

-- Task 10: Customer category business risk analysis
WITH CustomerBase AS
(SELECT CC.CustomerCategoryName,CASE WHEN C.CustomerName LIKE 'Wingtip%' THEN 'Wingtip' 
WHEN C.CustomerName LIKE 'Tailspin%' THEN 'Tailspin' ELSE C.CustomerName END AS CustomerName
FROM Sales.Customers C
JOIN Sales.CustomerCategories CC
ON CC.CustomerCategoryID = C.CustomerCategoryID),
CatAgg AS
(SELECT CustomerCategoryName, COUNT(DISTINCT CustomerName) AS CustomerCOUNT
FROM CustomerBase
GROUP BY CustomerCategoryName)
SELECT CustomerCategoryName,CustomerCOUNT,SUM(CustomerCOUNT) OVER () AS TotalCustomerCount,
CAST(CAST(CustomerCOUNT * 100.0 / SUM(CustomerCOUNT) OVER () AS decimal(5,2)) AS varchar(20)) + '%' AS DistributionFactor
FROM CatAgg
ORDER BY CustomerCategoryName
/*
Task 10 explanation:
1. I joined Customers with CustomerCategories to return the category for each customer.
2. I used CASE to group customer names that start with Wingtip or Tailspin under general names.
3. I used a CTE to separate the category and customer-name normalization step.
4. I used COUNT(DISTINCT CustomerName) with GROUP BY CustomerCategoryName to count unique customers per category.
5. I used a second CTE to separate the category aggregation step.
6. I used SUM(CustomerCOUNT) OVER() to calculate the total customer count across all categories.
7. I calculated DistributionFactor as the percentage of customers in each category.
8. I converted the percentage result into text and added the % symbol for display.
9. The final result is ordered by CustomerCategoryName.
*/