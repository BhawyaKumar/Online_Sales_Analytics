-- ANALYSIS

-- KPIS

--1. Total Customers - who have placed orders

select count(distinct CustomerKey) from Sales_table

-- 2. Total customer cities

select count(distinct Customer_City) from Sales_table

-- 3. Total Products

select count(distinct ProductKey) from Sales_table

-- 4. Total categories

select count(distinct Product_Category) from Sales_table

-- 5. Total orders

select count(distinct SalesOrderNumber) from Sales_table

-- 6. Total Revenue

select round(sum(SalesAmount),2) from Sales_table

-- 7. AVg order value 

select avg(sales_per_order) as avg_order_value from (select SalesOrderNumber,sum(salesAmount) as sales_per_order from Sales_table
group by SalesOrderNumber) as A

-- 8. Avg sales per customer

select avg(sales_amount) as avg_sales from (select CustomerKey, sum(salesamount) as sales_amount from Sales_table
group by CustomerKey) as A

-- 9. avg order count(frequency) by customer

select avg(frequency * 1.0) as avg_count from (select customerkey, count(distinct SalesOrderNumber ) as frequency from Sales_table
group by CustomerKey) as A

-- 10. top selling category

select top 1 Product_Category, sum(SalesAmount) from Sales_table
group by Product_Category
order by sum(salesAmount) desc

-- 11. total subcategories

select count(distinct Sub_Category) from Sales_table

-- 12. count of repeat(loyal) customers

select count(customerkey) from (select  CustomerKey, count(salesordernumber) as orders_ from Sales_table
group by CustomerKey
having count(salesordernumber) > 1) as A

-- 13. average shipping days 

select avg(datediff(day, OrderDateKey,ShipDateKey)) as avg_days from Sales_table

-- 14. avg delivery days

select avg(datediff(day,orderdatekey,duedatekey)) from sales_table

-- 15. budget variance-- Sum of total variance
SELECT 
    SUM(S.sales_ - B.budget) AS Total_Budget_Variance
FROM (
    SELECT 
        MONTH(OrderDateKey) AS month_, 
        YEAR(OrderDateKey) AS year_, 
        SUM(SalesAmount) AS sales_
    FROM Sales_table
    GROUP BY MONTH(OrderDateKey), YEAR(OrderDateKey)
) AS S
JOIN (
    SELECT 
        MONTH(date) AS month_, 
        YEAR(date) AS year_, 
        SUM(Budget) AS budget
    FROM Sales_Budget
    GROUP BY MONTH(date), YEAR(date)
) AS B
ON S.month_ = B.month_ AND S.year_ = B.year_;


---  EDA

-- Customer level analysis

-- 16. top 10 customers

select top 10 CustomerKey,full_name, sum(SalesAmount) as sales_ from Sales_table
group by CustomerKey, full_name
order by sales_ desc

--17.  bottom 10 customers

select top 10 CustomerKey,full_name, sum(SalesAmount) as sales_ from Sales_table
group by CustomerKey, full_name
order by sales_

-- 18 Gender wise sales

select Gender, round(sum(salesAmount) ,2)as gender_wise_sales from Sales_table
group by gender

-- 19. High value Customer segmentation 

WITH Percentiles AS (
    SELECT  
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salesAmount) OVER () AS p75,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salesAmount) OVER () AS p25
    FROM Sales_table
)

SELECT 
    A.CustomerKey, 
    SUM(A.salesAmount) AS total_sales,
    CASE 
        WHEN SUM(A.salesAmount) > B.p75 THEN 'High Revenue'
        WHEN SUM(A.salesAmount) BETWEEN B.p25 AND B.p75 THEN 'Medium Revenue'
        WHEN SUM(A.salesAmount) < B.p25 THEN 'Low Revenue'
    END AS Revenue_Segment
FROM Sales_table AS A
CROSS JOIN (
    SELECT DISTINCT p75, p25 FROM Percentiles
) AS B
GROUP BY A.CustomerKey, B.p75, B.p25;

-- 20 First-Time vs Repeat Customers (based on first purchase and sales count)

select count(customerkey),Buyer_Type, sum(salesamount) from (SELECT 
  customerkey,salesamount,
  CASE 
    WHEN count(salesordernumber) > 1 THEN 'Repeat Buyer'
    ELSE 'One-Time Buyer'
  END AS Buyer_Type
FROM Sales_table
group by CustomerKey, salesamount)as A
group by Buyer_Type



