-- E-Commerce Analytics Project — Database Setup & Data Load
-- Loads the cleaned dataset (from 02_data_cleaning.ipynb) into MySQL
 
CREATE DATABASE ecommerce_analytics;
USE ecommerce_analytics;
 
CREATE TABLE transactions (
    Invoice VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate DATETIME,
    Price DECIMAL(10,2),
    CustomerID INT,
    Country VARCHAR(50),
    SourceSheet VARCHAR(20),
    TransactionType VARCHAR(20),
    IsCancelled BOOLEAN,
    Description_clean VARCHAR(255),
    HasCustomerID BOOLEAN,
    Revenue DECIMAL(12,2)
);
 
-- Confirm structure before loading
DESCRIBE transactions;
 
-- MySQL only allows LOAD DATA INFILE to read from its designated secure folder.
-- Check the allowed path, then place the CSV there before loading.
SHOW VARIABLES LIKE 'secure_file_priv';
 
-- Load the cleaned CSV into the table.
-- CustomerID, IsCancelled, and HasCustomerID need conversion during load:
--   - CustomerID: empty strings in the CSV (missing IDs) must become proper NULL,
--     not fail as invalid integers
--   - IsCancelled / HasCustomerID: pandas exports booleans as the text "True"/"False",
--     but MySQL's BOOLEAN (stored as TINYINT) needs 0/1
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/online_retail_cleaned.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Invoice, StockCode, Description, Quantity, InvoiceDate, Price, @CustomerID, Country,
 SourceSheet, TransactionType, @IsCancelled, Description_clean, @HasCustomerID, Revenue)
SET
    CustomerID = NULLIF(@CustomerID, ''),
    IsCancelled = IF(@IsCancelled = 'True', 1, 0),
    HasCustomerID = IF(@HasCustomerID = 'True', 1, 0);
 
-- Verification: row count and total revenue should reconcile against the Python export
-- (Python profiling total: 19,287,250.57 matches after MySQL's DECIMAL(12,2) rounding)
SELECT COUNT(*) AS row_count, SUM(Revenue) AS total_revenue FROM transactions;