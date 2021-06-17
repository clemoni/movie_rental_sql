/*What is the TOP 100 customers ? */

WITH  uc as (SELECT 
	customer_id, 
	store_id, 
	CONCAT(first_name, ' ', last_name) as full_name,
	active
	FROM customer
	WHERE active = 1),

	not_null_rental AS (SELECT
	rental_id, 
	rental_date,
	return_date
	FROM rental r
	WHERE return_date IS NOT NULL),
  
	ur as (SELECT 
	rental_id, 
	rental_date,
	return_date::DATE - rental_date::DATE AS rental_period
	FROM not_null_rental),

	customer_rental as (SELECT
	uc.customer_id,
	uc.full_name,   
	ur.rental_date,
	ur.rental_period,
	p.amount
	FROM payment p
	JOIN uc
	ON uc.customer_id = p.customer_id
	JOIN ur 
	ON ur.rental_id = p.rental_id),
  
	compiled_customer_rental  AS (SELECT
	customer_id,
	full_name,
	ROUND(SUM(amount), 1) as sum_amount,
	ROUND(AVG(rental_period), 1) AS avg_period
	FROM customer_rental
	GROUP BY  customer_id, full_name)

SELECT 
customer_id,
full_name,
sum_amount,
avg_period,
RANK() OVER (ORDER BY sum_amount DESC, avg_period ASC) AS top_customer
FROM compiled_customer_rental
LIMIT 100

/* What category of movies rent the TOP 100 customers ? */

WITH film_reduced AS (SELECT
	f.film_id,
	f.replacement_cost,
	cat.name as cat_name
	FROM film f
	JOIN film_category 
	ON f.film_id = film_category.film_id
	JOIN category cat
	ON cat.category_id = film_category.category_id),

	uc as (SELECT 
	customer_id, 
	store_id, 
	CONCAT(first_name, ' ', last_name) as full_name,
	active
	FROM customer
	WHERE active = 1),

	not_null_rental AS (SELECT
	rental_id, 
	rental_date,
	return_date
	FROM rental r
	WHERE return_date IS NOT NULL),
  
	ur as (SELECT 
	rental_id, 
	rental_date,
	return_date::DATE - rental_date::DATE AS rental_period
	FROM not_null_rental),
  
	customer_rental as (SELECT
	uc.customer_id,
	uc.full_name,   
	ur.rental_date,
	ur.rental_period,
	p.amount
	FROM payment p
	JOIN uc
	ON uc.customer_id = p.customer_id
	JOIN ur 
	ON ur.rental_id = p.rental_id),
  
	compiled_customer_rental  AS (SELECT
	customer_id,
	full_name,
	ROUND(SUM(amount), 1) as sum_amount,
	ROUND(AVG(amount), 2) AS avg_amount, 
	ROUND(AVG(rental_period), 1) AS avg_period
	FROM customer_rental
	GROUP BY  customer_id, full_name),

	top_100_customer AS (SELECT 
	customer_id,
	full_name,
	sum_amount,
	avg_period,
	RANK() OVER (ORDER BY sum_amount DESC, avg_period ASC) AS top_customer
	FROM compiled_customer_rental
	LIMIT 100),

	film_filter_top_customer AS (SELECT 
	fr.cat_name AS cat_name,
	fr.replacement_cost
	FROM film_reduced fr
	JOIN inventory i
	ON fr.film_id = i.film_id
	JOIN rental r 
	ON r.inventory_id = i.inventory_id
	where r.customer_id IN (SELECT customer_id FROM top_100_customer)),
                        
	top_cat_top_cust AS (SELECT 
	cat_name,
	COUNT(cat_name) AS nbr_film, 
	ROUND(AVG(replacement_cost), 2) AS avg_cost
	FROM film_filter_top_customer
	GROUP BY 1
	ORDER BY 2 DESC) 
                        
