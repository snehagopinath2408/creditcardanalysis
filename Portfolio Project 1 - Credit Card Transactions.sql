
-- Table outline
SELECT* 
FROM credit_card_transcations
LIMIT 100;

-- Types of card type
SELECT card_type
FROM credit_card_transcations
GROUP BY card_type;

-- Types of Expenses
SELECT exp_type
FROM credit_card_transcations
GROUP BY exp_type;

-- Total Spend by Card Type
SELECT card_type, SUM(amount) AS total_spend_bycardtype
FROM credit_card_transcations
GROUP BY card_type;

-- Monthly spend
SELECT MONTH(transaction_date) AS month, SUM(amount) AS total_spend
FROM credit_card_transcations
GROUP BY MONTH(transaction_date)
ORDER BY month;

-- Gender-wise Spending 
SELECT gender, SUM(amount) AS total_spend
FROM credit_card_transcations
GROUP BY gender;

-- top 10 cities by total spend

SELECT city, SUM(amount) AS total_spend
FROM credit_card_transcations
GROUP BY city
LIMIT 10;

-- Expense type and their number of transactions and finding the type with highest number of transactions
SELECT exp_type, COUNT(*) AS number_of_transactions
FROM credit_card_transcations
GROUP BY exp_type
ORDER BY number_of_transactions DESC;


--  top 5 cities with highest spends and their percentage contribution of total credit card spends 
WITH cte AS(
SELECT city, SUM(amount) as spends
FROM credit_card_transcations
GROUP BY city
),
cte1 AS(
SELECT *,
DENSE_RANK() OVER(ORDER BY spends DESC) as rn
FROM cte
)
SELECT rn,city,spends,
(spends/(SELECT SUM(amount) FROM credit_card_transcations))*100 AS percentage_contribution
FROM cte1
WHERE rn<=5;

-- highest spend month for each year and amount spent in that month for each card type
WITH cte AS(
SELECT card_type, YEAR(transaction_date) AS year,  MONTHNAME(transaction_date) AS month, SUM(amount) AS spend
FROM credit_card_transcations
GROUP BY card_type, YEAR(transaction_date), MONTHNAME(transaction_date)
ORDER BY year, month
),
cte1 AS(
SELECT *,
DENSE_RANK() OVER( PARTITION BY card_type ORDER BY spend DESC) AS rn
FROM cte
 )
SELECT year, month, card_type, spend
FROM cte1
WHERE rn=1;

-- 3- transaction details(all columns from the table) for each card type when
	-- it reaches a cumulative of 1000000 total spends
    WITH cte AS(
    SELECT *,
    SUM(amount) OVER(PARTITION BY card_type ORDER BY transaction_date, transaction_id) as c_sum
    FROM credit_card_transcations
    ),
    cte1 AS(
    SELECT *,
    DENSE_RANK() OVER(PARTITION BY card_type ORDER BY c_sum) AS rn
    FROM cte
    WHERE c_sum>=1000000
    )
    SELECT  transaction_id, city, transaction_date, card_type, exp_type, gender, amount
    FROM cte1
    WHERE rn=1;
    
-- 4- city which had lowest percentage spend for gold card type 
WITH cte AS(
SELECT city, SUM(amount) AS total_spend,
(SUM(amount)/(SELECT SUM(amount) FROM credit_card_transcations WHERE card_type='Gold'))*100 AS percentage_spend
FROM credit_card_transcations
WHERE card_type='Gold'
GROUP BY city
)
SELECT *
FROM cte
WHERE percentage_spend=(SELECT MIN(percentage_spend) FROM cte);

-- 5-  city, highest_expense_type , lowest_expense_type 
WITH cte AS(
SELECT city, exp_type, SUM(amount) as tot
FROM credit_card_transcations
GROUP BY city,exp_type
),
cte1 AS(
SELECT *,
DENSE_RANK()OVER(PARTITION BY city ORDER BY tot DESC) AS desc_rn,
DENSE_RANK()OVER(PARTITION BY city ORDER BY tot ) AS asc_rn
FROM cte
 )
