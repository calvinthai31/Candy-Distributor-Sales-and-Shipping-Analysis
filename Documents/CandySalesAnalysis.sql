##########################
##  Exploring the Data  ##
##########################

DESCRIBE fixed_sales;

SELECT *
FROM fixed_sales
LIMIT 100;

SELECT COUNT(*)
FROM fixed_sales;

# Finding number of unique customers
SELECT COUNT(DISTINCT `Customer ID`)
FROM fixed_sales;

# How many customers are repeat buyers
SELECT COUNT(*) "Repeat Customters"
FROM
(SELECT COUNT(*)
FROM fixed_sales
GROUP BY `Customer ID`
HAVING COUNT(`Customer ID`) > 1) customer_revisits;

# Total sales, units sold, and profit
SELECT CAST(SUM(Sales) AS decimal(10,2)) AS "Total Sales", CAST(SUM(Units) AS decimal(10,2)) AS "Total Units Sold", CAST(SUM(`Gross Profit`) AS decimal(10,2)) AS "Total Profit"
FROM fixed_sales;

# Sales by product
SELECT `Product Name`, CAST(SUM(Sales) AS decimal(10,2)) AS Sales
FROM fixed_sales
GROUP BY `Product Name`;

# Looking at profit in each of the two countries per month
SELECT `Country/Region`, MONTH(str_to_date(`order date`, "%c/%e/%Y")) "Month of Order", CAST(SUM(`Gross Profit`) AS decimal(10,2)) AS "Profit Per Month"
FROM fixed_sales
GROUP BY 1, 2
ORDER BY 1 DESC, 2 ASC;

# Finding the total units sold of products that have Wonka Bar in their names
SELECT SUM(wonka_bar_types)
FROM
(SELECT `Product Name`, SUM(units) wonka_bar_types
FROM fixed_sales
GROUP BY 1
HAVING `Product Name` LIKE "Wonka Bar%") wonkabarunits;



##################################
##  Shipping Distance Analysis  ##
##################################

# Creating a temp table for the exact lat/long locations of factories that produce the different types of candies
DROP TEMPORARY TABLE IF EXISTS factorylocations;
CREATE TEMPORARY TABLE factorylocations
SELECT f.factory, Latitude AS "Lat of Factory", Longitude AS "Long of Factory", p.`Product Name`
FROM factories f JOIN products p 
	ON f.factory = p.factory;

# Another temp table compling each customer's location in latitude and longitude, along with which products they purchased in each order
DROP TEMPORARY TABLE IF EXISTS customerlocations;
CREATE TEMPORARY TABLE customerlocations
SELECT fs.`Postal Code` "ZIP of Customer", lat AS "Lat of Customer", lng AS "Long of Customer", fs.`Product Name`
FROM fixed_sales fs 
	LEFT JOIN uszips us ON fs.`Postal Code` = us.zip;

SELECT *
FROM factorylocations;

SELECT *
FROM customerlocations;

# Putting them both together in another temp table that shows the distance in km each order takes to be shipped to its customer and theoretical distances if the product was produced in any of the other factories
DROP TEMPORARY TABLE IF EXISTS shippingdistance;
CREATE TEMPORARY TABLE shippingdistance
SELECT 
	factory,
	fl.`Product Name`, 
    `Long of Factory`, 
    `Lat of Factory`, 
    `Long of Customer`, 
    `Lat of Customer`, 
    `ZIP of Customer`, 
    ST_Distance_Sphere(point(`Long of Factory`, `Lat of Factory`), point(`Long of Customer`, `Lat of Customer`))/1000 AS Actual_Shipping_Distance, 
    ST_Distance_Sphere(point(-111.768036, 32.881893), point(`Long of Customer`, `Lat of Customer`))/1000 AS Dist_Lots, 
    ST_Distance_Sphere(point(-81.088371,32.076176), point(`Long of Customer`, `Lat of Customer`))/1000 AS Dist_Wicked, 
    ST_Distance_Sphere(point(-96.18115, 48.11914), point(`Long of Customer`, `Lat of Customer`))/1000 AS Dist_Sugar, 
    ST_Distance_Sphere(point(-90.565487, 41.446333), point(`Long of Customer`, `Lat of Customer`))/1000 AS Dist_Secret, 
    ST_Distance_Sphere(point(-89.971107, 35.1175), point(`Long of Customer`, `Lat of Customer`))/1000 AS Dist_Other
FROM factorylocations fl RIGHT JOIN customerlocations cl
	ON fl.`Product Name`= cl.`Product Name`;

# Evaluating the general efficiency of shipping routes from each factory
SELECT factory, AVG(Actual_Shipping_Distance), AVG(Dist_Lots), AVG(Dist_Wicked), AVG(Dist_Sugar), AVG(Dist_Secret), AVG(Dist_Other)
FROM shippingdistance
GROUP BY factory
ORDER BY AVG(Actual_Shipping_Distance);

# Final query showing, for each product, what the lowest average shipping distance would be if it were produced in its optimal factory, location-wise, 
# and the amount of shipping distance saved on average if it were to switch to its optimal factory
SELECT  
	factory, 
	`Product Name`, 
	AVG(Actual_Shipping_Distance) Actual, 
	AVG(Dist_Lots) Lots, 
	AVG(Dist_Wicked) Wicked, 
	AVG(Dist_Sugar) Sugar, 
	AVG(Dist_Secret) Secret, 
	AVG(Dist_Other) Other, 
	LEAST(AVG(Actual_Shipping_Distance), AVG(Dist_Lots), AVG(Dist_Wicked), AVG(Dist_Sugar), AVG(Dist_Secret), AVG(Dist_Other)) Min_Dist, 
    (AVG(Actual_Shipping_Distance) - LEAST(AVG(Actual_Shipping_Distance), AVG(Dist_Lots), AVG(Dist_Wicked), AVG(Dist_Sugar), AVG(Dist_Secret), AVG(Dist_Other))) AS "Difference Between Actual Distance and Lowest Distance", 
    IF(AVG(Actual_Shipping_Distance) = LEAST(AVG(Actual_Shipping_Distance), AVG(Dist_Lots), AVG(Dist_Wicked), AVG(Dist_Sugar), AVG(Dist_Secret), AVG(Dist_Other)), "Yes", "No") AS "Already Most Efficient Route?"
FROM shippingdistance
GROUP BY factory, `Product Name`
ORDER BY 10 DESC;



#####################
##  Sales Targets  ##
#####################

SELECT *
FROM targets;

# Evaluating if each division's sales hit their goals
SELECT t.division, target, Sales_Total
FROM targets t LEFT JOIN
(SELECT division, CAST(SUM(Sales) AS decimal(10,2)) AS Sales_Total
FROM fixed_sales
GROUP BY 1) ds
	ON t.division = ds.division;