--- 21 Customer Lifetime Value

select customerkey, sum(salesamount) as clv,
datediff(day, datefirstpurchase , max(orderdatekey)) as tenure from Sales_table
group by CustomerKey, datefirstpurchase

-- 22 Product Preferences by Customer Segment

WITH Percentiles AS (
    SELECT  
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salesAmount) OVER () AS p75,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salesAmount) OVER () AS p25
    FROM Sales_table
), 

Customer_Segment AS (
    SELECT 
        A.CustomerKey, 
        A.product_name,
        SUM(A.salesAmount) AS total_sales,
        CASE 
            WHEN SUM(A.salesAmount) > B.p75 THEN 'High Revenue'
            WHEN SUM(A.salesAmount) BETWEEN B.p25 AND B.p75 THEN 'Medium Revenue'
            ELSE 'Low Revenue'
        END AS Revenue_Segment
    FROM Sales_table AS A
    CROSS JOIN (
        SELECT DISTINCT p75, p25 FROM Percentiles
    ) AS B
    GROUP BY A.CustomerKey, B.p75, B.p25, A.product_name
)

SELECT 
    product_name, 
    Revenue_Segment, 
    SUM(total_sales) AS total_sales_by_segment
FROM Customer_Segment
GROUP BY product_name, Revenue_Segment
ORDER BY product_name, Revenue_Segment;

-- 23 RFM Segmentation 

WITH Customer_RFM AS (
    SELECT
        CustomerKey,
        DATEDIFF(DAY, MAX(OrderDateKey), '2021-01-31') AS INACTIVE_DAYS, -- Recency
        COUNT(DISTINCT SalesOrderNumber) AS Frequency,
        SUM(SalesAmount) AS Total_Expenditure
    FROM Sales_table
    GROUP BY CustomerKey
),
percentiles AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.66) WITHIN GROUP (ORDER BY INACTIVE_DAYS) OVER () AS P66_R,
        PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY INACTIVE_DAYS) OVER () AS P33_R,
        PERCENTILE_CONT(0.45) WITHIN GROUP (ORDER BY Total_Expenditure) OVER () AS P45_M,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY Total_Expenditure) OVER () AS P95_M
    FROM Customer_RFM
),
rfm AS (
    SELECT
        CustomerKey,
        Total_Expenditure,
        Frequency,
        INACTIVE_DAYS,
        CASE 
            WHEN INACTIVE_DAYS >= P66_R THEN 1
            WHEN INACTIVE_DAYS > P33_R THEN 2
            ELSE 3
        END AS Recency_Score,
        CASE 
            WHEN Frequency > 4 THEN 3
            WHEN Frequency > 2 THEN 2
            ELSE 1
        END AS Frequency_Score,
        CASE 
            WHEN Total_Expenditure > P95_M THEN 3
            WHEN Total_Expenditure > P45_M THEN 2
            ELSE 1
        END AS Monetary_Score
    FROM Customer_RFM
    CROSS JOIN percentiles
),
segmentation AS (
    SELECT
        CustomerKey,
        (Recency_Score + Frequency_Score + Monetary_Score) AS RFM_SCORE
    FROM rfm
)

UPDATE s
SET Segment =
    CASE 
        WHEN seg.RFM_SCORE >= 7 THEN 'Premium'
        WHEN seg.RFM_SCORE BETWEEN 5 AND 6 THEN 'Gold'
        WHEN seg.RFM_SCORE = 4 THEN 'Silver'
        ELSE 'Standard'
    END
FROM Sales_table s
JOIN segmentation seg ON s.CustomerKey = seg.CustomerKey;




-- Product level Analysis

-- 24. Top 10 Products (as per sales and contribution %)

select top 10 ProductKey, Product_Name, sum(salesAmount) as sales,
round(sum(salesAmount) * 100/ (select sum(salesAmount) from Sales_table),2) as percentage_contri
from Sales_table
group by ProductKey, Product_Name
order by sum(salesAmount) desc

-- 25 Low Performing products (based on sales)

