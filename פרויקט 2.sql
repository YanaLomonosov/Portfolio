use WideWorldImporters

--**ex1
--Write an SQL query that calculates the annual sales total and the annual linear revenue for each year.
--In addition, calculate the growth rate of the annual linear revenue compared to the previous year.

with Income
as
(
	select year(o.OrderDate) as year
			,sum(ol.PickedQuantity * ol.UnitPrice) as IncomePerYear
			,count(distinct MONTH(o.OrderDate)) as NumberofDistinctMonths
	from Sales.OrderLines ol join Sales.Orders o
	on ol.OrderID=o.OrderID
	group by year(o.OrderDate)
),
LinearIncome
as (
	select year 
		   ,round(12*(IncomePerYear/NumberofDistinctMonths),2) as YearlyLinearIncome
	from Income
)
select Income.year
	   ,IncomePerYear
	   ,NumberofDistinctMonths
	   ,FORMAT(YearlyLinearIncome,'#.00') as YearlyLinearIncome
	   ,format(
			   (YearlyLinearIncome - lag(YearlyLinearIncome) over(order by cte.year))/lag(YearlyLinearIncome) over(order by cte.year) *100
			   ,'0.00')
		as GrowthRate
from Income join LinearIncome
on Income.year=LinearIncome.year

--**ex2
--Write an SQL query that displays the top five customers by net income for each quarter of the year.

select *
from(select *
		   ,DENSE_RANK() over(partition by TheYear,TheQuarter order by IncomePerYear desc) DNR
	 from(select YEAR(o.orderDate) as TheYear
				,DATEPART(qq,o.orderDate) as TheQuarter
				,c.CustomerName
				,sum(ol.PickedQuantity * ol.UnitPrice) as IncomePerYear
		  from Sales.Orders o join Sales.OrderLines ol
		  on o.OrderID=ol.OrderID
		  join Sales.Customers c
		  on o.CustomerID=c.CustomerID
		  group by YEAR(o.orderDate),DATEPART(qq,o.orderDate),c.CustomerName
		  )t
	)tt
where DNR<=5

--**ex3
--Write an SQL query that identifies the top 10 products that generated the highest total profit based on sold line items.
--The products should be ranked by total profit, and the query should return the item ID, item name, and their total profit.
--Total profit calculation: the difference between the extended price and the tax amount.

select StockItemID,StockItemName,TotalProfit
from(
select *
		,DENSE_RANK() over(order by TotalProfit desc) as DNR
from(select si.StockItemID
		   ,si.StockItemName
		   ,sum(il.ExtendedPrice - il.TaxAmount) as TotalProfit
	 from Sales.InvoiceLines il join Warehouse.StockItems si
	 on il.StockItemID=si.StockItemID
	 group by si.StockItemID,si.StockItemName) t
	 )tt
where DNR<=10

--**ex4
--Write an SQL query that finds all inventory items that are still valid (not expired),
--calculates the nominal profit for each item (the difference between the suggested retail price and the unit price),
--and ranks the items by nominal profit in descending order.
--Also, display the serial number of each item in this order.

with StockItemProperties
as(
	select StockItemID
		  ,StockItemName
		  ,UnitPrice
		  ,RecommendedRetailPrice
		  ,RecommendedRetailPrice-UnitPrice as NominalProductProfit
	from Warehouse.StockItems
)
select ROW_NUMBER() over(order by NominalProductProfit desc) as Rn
		,StockItemID
		,StockItemName
		,UnitPrice
		,RecommendedRetailPrice
		,NominalProductProfit
		,DENSE_RANK() over(order by NominalProductProfit desc) as DNR
from StockItemProperties

--**ex5
--Write an SQL query that displays, for each supplier code and supplier name,
--the list of products in inventory for that supplier, with the list separated by '/,'.
--Each product entry should include the product code and product name from the product inventory.

select concat(s.SupplierID,' - ',s.SupplierName) as SupplierDetails
		,STRING_AGG(
					concat(si.StockItemID,' ',si.StockItemName)
					,'/,')
		as ProdactDetails
from Warehouse.StockItems si join Purchasing.Suppliers s
on si.SupplierID=s.SupplierID
group by s.SupplierID,s.SupplierName

--**ex6
--Write an SQL query that displays the top five customers based on the total ExtendedPrice they spent on purchases,
--including their geographic location details.

with CustomersAddress
as
(
	select cus.CustomerID
		   ,cit.CityName
		   ,cntry.CountryName
		   ,cntry.Continent
		   ,cntry.Region
	from Sales.Customers cus join Application.Cities cit
	on cus.PostalCityID=cit.CityID
	join Application.StateProvinces sp
	on sp.StateProvinceID=cit.StateProvinceID
	join Application.Countries cntry
	on sp.CountryID=cntry.CountryID
),
CustomersExpenses
as
(
	select inv.CustomerID
		   ,sum(invl.ExtendedPrice) as TotalExtendedPrice
	from Sales.Invoices inv join Sales.InvoiceLines invl
	on inv.InvoiceID=invl.InvoiceID
	group by inv.CustomerID
)
select top 5 CustomersAddress.CustomerID
	   ,CustomersAddress.CityName
	   ,CustomersAddress.CountryName
	   ,CustomersAddress.Continent
	   ,CustomersAddress.Region
	   ,FORMAT(CustomersExpenses.TotalExtendedPrice,'#,#.00') as TotalExtendedPrice
