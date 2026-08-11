-- Change over time analysis 

SELECT 
YEAR(order_date) as order_year,
MONTH(order_date) as order_month,
SUM(sales) as total_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL 
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date)




-- Cummulative Ananlysis

-- Calculate the total sales per month

SELECT 
order_date,
total_sales,
SUM(total_sales) OVER ( PARTITION BY YEAR(order_date )ORDER BY order_date) AS running_total
FROM
(
SELECT 
	DATETRUNC(MONTH, order_date) AS order_date,
	SUM(sales) AS total_sales
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(MONTH, order_date) 
)t


-- Performance analysis 	


/* Analyze the yearly performance of products by comapring each products sales to
both its average sales performance and the previous years sales */


WITH yearly_product_sales AS (
SELECT 
	YEAR(f.order_date) AS order_year,
	p.product_name,
	SUM(f.sales) AS current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL 
GROUP BY 
YEAR(f.order_date),
p.product_name
)

SELECT
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
	current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
	CASE 
		WHEN 
		current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above avg'
		WHEN
		current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
		ELSE 'Avg'
	END avg_change,
	LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) py_sales,
	current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS diff_py,
	CASE 
		WHEN 
		current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
		WHEN
		current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
		ELSE 'No change'
	END py_change
	FROM yearly_product_sales
	ORDER BY product_name, order_year




	--------------------------------------------------------------------------

	WITH monthly_product_sales AS (
SELECT 
	month(f.order_date) AS order_month,
	p.product_name,
	SUM(f.sales) AS current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL 
GROUP BY 
month(f.order_date),
p.product_name
)

SELECT
	order_month,
	product_name,
	current_sales,
	AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
	current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
	CASE 
		WHEN 
		current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above avg'
		WHEN
		current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
		ELSE 'Avg'
	END avg_change,
	LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_month) py_sales,
	current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_month) AS diff_py,
	CASE 
		WHEN 
		current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_month) > 0 THEN 'Increase'
		WHEN
		current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_month) < 0 THEN 'Decrease'
		ELSE 'No change'
	END py_change
	FROM monthly_product_sales
	ORDER BY product_name, order_month;



-- Part to whole analysis

-- Which category contributes the most to overall sales

WITH category_sales AS(
SELECT 
	category,
	SUM(sales) total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
GROUP BY category)

SELECT 
	category,
	total_sales,
	SUM(total_sales) OVER() overall_sales,
	CONCAT(Round((CAST(total_sales AS FLOAT)/SUM(total_sales) OVER()) * 100, 2), '%') AS percentage_total
	FROM category_sales
	ORDER BY total_sales DESC;


-- Data segmentation

-- segement products into cost ranges an count hw many products fall into each segment


WITH product_seg AS(
SELECT
	product_key,
	product_name,
	cost,
	CASE 
		WHEN cost < 100 THEN 'Below 100'
		WHEN cost BETWEEN 100 AND 500 THEN '100 - 500'
		WHEN cost BETWEEN 500 AND 1000 THEN '500 - 1000'
		ELSE 'Above 1000'
	END cost_range
FROM gold.dim_products)

SELECT
	cost_range,
	COUNT(product_key) AS total_productts
FROM product_seg
GROUP BY cost_range
ORDER BY total_productts DESC;



WITH customer_spending AS (
SELECT 
	c.customer_key,
	SUM(f.sales) AS total_spending,
	MIN(order_date) AS first_order,
	MAX(order_date) AS last_order,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key)

SELECT 
	customer_segment,
	COUNT(customer_key) AS total_customers
FROM(
SELECT 
	customer_key,
	CASE 
		WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
		WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
		ELSE 'New'
	END customer_segment
FROM customer_spending) t
GROUP BY customer_segment
ORDER BY total_customers DESC;