select top 10 ProductKey, Product_Name, sum(salesAmount) as sales,
round(sum(salesAmount) * 100/ (select sum(salesAmount) from Sales_table),2) as percentage_contri
from Sales_table
group by ProductKey, Product_Name
order by sum(salesAmount)

-- 26 Sales by Product category 

select Product_Category, sum(SalesAmount) as sales_cat from Sales_table
group by Product_Category
order by sales_cat desc

-- 27. Product lifecycle analysis(first and last sold)

select  Product_Name, min(orderdatekey) as first_sold, max(orderdatekey) as last_sold,
datediff(day, min(orderdatekey), max(orderdatekey)) as product_lifecycle
from Sales_table
group by Product_Name

-- 29 Product Performance Over Time

select  Product_Name, ProductKey, format(orderdatekey, 'yyyy-MM'), sum(salesAmount) from Sales_table
group by Product_Name, ProductKey, format(orderdatekey, 'yyyy-MM')
order by format(orderdatekey, 'yyyy-MM')

-- 30  Category Performance Over Time

select  Product_Category, format(orderdatekey, 'yyyy-MM'), sum(salesAmount) from Sales_table
group by Product_Category, format(orderdatekey, 'yyyy-MM')
order by format(orderdatekey, 'yyyy-MM')

-- 31 Which Product models generate the most revenue? 

select top 10 Product_Model_Name, round(sum(salesAmount),2) from Sales_table
group by Product_Model_Name
order by round(sum(salesAmount),2) desc

-- 32 Product Model Performance by Category

select Product_Category, Product_Model_Name, sum(salesAmount) from Sales_table
group by Product_Category, Product_Model_Name 

-- 33 Product Status wise sales

select Product_Status, sum(salesAmount) from Sales_table
group by Product_Status


---- Order $ Fulfuilment analysis

-- 34 Calculate if there is any delay in delivery by due date vs shipment date analysis (on time delivery percentage)

SELECT 
    COUNT(CASE WHEN ShipDateKey <= DueDateKey THEN 1 END) * 100 / COUNT(*) AS OnTimeDeliveryPercentage
FROM  Sales_table

-- 35 Month wise order Analysis

select DATENAME(MONTH, OrderDateKey) AS MonthName, count(salesordernumber) as count_orders, sum(salesAMount) as Sales from Sales_table
group by  DATENAME(MONTH, OrderDateKey), MONTH(OrderDateKey)
order by MONTH(OrderDateKey)

--36  Order Volume Analysis by customer and product

select  CustomerKey, count(salesordernumber) as order_volume from Sales_table
group by CustomerKey
order by order_volume desc


select  ProductKey, count(salesordernumber) as order_volume from Sales_table
group by ProductKey
order by order_volume desc

---- BUDGET ANALYSIS

-- 37 Comparison between actual sales and budget allocated

WITH Sales_Monthly AS (
    SELECT 
        YEAR(OrderDateKey) AS Sale_Year,
        MONTH(OrderDateKey) AS Sale_Month,
        SUM(salesAmount) AS Monthly_Sales
    FROM Sales_table
    GROUP BY YEAR(OrderDateKey), MONTH(OrderDateKey)
),
Budget_Monthly AS (
    SELECT 
        YEAR([date]) AS Budget_Year,
        MONTH([date]) AS Budget_Month,
        SUM(budget) AS Monthly_Budget
    FROM Sales_Budget
    GROUP BY YEAR([date]), MONTH([date])
)
SELECT 
    SUM(s.Monthly_Sales) AS actual_sales,
    SUM(b.Monthly_Budget) AS budget
FROM Sales_Monthly s
JOIN Budget_Monthly b
  ON s.Sale_Year = b.Budget_Year 
 AND s.Sale_Month = b.Budget_Month;

-- 38 To highlight months that consistently exceed or fall below budget.

