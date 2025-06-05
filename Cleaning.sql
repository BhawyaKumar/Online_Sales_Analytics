select count(*) from FACT_InternetSales -- 58168 -- No Duplicates - No null Values
select count(*) from DIM_Customer -- 18484 --  No Duplicates -- No null Values
select count(*) from DIM_Product -- 606 -- No Duplicates -- Have records with NULL
select count(*) from DIM_Calendar -- 1096 -- No Duplicates -- No null Values
select count(*) from Sales_Budget -- 18 -- No Duplicates -- No null Values

-- Checking duplicates in all tables
select count(*) from (select distinct * from FACT_InternetSales) as A
select count(*) from (select distinct * from DIM_Customer) as A
select count(*) from (select distinct * from DIM_Product) as A
select count(*) from (select distinct * from DIM_Calendar) as A
select count(*) from (select distinct * from Sales_Budget) as A

-- Checking Null values in all tables 

-- Fact Table
select * from FACT_InternetSales
where ProductKey is null
or OrderDateKey is null
or DueDateKey is null
or ShipDateKey is null
or CustomerKey is null
or SalesOrderNumber is null
or SalesAmount is null



select * from FACT_InternetSales
where cast(ProductKey as varchar) = 'Null'
or cast(OrderDateKey as varchar) = 'Null'
or cast(DueDateKey as varchar) = 'Null'
or cast(ShipDateKey as varchar) = 'Null'
or cast(CustomerKey as varchar) = 'Null'
or SalesOrderNumber = 'null'
or cast(SalesAmount as varchar) = 'null'

-- Customer Table -- No null values

select * from DIM_Customer
where CustomerKey is null
or First_Name is null
or Last_Name is null
or Full_Name is null
or Gender is null
or DateFirstPurchase is null
or Customer_City is null

select * from DIM_Customer
where cast(CustomerKey as varchar) = 'Null'
or First_Name = 'Null'
or Last_Name = 'Null'
or Full_Name = 'Null'
or Gender = 'Null'
or cast(DateFirstPurchase as varchar) = 'Null'
or Customer_City = 'Null'



-- Product Table

select * from DIM_Product
where ProductKey is null
or ProductItemCode is null
or Product_Name is null
or Sub_Category is null
or Product_Category is null
or Product_Model_Name is null
or Product_Status is null 

select * from DIM_Product
where cast(ProductKey as varchar) = 'null'
or ProductItemCode = 'null'
or Product_Name = 'null'
or Sub_Category = 'null'
or Product_Category = 'null'
or Product_Model_Name = 'null'
or Product_Status = 'null'

-- Calender Table

select * from DIM_Calendar
where DateKey is null 
or Date is null
or day is null
or Month is null
or MonthShort is null
or MonthNo is null
or Quarter is null
or Year is null

-- Budget Table

select * from Sales_Budget
where date is null
or budget is null

-- To check if CustomerKey in fact table exists in DimCustomer.

select * from FACT_InternetSales as A
left join DIM_Customer as B 
on A.CustomerKey = B.CustomerKey
where b.CustomerKey is null

select * from FACT_InternetSales as A
where  not exists (select CustomerKey from DIM_Customer as B where A.CustomerKey = B.CustomerKey)

-- To check if ProductKey in fact table exists in DimProduct

select * from FACT_InternetSales as A
where  not exists (select ProductKey from DIM_Product as B where A.ProductKey = B.ProductKey)

select * from FACT_InternetSales as A
left join DIM_Product as B 
on A.ProductKey = B.ProductKey
where b.ProductKey is null

-- To check if any sales order number is associated with more than 1 customerkey 

select SalesOrderNumber, count(distinct customerKey) from FACT_InternetSales
group by SalesOrderNumber
having count(distinct customerKey)  > 1

-- Check If due date or shipment date is before order date. Also if due date is before shipment date

select SalesOrderNumber, OrderDateKey, ShipDateKey, DueDateKey from FACT_InternetSales
where ShipDateKey < OrderDateKey
or DueDateKey < OrderDateKey 
or DueDateKey < ShipDateKey

-- Check if one order has multiple order date 

select SalesOrderNumber, count(distinct OrderDateKey) from FACT_InternetSales
group by SalesOrderNumber
having count(distinct OrderDateKey) > 1

-- check if amount has 0 values

select * from FACT_InternetSales
where SalesAmount <= 0


-- Replacing Null values in product table with other

update DIM_Product
set Product_Category = 'Others'
where Product_Category is null or Product_Category = 'Null'

update DIM_Product
set Sub_Category = 'Others'
where Sub_Category is null or Sub_Category = 'Null'

update DIM_Product
set Product_Model_Name = 'Others'
where Product_Model_Name is null or Product_Model_Name = 'Null'

-- creating main Sales table 

select * into Sales_table from (
select A.*,b.Full_Name,b.Gender,b.Customer_City,b.DateFirstPurchase, C.ProductItemCode,c.Product_Name,c.Product_Category,
c.Sub_Category,c.Product_Model_Name,c.Product_Status
from FACT_InternetSales as A
left join DIM_Customer as b on A.CustomerKey = B.CustomerKey
left join DIM_Product as c on A.ProductKey = c.ProductKey) as D