SELECT 
cat_name, 
nbr_film,
ROUND(nbr_film/ (SELECT SUM(nbr_film) FROM  top_cat_top_cust) *100, 2) AS percent_cat, 
avg_cost
FROM top_cat_top_cust          
                        
/* What is the repartition of Active and Inactive customers? */

WITH inactive_rental AS (
	SELECT
	c.customer_id, 
	c.active,
	p.amount, 
	r.return_date
	FROM payment p
	JOIN rental r
	ON p.rental_id = r.rental_id
	JOIN customer c
	ON c.customer_id = r.customer_id),

	inactive_rental_month AS (SELECT
	active,                
	customer_id,
	DATE_TRUNC('month', return_date) AS month, 
	SUM(amount) as sum_month
	FROM inactive_rental
	GROUP BY 1, 2, 3
	ORDER BY 1, 2),

	average_per_month AS (SELECT
	active,
	customer_id,
	COUNT(DATE_TRUNC('month', month)) AS nbr_month,
	ROUND(AVG(sum_month), 2) AS avg_spend_month
	FROM inactive_rental_month
	GROUP BY 1, 2),
     
	active_inactive AS (SELECT 
	active, 
	COUNT(customer_id) AS nbr_customer, 
	ROUND(AVG(nbr_month), 2) AS avg_nbr_month, 
	ROUND(AVG(avg_spend_month), 2) AS avg_spend_month
	FROM average_per_month
	GROUP BY 1)
      
SELECT 
CASE
      WHEN active = 1 THEN 'ACTIVE'
      ELSE 'INACTIVE'
END AS active_status,
nbr_customer, 
ROUND( nbr_customer / (SELECT SUM(nbr_customer) FROM active_inactive) * 100, 2) AS percent_nbr_customer,
avg_nbr_month,
avg_spend_month   
FROM active_inactive

/* Can we observe difference between Active and Inactive customers when the average amount spent per month is divided into quartile ? */

WITH inactive_rental AS (
	SELECT
	c.customer_id, 
	c.active,
	p.amount, 
	r.return_date
	FROM payment p
	JOIN rental r
	ON p.rental_id = r.rental_id
	JOIN customer c
	ON c.customer_id = r.customer_id),

	inactive_rental_month AS (SELECT
	active,                
	customer_id,
	DATE_TRUNC('month', return_date) AS month, 
	SUM(amount) as sum_month
	FROM inactive_rental
	GROUP BY 1, 2, 3
	ORDER BY 1, 2),

	average_per_month AS (SELECT
	active,
	customer_id,
	COUNT(DATE_TRUNC('month', month)) AS nbr_month,
	ROUND(AVG(sum_month), 2) AS avg_spend_month
	FROM inactive_rental_month
	GROUP BY 1, 2),
      
	month_quartile AS (SELECT 
	active,
	customer_id,
	nbr_month,
	avg_spend_month,
	NTILE(4) OVER (ORDER BY avg_spend_month) AS quartile
	FROM average_per_month
	ORDER BY quartile, avg_spend_month DESC),
      
	month_quartile_compiled AS (SELECT
	quartile,  
	active,
	CASE
      		WHEN active = 1 THEN 'ACTIVE'
      		ELSE 'INACTIVE'
	END AS active_status,
	COUNT(active) AS nbr_active_inactive,
	ROUND(AVG(nbr_month), 2) AS avg_nbr_month,
	ROUND(AVG(avg_spend_month), 2) AS avg_spend_month,
	MAX(avg_spend_month)AS max_month, 
	MIN(avg_spend_month) AS min_month
	FROM month_quartile
	GROUP BY 1, 2 
	ORDER BY 1 DESC, 2 DESC)
      
SELECT 
quartile,
active_status,
nbr_active_inactive,
ROUND(nbr_active_inactive/SUM(nbr_active_inactive) OVER(PARTITION BY quartile) * 100, 2) AS percent_active_inactive,
avg_nbr_month,
avg_spend_month,
max_month, 
min_month
FROM month_quartile_compiled
ORDER BY 1 DESC, 2 DESC


       