from CustomersAddress join CustomersExpenses
on CustomersExpenses.CustomerID=CustomersAddress.CustomerID
order by CustomersExpenses.TotalExtendedPrice desc

--**ex7
--Write an SQL query that displays the total number of products in orders for each month of the year,
--as well as the cumulative total for each year.
--Additionally, include a row that summarizes the data for the entire year.

with OrderDetails
as
(
select YEAR(o.OrderDate) as OrderYear
	   ,month(o.OrderDate) as OrderMonth
	   ,sum(ol.PickedQuantity * ol.UnitPrice) MonthlyTotal
	   ,sum(sum(ol.PickedQuantity * ol.UnitPrice))
			over (partition by YEAR(o.OrderDate) 
				  order by month(o.OrderDate) rows between unbounded preceding and current row)
		as CumulativeTotal
from Sales.OrderLines ol join Sales.Orders o
on ol.OrderID=o.OrderID
group by YEAR(o.OrderDate),month(o.OrderDate)
),
AnnualSummary
as(
select OrderYear
	  ,cast(OrderMonth as nvarchar) as OrderMonth
	  ,format(MonthlyTotal,'#,#.00') as MonthlyTotal
	  ,format(CumulativeTotal,'#,#.00') as CumulativeTotal
from OrderDetails
union
select OrderYear
	   ,'Grand Total' as OrderMonth 
	   ,format(sum(MonthlyTotal),'#,#.00')
	   ,format(sum(MonthlyTotal),'#,#.00')
from OrderDetails
group by OrderYear
)
select *
from AnnualSummary
order by OrderYear,iif(OrderMonth='Grand Total',13,OrderMonth)

--**ex8
--Display, using a matrix, the number of orders made in each month of the year.

select OrderMonth,[2013],[2014],[2015],[2016]
from (select YEAR(OrderDate) as OrderYear
			 ,MONTH(OrderDate) as OrderMonth
			 ,orderid
	  from Sales.Orders
	  ) t
pivot(count(orderid) for OrderYear in ([2013],[2014],[2015],[2016])) pvt
order by OrderMonth

--**ex9
--Identify potential churn customers based on their order patterns.
--A customer is considered "at risk of churn" if the time elapsed since their last order is more than twice their average
--time between orders.
--Display, for each customer, the customer ID, customer name, date of the last order, number of days since the last order,
-- average time between orders (in days), and customer status ("At Risk of Churn" or "Active").

with OrdersPerCustomers
as
(
	select ordrs.CustomerID
		   ,cus.CustomerName
		   ,ordrs.OrderDate
		   ,lag(ordrs.OrderDate) over(partition by ordrs.CustomerID order by ordrs.CustomerID,ordrs.orderdate) as PreviousOrderDate
		   ,max(ordrs.OrderDate) over(partition by ordrs.customerId) as LastCustomersOrder
	from Sales.Orders ordrs join Sales.Customers cus
	on ordrs.CustomerID=cus.CustomerID
),
CalcDays
as
(
	select *
		   ,max(LastCustomersOrder) over() as LastOrder
		   ,DATEDIFF(dd,PreviousOrderDate,OrderDate) as DaysSincePreviousOrder
		   ,DATEDIFF(dd,LastCustomersOrder,max(LastCustomersOrder) over()) as DaysSinceLastOrder
	from OrdersPerCustomers
)
select CustomerID
	   ,CustomerName
	   ,OrderDate
	   ,PreviousOrderDate
	   ,DaysSinceLastOrder
	   ,avg(DaysSincePreviousOrder) over(partition by customerId) as AvgDaysBetweenOrders
	   ,iif(
			 DATEDIFF(dd,LastCustomersOrder,LastOrder) > 2*avg(DaysSincePreviousOrder) over(partition by customerId)
			,'Potential Churn'
			,'Active'
			)
		as CustomerStatus
from CalcDays

--**ex10
--Write a query that examines the business risk of the company by customer categories.
--Identify the customer categories with the highest number of unique customers,
--while grouping customers whose names start with "Wingtip" and "Tailspin" under general category names.
--Calculate the relative distribution of customers in each category out of the total number of customers,
--and assess where the highest risk exists based on the concentration of customers in each category.

with CustomersPerCategories
as
(
	select CustomerCategoryName
		   ,cast(CustomerCOUNT as float)as CustomerCOUNT
		   ,sum(CustomerCOUNT) over() as TotalCustCount
	from(select CustomerCategoryName
  ,count(distinct CustomerName) as CustomerCOUNT
		 from(select cat.CustomerCategoryID
					,cat.CustomerCategoryName
					,case 
						when cus.CustomerName like 'Wingtip%' then 'Wingtip'
						when cus.CustomerName like 'Tailspin%' then 'Tailspin'
						else cus.CustomerName 
					 end
					 as CustomerName
			  from Sales.Customers cus join Sales.CustomerCategories cat
			  on cus.CustomerCategoryID=cat.CustomerCategoryID) as t
		 group by CustomerCategoryName) as tt
)
select *
		,concat(round(CustomerCOUNT/TotalCustCount*100,2),'%') as DistributionFactor
from CustomersPerCategories
order by CustomerCategoryName

--The relative distribution of customers in each category shows
--that the highest risk exists in the categories of: Novelty Shop and Supermarket.
--This is because the number of customers in these categories is higher compared to other categories,
--and therefore, in the event of a problem in one of these categories, the company will be more affected.
