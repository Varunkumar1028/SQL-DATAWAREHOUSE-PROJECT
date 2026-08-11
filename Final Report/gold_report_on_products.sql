CREATE VIEW gold.report_products AS
WITH base_query AS(
SELECT 
	f.order_number,
	f.order_date,
	f.customer_key,
	f.sales,
	f.quantity,
	p.product_key,
	p.product_name,
	p.category,
	p.subcategory,
	p.cost

FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
on p.product_key = f.product_key
WHERE order_date IS NOT NULL) 

, product_aggregation AS (
SELECT 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
	MAX(order_date) AS last_order_date,
	COUNT(DISTINCT order_date) AS total_orders,
	COUNT(DISTINCT customer_key) AS total_customer,
	SUM(sales) AS total_sales,
	SUM(quantity) AS total_quantity,
	ROUND(AVG(CAST(sales AS FLOAT) / NULLIF(quantity, 0)), 1) AS avg_selling_price
FROM base_query
GROUP BY 
	product_key,
	product_name,
	category,
	subcategory,
	cost
)

SELECT 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	last_order_date,
	DATEDIFF(month, last_order_date, GETDATE()) AS recency_in_months,
	CASE
		WHEN total_sales > 50000 THEN 'High performer'
		WHEN total_sales >= 10000 THEN 'Mid range'
		ELSE 'Low performer'
	END AS product_segment,
	lifespan,
	total_orders,
	total_sales,
	total_quantity,
	total_customer,
	avg_selling_price,
	CASE 
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders 
	END AS avg_order_value,
	CASE 
		WHEN lifespan = 0 THEN total_sales
		ELSE total_sales / lifespan
	END AS avg_monthly_spend
FROM product_aggregation;


select * from gold.report_products