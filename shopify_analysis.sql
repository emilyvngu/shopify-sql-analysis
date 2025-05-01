-- ========================================
-- PART 0: DATA VALIDATION
-- ========================================
-- Check sample data
SELECT * FROM RAW_DATA.ORDERS LIMIT 5;

-- Check for duplicate users
SELECT USER_ID, COUNT(USER_ID)
FROM CUSTOMERS
GROUP BY USER_ID
HAVING COUNT(USER_ID) > 1;

-- ========================================
-- PART 1: CLEANED AVERAGE ORDER VALUE (AOV)
-- ========================================

-- Initial AOV
SELECT ROUND(AVG(ORDER_AMOUNT), 2) AS AOV
FROM RAW_DATA.ORDERS;

-- Look for cases of fraud 
SELECT ORDER_AMOUNT, COUNT(ORDER_AMOUNT)
FROM ORDERS
GROUP BY ORDER_AMOUNT
ORDER BY ORDER_AMOUNT DESC;

-- CTE with no fraud orders
WITH cleaned_orders AS (
    SELECT * 
    FROM ORDERS
    WHERE ORDER_AMOUNT <> 704000
)
SELECT ROUND(AVG(ORDER_AMOUNT),2) FROM cleaned_orders;

-- ========================================
-- PART 2: ORDER SIZE CATEGORIZATION
-- ========================================
WITH Clean_Orders AS (
    SELECT *
    FROM ORDERS
    WHERE ORDER_AMOUNT != 704000
)
SELECT 
    ORDER_ID,
    USER_ID,
    TOTAL_ITEMS,
    CASE 
        WHEN TOTAL_ITEMS BETWEEN 1 AND 2 THEN 'Small'
        WHEN TOTAL_ITEMS BETWEEN 3 AND 5 THEN 'Medium'
        WHEN TOTAL_ITEMS > 5 THEN 'Large'
        ELSE 'Unknown'
    END AS ORDER_SIZE
FROM Clean_Orders;

-- Find the Most Frequent Order Size
WITH Clean_Orders AS (
    SELECT *
    FROM ORDERS
    WHERE ORDER_AMOUNT != 704000
)
SELECT 
    CASE 
        WHEN TOTAL_ITEMS BETWEEN 1 AND 2 THEN 'Small'
        WHEN TOTAL_ITEMS BETWEEN 3 AND 5 THEN 'Medium'
        WHEN TOTAL_ITEMS > 5 THEN 'Large'
        ELSE 'Unknown'
    END AS ORDER_SIZE,
    COUNT(*) AS FREQUENCY
FROM Clean_Orders
GROUP BY ORDER_SIZE
ORDER BY FREQUENCY DESC;

-- Calculate % of Total Orders per Category
WITH Clean_Orders AS (
    SELECT *
    FROM ORDERS
    WHERE ORDER_AMOUNT != 704000
)
SELECT 
    ORDER_SIZE,
    COUNT(*) AS FREQUENCY,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Clean_Orders), 2) AS PERCENTAGE_OF_TOTAL
FROM (
    SELECT 
        CASE 
            WHEN TOTAL_ITEMS BETWEEN 1 AND 2 THEN 'Small'
            WHEN TOTAL_ITEMS BETWEEN 3 AND 5 THEN 'Medium'
            WHEN TOTAL_ITEMS > 5 THEN 'Large'
            ELSE 'Unknown'
        END AS ORDER_SIZE
    FROM Clean_Orders
)
GROUP BY ORDER_SIZE
ORDER BY FREQUENCY DESC;

-- ========================================
-- PART 3: TOP 10 CUSTOMERS BY SPEND
-- ========================================

-- Distribution of customers by state
SELECT STATE, COUNT(USER_ID) AS FREQUENCY
FROM CUSTOMERS
GROUP BY STATE
ORDER BY FREQUENCY DESC;

-- Top 10 customers Based on Total Spend
WITH Clean_Orders AS (
    SELECT *
    FROM ORDERS
    WHERE ORDER_AMOUNT != 704000
)
SELECT USER_ID, 
       SUM(ORDER_AMOUNT) AS ORDER_TOTAL
FROM Clean_Orders
GROUP BY USER_ID
ORDER BY ORDER_TOTAL DESC
LIMIT 10;

-- Get their demographic info (age_group and state)
WITH Clean_Orders AS (
    SELECT *
    FROM ORDERS
    WHERE ORDER_AMOUNT != 704000
)
SELECT 
    t.USER_ID,
    t.TOTAL_SPENT,
    c.AGE_GROUP,
    c.STATE
FROM (
    SELECT 
        USER_ID,
        SUM(ORDER_AMOUNT) AS TOTAL_SPENT
    FROM Clean_Orders
    GROUP BY USER_ID
    ORDER BY TOTAL_SPENT DESC
    LIMIT 10
) AS t
JOIN CUSTOMERS c
ON t.USER_ID = c.USER_ID
ORDER BY t.TOTAL_SPENT DESC;

-- What age group is the majority?
WITH Clean_Orders AS (
    SELECT *
    FROM ORDERS
    WHERE ORDER_AMOUNT != 704000
)
SELECT 
    c.AGE_GROUP,
    COUNT(c.USER_ID) AS FREQUENCY
FROM (
    SELECT 
        USER_ID,
        SUM(ORDER_AMOUNT) AS TOTAL_SPENT
    FROM Clean_Orders
    GROUP BY USER_ID
    ORDER BY TOTAL_SPENT DESC
    LIMIT 10
) AS t
JOIN CUSTOMERS c
ON t.USER_ID = c.USER_ID
GROUP BY AGE_GROUP
ORDER BY FREQUENCY DESC;

-- What state is the majority?
WITH Clean_Orders AS (
    SELECT *
    FROM ORDERS
    WHERE ORDER_AMOUNT != 704000
)
SELECT 
    c.STATE,
    COUNT(c.USER_ID) AS FREQUENCY
FROM (
    SELECT 
        USER_ID,
        SUM(ORDER_AMOUNT) AS TOTAL_SPENT
    FROM Clean_Orders
    GROUP BY USER_ID
    ORDER BY TOTAL_SPENT DESC
    LIMIT 10
) AS t
JOIN CUSTOMERS c
ON t.USER_ID = c.USER_ID
GROUP BY STATE
ORDER BY FREQUENCY DESC;

-- ========================================
-- PART 4: WEEK-OVER-WEEK GROWTH
-- ========================================

WITH weekly_sales AS (
    SELECT DATE_TRUNC('WEEK', CREATED_AT)::DATE AS week_start, 
            SUM(ORDER_AMOUNT) AS total_sales
    FROM ORDERS
    WHERE ORDER_AMOUNT != 704000
    GROUP BY week_start
)
SELECT a.week_start AS current_week, 
       a.total_sales AS current_week_sales,
       b.total_sales AS previous_week_sales,
       ROUND(((current_week_sales - previous_week_sales) / previous_week_sales)*100, 2) AS growth_percentage
FROM weekly_sales a
LEFT JOIN weekly_sales b
ON a.week_start = b.week_start + INTERVAL '1 week'
ORDER BY a.week_start;