WITH Sales_Monthly AS (
    SELECT 
        YEAR(OrderDateKey) AS Sale_Year,
        MONTH(OrderDateKey) AS Sale_Month,
        SUM(salesAmount) AS Monthly_Sales
    FROM Sales_table
    GROUP BY YEAR(OrderDateKey), MONTH(OrderDateKey)
),
Budget_Monthly AS (
    SELECT 
        YEAR([date]) AS Budget_Year,
        MONTH([date]) AS Budget_Month,
        SUM(budget) AS Monthly_Budget
    FROM Sales_Budget
    GROUP BY YEAR([date]), MONTH([date])
)
SELECT 
    s.Sale_Year,
    s.Sale_Month,
    SUM(s.Monthly_Sales) AS actual_sales,
    SUM(b.Monthly_Budget) AS budget,
    CASE 
        WHEN SUM(s.Monthly_Sales) > SUM(b.Monthly_Budget) THEN 'Above Budget'
        WHEN SUM(s.Monthly_Sales) < SUM(b.Monthly_Budget) THEN 'Below Budget'
        ELSE 'On Target'
    END AS performance_flag
FROM Sales_Monthly s
JOIN Budget_Monthly b
  ON s.Sale_Year = b.Budget_Year 
 AND s.Sale_Month = b.Budget_Month
GROUP BY s.Sale_Year, s.Sale_Month
ORDER BY s.Sale_Year, s.Sale_Month


-- 39 Quarterly Budget vs actual


WITH Sales_Monthly AS (
    SELECT 
        YEAR(OrderDateKey) AS Sale_Year,
        DATEPART(QUARTER, OrderDateKey) AS Sale_Quarter, 
        SUM(salesAmount) AS Monthly_Sales
    FROM Sales_table
    GROUP BY YEAR(OrderDateKey),  DATEPART(QUARTER, OrderDateKey)
),
Budget_Monthly AS (
    SELECT 
        YEAR([date]) AS Budget_Year,
         DATEPART(QUARTER, [date]) AS budget_quarter,
        SUM(budget) AS Monthly_Budget
    FROM Sales_Budget
    GROUP BY YEAR([date]),  DATEPART(QUARTER, [date])
)

select s.Sale_Year, s.Sale_Quarter, Monthly_Sales - Monthly_Budget from Sales_Monthly as s
join Budget_Monthly as b
on s.Sale_Year = b.Budget_Year
and s.Sale_Quarter = b.budget_quarter



-- 40  Compute budget variance per month and year


WITH Sales_Monthly AS (
    SELECT 
        YEAR(OrderDateKey) AS Sale_Year,
        MONTH(OrderDateKey) AS Sale_Month,
        SUM(salesAmount) AS Monthly_Sales
    FROM Sales_table
    GROUP BY YEAR(OrderDateKey), MONTH(OrderDateKey)
),
Budget_Monthly AS (
    SELECT 
        YEAR([date]) AS Budget_Year,
        MONTH([date]) AS Budget_Month,
        SUM(budget) AS Monthly_Budget
    FROM Sales_Budget
    GROUP BY YEAR([date]), MONTH([date])
)

select s.Sale_Year, s.Sale_Month, Monthly_Sales - Monthly_Budget as variance from Sales_Monthly as s
join Budget_Monthly as b 
on s.Sale_Year = b.Budget_Year
and s.Sale_Month = b.Budget_Month

-- SALES TRENDS

-- 41 MoM sales growth
SELECT YEAR(OrderDateKey) AS Sale_Year, month(OrderDateKey) AS Sale_Month, SUM(SalesAmount) AS Total_Sales,
    SUM(SalesAmount) - LAG(SUM(SalesAmount)) OVER (ORDER BY YEAR(OrderDateKey), MONTH(OrderDateKey)) AS Sales_Difference
FROM Sales_table
GROUP BY YEAR(OrderDateKey), MONTH(OrderDateKey)
ORDER BY Sale_Year, Sale_Month

-- 42 YOY saes growth

SELECT YEAR(OrderDateKey) AS Sale_Year, SUM(SalesAmount) AS Total_Sales,
    SUM(SalesAmount) - LAG(SUM(SalesAmount)) OVER (ORDER BY YEAR(OrderDateKey)) AS Sales_Difference
FROM Sales_table
GROUP BY YEAR(OrderDateKey)
ORDER BY Sale_Year

-- 43 Quarter-wise Sales Distribution

select datepart(quarter, OrderDateKey), sum(salesAmount) 
from Sales_table
group by datepart(quarter, OrderDateKey) 
order by sum(salesAmount) desc

-- 44  Location wise Sales

select  Customer_City, sum(salesAmount) from Sales_table
group by Customer_City
order by sum(salesAmount) desc