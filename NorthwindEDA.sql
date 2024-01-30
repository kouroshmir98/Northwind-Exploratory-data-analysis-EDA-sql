-- Q1 : What is total revenue ? 
select 
    sum(unitPrice * quantity * (1-discount)) as TotalRevenue
from factOrder
go

-- Q2 : How many orders have been placed so far?
select 
    COUNT(distinct orderBk) as totalOrders
from factOrder
go

-- Q3 : Calculate average revenue per customer ? 

select 
    sum(unitPrice * quantity * (1-discount)) / COUNT(distinct customerKey) as avgRevPerCustomer
from factOrder
go

-- Q4 : What is the country breakdown of our customers?
with cte_customerLocationKey as (
select 
    customerKey , 
    customerLocationKey as locationKey
from factOrder
group by customerLocationKey , customerKey
)
SELECT 
    l.country , 
    count( c.customerKey ) as countCustomers
from cte_customerLocationKey as c
INNER JOIN dimLocation as l on c.locationKey = l.locationKey
group by l.country
order by countCustomers DESC
go

-- Q5 : Who are our top 5 customers (by revenue) ?
-- A : using rank
with cte_revByCustomer as (
SELECT
    customerKey , 
    sum(unitPrice * quantity * (1-discount)) as revenue
from factOrder
group by customerKey
) , 
cte_customerRevRanked as (
select 
    * , 
RANK() OVER (order by revenue DESC) as rev_rank
from cte_revByCustomer
)
select 
    customerKey , revenue
from cte_customerRevRanked
WHERE rev_rank <= 5

-- B : using group by 
SELECT top 5
    customerKey , 
    sum(unitPrice * quantity * (1-discount)) as revenue
from factOrder
group by customerKey
order by revenue DESC
go


-- Q6 : How do we manage to deliver on time? ( What is on-time delivery rate ? )
with cte_ordersWithIsOnTime as (
SELECT
    orderBk, 
    case
        when  max(requiredDate) > max(shippedDate) then 1.0
        else 0.0
    END as isOntime 
from factOrder
WHERE shippedDate is not null
GROUP by orderBk
)
SELECT
    round(sum(isOntime)*100 / COUNT(orderBk) , 2) as onTimeDeliveryRate 
from cte_ordersWithIsOnTime
GO

-- Q7 : How many times have we shipped products?
WITH cte_orderByOrderBK as (
    SELECT
        orderBk
    from factOrder
    WHERE shippedDate is not NULL
    group by orderBk
)
select 
    COUNT(orderBk) as totalShipped
from cte_orderByOrderBK
GO
-- Q8 : On average, how many days does it take for an order to be shipped from the time it is placed?
WITH cte_orderByOrderBK as (
    SELECT
        orderBk , 
        DATEDIFF(DAY , max(orderDate) , max(shippedDate)) as orderToShipDays 
    from factOrder
    WHERE shippedDate is not NULL
    group by orderBk
)
select 
    AVG(orderToShipDays) avgOrderToShipDays
from cte_orderByOrderBK
go


-- Q9 : What is the average freight per country?
select 
    l.country , 
    round(AVG(freight) , 2) as avgFreight
from factOrder
INNER JOIN dimLocation as l on l.locationKey = factOrder.shipLocationKey
GROUP BY l.country
order by avgFreight DESC
GO


-- Q10 : How many units have been sold ? 
SELECT 
    sum(quantity) as unitsSold
from factOrder
GO

-- Q11 : What are the top 5 products? ( by revenue )
with cte_productRev as (
    select 
        productKey , 
        sum( quantity * unitPrice * (1-discount) ) as productRev
    from factOrder
    group by productKey
),
cte_productRevRanked as (
    select 
        * , 
        RANK() over (order by productRev desc) as prRank
    from cte_productRev
)
select 
    productKey , 
    productRev
from cte_productRevRanked 
WHERE prRank < = 5

GO

-- Q12 : What are the top 3 products in each country? ( by revenue )

with cte_productRevPerCountry as (
    select 
        l.country , 
        o.productKey , 
        sum(o.quantity * o.unitPrice * (1-o.discount) ) as productRev
    from factOrder as o
    inner join dimLocation as l on l.locationKey = o.customerLocationKey
    group by o.productKey , l.country
),
cte_productRevRanked as (
    select 
        * , 
        RANK() over (partition by country order by productRev desc) as prRank
    from cte_productRevPerCountry
)
select 
    productKey ,
    country ,  
    productRev
from cte_productRevRanked 
WHERE prRank < = 3
order by country

-- Q13 : What are the top 5 vendors by total sales?
with cte_vendorSales as (
    select 
        p.supplierName as vendor , 
        sum(quantity * unitPrice * (1-discount)) as totalSales
    from factOrder as o
    inner JOIN dimProduct as p on p.productKey = o.productKey
    group by p.supplierName
), 
cte_vendorRanked as (
    select 
        * , 
        RANK() OVER(order by totalSales desc) as vRank
    from cte_vendorSales
)
select 
    * 
from cte_vendorRanked
WHERE vRank <= 5
go

-- Q14 : What is the gender breakdown of the employees?
SELECT 
    gender , 
    COUNT(*) as count
from dimEmployee
WHERE gender != 'None'
group by gender
go

-- Q15 : What is the average age of the employees? 
select 
    avg(DATEDIFF(YEAR , birthDate , GETDATE()))
from dimEmployee
WHERE birthDate is not NULL
go


-- Q16 : Who are the top 3 employees?
with cte_employeeSales as (
    select 
        employeeKey , 
        sum(quantity * unitPrice * (1-discount) ) as sales
    from factOrder
    group by orderBk , employeeKey
),
cte_employeeSalesRanked as (
    select 
        * , 
        RANK() over(order by sales desc) as esRank
    from cte_employeeSales
)
select 
    * 
from cte_employeeSalesRanked
WHERE esRank <= 3
GO


-- Q17 : What are the shippers' shares?
with cte_orderShipperKey as(
    select
        orderBk ,
        shipperKey
    from factOrder
    WHERE shippedDate is not null
    group by shipperKey , orderBk

) , 
cte_shipperShippedCount as (
select
    shipperKey , 
    COUNT(*) as totalShipped
from cte_orderShipperKey
group by shipperKey
) , 
cte_shipperShippedWithGrandTotal 
as (
SELECT
    shipperKey , 
    totalShipped , 
    cast(sum(totalShipped) over() as decimal) as grandTotalShipped
from cte_shipperShippedCount
)
select 
    shipperKey , 
    round((totalShipped*100/grandTotalShipped) , 2 ) as shipperSharePCT
from cte_shipperShippedWithGrandTotal
GO