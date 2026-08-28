USE ecommerce_analytics;

-- Revenue by TransactionType, reconciled against Python (minor rounding-order variance, confirmed immaterial)
SELECT 
    transactionType, SUM(Revenue) AS Total_Revenue
FROM
    transactions
GROUP BY TransactionType;
-- Monthly Sale revenue trend. Excludes non-sale transaction types. Dec-2011 is partial (data ends 2011-12-09)
SELECT 
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS YearMonth,
    SUM(Revenue) AS Total_Revenue
FROM
    transactions
WHERE
    TransactionType = 'Sale'
GROUP BY YearMonth
ORDER BY YearMonth;
-- Overall cancellation rate: cancelled transactions as a % of all transactions
SELECT 
    SUM(IsCancelled) AS Total_Cancellations,
    COUNT(*) AS Total_Rows,
    (SUM(IsCancelled) / COUNT(*)) * 100 AS Cancellation_Rate_Percent
FROM
    transactions;
-- Monthly cancellation trend: count and value of cancelled transactions per month
SELECT 
    COUNT(IsCancelled) AS Total_Cancellation,
    DATE_FORMAT(InvoiceDate, '%Y,%m') AS TimePeriod,
    SUM(Revenue) AS Total_Value
FROM
    transactions
WHERE
    IsCancelled = 1
GROUP BY TimePeriod
ORDER BY TimePeriod ASC;
-- Top 10 highest-value cancellations in Dec-2011, investigating why that month's
-- cancellation value was disproportionately high despite having the fewest cancellations.
-- This query surfaced AMAZONFEE and CRUK StockCodes, leading to the discovery of
-- several non-product transaction types missing from TransactionType classification
-- (see 02_data_cleaning.ipynb for the fix)
SELECT 
    Invoice,
    StockCode,
    Quantity,
    Description_clean,
    InvoiceDate,
    Revenue
FROM
    transactions
WHERE
    IsCancelled = 1
        AND DATE_FORMAT(InvoiceDate, '%Y-%m') = '2011-12'
ORDER BY Revenue ASC
LIMIT 10;

-- Top 10 products by revenue. Restricted to Sale rows only fees, vouchers, and
-- adjustments would otherwise distort the ranking. Grouped on Description_clean rather
-- than StockCode for readability; note a small number of distinct StockCodes share a
-- Description_clean (see profiling notebook), so use StockCode if exact product level
-- granularity is required.
SELECT 
    Description_clean,
    SUM(REVENUE) AS Most_Revenue,
    SUM(Quantity) AS Total_Quantity
FROM
    transactions
WHERE
    TransactionType = 'Sale'
GROUP BY Description_clean
ORDER BY Most_Revenue DESC
LIMIT 10;
    
-- Customer-level revenue and order summary. No LIMIT by design this is the base table
-- for Phase 4 RFM segmentation: Customer_Orders = Frequency, Total_Revenue = Monetary,
-- Last_Order_Date = basis for Recency. DENSE_RANK used over RANK so tied customers don't
-- leave gaps in the ranking.    
SELECT
	CustomerID,
    COUNT(DISTINCT INVOICE) AS Customer_Orders,
    SUM(Revenue) AS Total_Revenue,
    MAX(InvoiceDate) AS Last_Order_Date,
    DENSE_RANK() OVER( ORDER BY SUM(Revenue) DESC) AS Ranking
    FROM Transactions
    WHERE HasCustomerID = 1 AND TransactionType = 'Sale'
    GROUP BY CustomerID
    ORDER BY Total_Revenue DESC
    LIMIT 10;
    
-- Cumulative Sale revenue by month. CTE isolates the monthly aggregation so the running
-- total can be layered on top cleanly. SUM() OVER (ORDER BY YearMonth) with no explicit
-- frame defaults to "all rows up to and including the current row," which is what
-- produces the cumulative effect.    
WITH monthly_totals AS(  
	SELECT
		SUM(Revenue) AS Total_Revenue,
		DATE_FORMAT(InvoiceDate,'%Y-%m') AS YearMonth
		From Transactions
		WHERE TransactionType = 'Sale'
		GROUP BY YearMonth
		ORDER BY YearMonth ASC)
        SELECT *,
        SUM(Total_Revenue) OVER(ORDER BY YearMonth) AS Running_Total
        FROM monthly_totals;