SELECT city,
    MIN(CASE WHEN asc_rn=1 THEN exp_type END) AS lowest_expense_type,
	MAX( CASE WHEN desc_rn=1 THEN exp_type END) AS highest_expense_type
FROM cte1
GROUP BY city;

-- another way to do it
WITH cte AS (
    SELECT city, 
           exp_type, 
           SUM(amount) AS amount_each_exp
    FROM credit_card_transcations
    GROUP BY city, exp_type
),
cte1 AS (
    SELECT *,
           DENSE_RANK() OVER(PARTITION BY city ORDER BY amount_each_exp) AS lowest_exp,
           DENSE_RANK() OVER(PARTITION BY city ORDER BY amount_each_exp DESC) AS highest_exp
    FROM cte
),
lowest_exp_type AS (
    SELECT city, exp_type
    FROM cte1
    WHERE lowest_exp = 1
),
highest_exp_type AS (
    SELECT city, exp_type
    FROM cte1
    WHERE highest_exp = 1
)
SELECT low.city, high.exp_type AS highest_expense_type, low.exp_type AS lowest_expense_type
FROM lowest_exp_type AS low
JOIN highest_exp_type AS high ON low.city = high.city;


-- 6-percentage contribution of spends by females for each expense type 
SELECT exp_type,
(SUM(CASE WHEN UPPER(gender)='F' THEN amount ELSE 0 END)/SUM(amount))*100 AS  percent_contribution
FROM credit_card_transcations
GROUP BY exp_type
ORDER BY percent_contribution DESC;

-- 7- which card and expense type combination saw highest month over month growth in Jan-2014 
WITH cte AS (
SELECT card_type, exp_type, YEAR(transaction_date) AS year, MONTH(transaction_date) AS month, SUM(amount) AS cur_amt
FROM credit_card_transcations
GROUP BY card_type, exp_type, YEAR(transaction_date), MONTH(transaction_date)
),
cte1 AS (
SELECT *,
LAG(cur_amt) OVER(PARTITION BY card_type, exp_type ORDER BY year, month) AS previous_amt
FROM cte
), 
cte2 AS (
SELECT *,
cur_amt - previous_amt AS monthly_growth   
FROM cte1
WHERE previous_amt IS NOT NULL AND year=2014 AND month=1
),
 cte3 AS (
SELECT card_type, exp_type, MAX(monthly_growth) AS highest_growth
FROM cte2
GROUP BY card_type, exp_type
)
SELECT *
FROM cte3
WHERE highest_growth = (SELECT MAX(highest_growth) FROM cte3);

-- 8- during weekends which city has highest total spend to total no of transcations ratio 
WITH cte AS(
SELECT city, SUM(amount) AS total_spend, COUNT(*) AS no_of_transcations
FROM credit_card_transcations
WHERE WEEKDAY(transaction_date) IN (5,6)
GROUP BY city
)
SELECT city, total_spend/ no_of_transcations AS totalspend_to_numoftransactions_ratio  
FROM cte
WHERE total_spend/ no_of_transcations =(SELECT MAX(total_spend/ no_of_transcations) FROM cte);


-- 9- which city took least number of days to reach its 500th transaction after the first transaction in that city
WITH cte AS(
SELECT *,
ROW_NUMBER() OVER(PARTITION BY city ORDER BY transaction_date, transaction_id) as rn
FROM credit_card_transcations
),
cte1 AS(
SELECT city,
TIMESTAMPDIFF(DAY, MIN(transaction_date), MAX(transaction_date)) as datediff1
FROM cte
WHERE rn=1 OR rn=500
GROUP BY city
HAVING COUNT(1)=2 -- Ensures that each city has exactly two rows (one for the first transaction and one for the 500th transaction) 
) 
SELECT city,datediff1
FROM cte1
WHERE datediff1=(SELECT MIN(datediff1) FROM cte1);




