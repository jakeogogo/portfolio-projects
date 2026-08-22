
/*
 In analytics/data modeling:
 -------------------------------------------------------------------------------------------------------------------------------
 **MEASURE**   a numeric value you calculate or aggregate.
 Measures (quantitative, aggregatable), Measures are numbers that aggregate meaningfully 
 they represent what you count, sum, or calculate.
 Examples: `Sales Amount`, `Quantity`, `Profit`, `Average Rating`.
 How to identify: Would I use this in a calculation or aggregation?
 Does summing/averaging it make business sense?
 Is it something I'd put on a dashboard as a metric?
 
 
 -------------------------------------------------------------------------------------------------------------------------------
 **DIMENSION** = descriptive information used to group, filter, or label measures.  
 Dimensions answer "who, what, when, where, which"
 they describe context around your data.        
 Examples: `Product`, `Customer`, `Region`, `Date`, `Category`.
 
 Dimensions answer "who, what, when, where, which"  - they describe context around your data.
 Examples: Date, Customer Name, Product Category, Region, Department
 How to identify: Would I use this to group by or filter?
 Is it a quality or attribute of something?
 Can I list its distinct values? (e.g., all product categories)
 
 -------------------------------------------------------------------------------------------------------------------------------
 Example: “Show total sales by region and month.”
 
 | Field         | Type      |
 |---------------|-----------|
 | Total Sales   | Measure   |
 | Region        | Dimension |
 | Month         | Dimension |
 
 A field can sometimes behave differently depending on use. 
 For instance, `Year` is normally a dimension, while `Order ID` is usually a dimension/identifier
 but `Count of Order ID` becomes a measure.
 
 order_id,         -- COUNT > measure; GROUP BY > dimension
 customer_id,        -- COUNT > measure; GROUP BY > dimension
 contact_phone_or_email,       -- COUNT > measure; GROUP BY > dimension
 order_date,     -- dimension
 order_status,       -- dimension
 payment_method,     -- dimension
 shipping_state,     -- dimension
 discount,       -- AVG > measure
 unit_price,      -- AVG > measure
 quantity,       -- TOTAL > measure
 unit_price * quantity * (1-discount) AS revenue         -- TOTAL > measure
 */
        SELECT * FROM PracticeDB.dbo.ecommerce_orders_final 
        --------------------------------------------------------------------------------------------------------------------------------------------------
        -- 01. MEASURES EXPLORATION -- most of these would have featured in "data discovery"
        --------------------------------------------------------------------------------------------------------------------------------------------------
        --------------------------------------------------------------------------------------------------------------------------------------------------
        SELECT 'Total Sales' AS #metric, SUM(revenue) AS #result
        FROM PracticeDB.dbo.ecommerce_orders_final -- Find Total Sales
        UNION ALL
        SELECT 'Items Sold', SUM(quantity)
        FROM PracticeDB.dbo.ecommerce_orders_final -- Find how many items are sold
        UNION ALL
        SELECT 'Average Selling Price', AVG(unit_price)
        FROM PracticeDB.dbo.ecommerce_orders_final -- Find the average selling price
        UNION ALL
        SELECT 'Total no. Orders', COUNT(DISTINCT order_id)
        FROM PracticeDB.dbo.ecommerce_orders_final -- Find Total no. of orders
        UNION ALL
        SELECT 'Total no. Customers', COUNT(DISTINCT customer_id)
        FROM PracticeDB.dbo.ecommerce_orders_final -- Find Total no. of customers
/*
        #metric	                #result
        Total Sales	        1297518027.70
        Items Sold	        20273.00
        Average Selling Price	70958.60
        Total no. Orders	12000.00
        Total no. Customers	1598.00

*/


--------------------------------------------------------------------------------------------------------------------------------------------------
-- 02. MAGNITUDE EXPLORATION Divide a [MEASURE]/ [DIMENSION]
--------------------------------------------------------------------------------------------------------------------------------------------------
-- order_id/ customer_id/ discount/ unit_price/ quantity/ revenue [MEASURES] use COUNT
-- BY  -- order_status/ payment_method/ shipping_state [DIMENSION]


-- TOTAL CUSTOMERS
SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM PracticeDB.dbo.ecommerce_orders_final
WHERE customer_id IS NOT NULL
--Total DISTINCT customers 1598 where customer_id IS NOT NULL
--total_customers
--1598

-- TOTAL CUSTOMERS who shipped to each state STATE
-- The apparent mismatch happens because a customer can appear in more than one shipping state, so state totals should not be summed to compare with the overall unique-customer count.
        SELECT 
        shipping_state,
        COUNT(DISTINCT customer_id) AS total_customers
        FROM PracticeDB.dbo.ecommerce_orders_final
        GROUP BY shipping_state
/*
shipping_state	total_customers
EDO	973
FCT	999
KANO	985
LAGOS	1492
OYO	916
RIVERS	971
*/

--- AVERAGE SPEND PER CUSTOMER ACROSS THE STATES  

        SELECT  shipping_state,
                COUNT (DISTINCT customer_id) AS customer_count,
                FORMAT(SUM(total_revenue), '#,###') AS total_spend,
                FORMAT((SUM(total_revenue)/COUNT (DISTINCT customer_id)), '#,###') AS Average_customer_spend
        FROM
                (
                SELECT 
                        customer_id,
                        shipping_state,
                        SUM(revenue) AS total_revenue
                FROM PracticeDB.dbo.ecommerce_orders_final
                GROUP BY shipping_state,    customer_id
                )t
        GROUP BY shipping_state
        ORDER BY (SUM(total_revenue)/COUNT (DISTINCT customer_id)) DESC



/*
shipping_state	customer_count	total_spend	Average_customer_spend
LAGOS	        1492	        480,912,172	322,327
KANO	        985	        168,576,658	171,144
EDO	        973	        165,615,529	170,211
RIVERS	        971	        163,859,393	168,753
FCT	        999	        168,377,223	168,546
OYO	        916	        150,177,053	163,949
*/
-------------------------------------------------------------------------------------------------------------------------



-- Total quantity shipped per category
SELECT category,
       FORMAT(SUM(quantity), 'N0') AS total_quantity
FROM PracticeDB.dbo.ecommerce_orders_final
GROUP BY category
ORDER BY total_quantity DESC
        /*
        category	total_quantity
        Electronics	8,086
        Fashion	        6,107
        Home	        6,080
         
         */
        -- What is total revenue generated for each payment_method-- WHERE payment_method is not NULL
SELECT
        payment_method,
        FORMAT(SUM (revenue), 'N0') AS total_revenue
FROM
        PracticeDB.dbo.ecommerce_orders_final
GROUP BY
        payment_method
HAVING
        payment_method IS NOT NULL
ORDER BY
        total_revenue DESC
        /*
         payment_method	total_revenue
         POS	        223,786,307
         Paystack	221,816,634
         Bank Transfer	216,969,681
         Card	        216,637,412
         Flutterwave	210,566,067
         Cash	        207,741,925
         */
                                        -- Find total revenue generated by each customer

        SELECT TOP 10 customer_id,
        FORMAT (SUM(revenue), '#,###') AS total_revenue
        FROM    PracticeDB.dbo.ecommerce_orders_final
        GROUP BY customer_id
        ORDER BY SUM(revenue) DESC

        /*
        customer_id	total_revenue
        NULL	        10,764,080
        CUST1824	3,291,189
        CUST1493	2,874,355
        CUST1289	2,561,075
        CUST2221	2,239,244
        CUST1337	2,229,559
        CUST2340	2,180,335
        CUST1691	2,129,931
        CUST1385	2,109,350
        CUST2146	2,098,388


        */
         -- customer_id = 'NULL' accounts for 10764080.48 revenue ()


        -- What is the distribution of the sold items across states -- TOP 10
SELECT  shipping_state,
        FORMAT(SUM (revenue),'#,###') AS total_revenue
FROM    PracticeDB.dbo.ecommerce_orders_final
GROUP BY shipping_state
ORDER BY SUM (revenue) DESC
        /*
        shipping_state	total_revenue
        LAGOS	480,912,172
        KANO	168,576,658
        FCT	168,377,223
        EDO	165,615,529
        RIVERS	163,859,393
        OYO	150,177,053
                
         */
SELECT  category,
        FORMAT(SUM (revenue),'#,###') AS total_revenue
FROM    PracticeDB.dbo.ecommerce_orders_final
GROUP BY category
ORDER BY SUM (revenue) DESC
        /*
        category	total_revenue
        Electronics	564,890,905
        Home	        502,883,312
        Fashion	        229,743,811
         
         */

SELECT  DISTINCT product
FROM           PracticeDB.dbo.ecommerce_orders_final

        --------------------------------------------------------------------------------------------------------------------------------------------------
        -- 03. RANKING ANALYSIS  -- highest/ lowest/ top 10 etc
        --------------------------------------------------------------------------------------------------------------------------------------------------
        -- Which 5 products generate the highest revenue?

SELECT     product,shipping_state,
               FORMAT( SUM (revenue),'#,###') AS total_revenue
FROM            PracticeDB.dbo.ecommerce_orders_final
GROUP BY        shipping_state, product
ORDER BY        product, SUM (revenue) DESC

select distinct product from PracticeDB.dbo.ecommerce_orders_final

        /*
product	total_revenue
Other	                717,008,567.66
Office Chair	        265,525,668.34
Wireless Headphones	156,720,385.00
Running Shoes	        122,737,667.55
USB-C Charger	        35,525,739.15

         */
        -- Which 5 worst-performing products in terms of sales? Reverse Order by omitting DESC
SELECT  product,
        FORMAT(SUM (revenue), '#,##0.00')  AS total_revenue
FROM
        PracticeDB.dbo.ecommerce_orders_final
GROUP BY
        product
order by
        SUM (revenue) DESC

        /*

        product	        total_revenue
        Office Chair	265,525,668.34
        Smart Watch	201,735,243.49
        External SSD	173,521,564.17
        Wireless Headphones	156,720,385.00
        Coffee Maker	126,908,642.99
        Running Shoes	122,737,667.55
        Blender	        106,814,620.18
        Backpack	75,257,343.94
        USB-C Charger	35,525,739.15
        T-Shirt	        32,771,152.89        

         */
        -- Find Top 10 customers that generated the highest revenue
SELECT  TOP 10 customer_id,
        FORMAT(SUM (revenue), 'N0') AS total_revenue
FROM    PracticeDB.dbo.ecommerce_orders_final
WHERE   customer_id IS NOT NULL
GROUP BY customer_id
order by SUM (revenue) DESC
        /*
         customer_id	total_revenue
         CUST1824	3,291,189
         CUST1493	2,874,355
         CUST1289	2,561,075
         CUST2221	2,239,244
         CUST1337	2,229,559
         CUST2340	2,180,335
         CUST1691	2,129,931
         CUST1385	2,109,350
         CUST2146	2,098,388
         CUST1328	2,092,333
         */

/*         -- Find Bottom 10 customers that generated the lowest revenue
customer_id	total_revenue
CUST1621	15,354
CUST1188	30,306
CUST1859	32,415
CUST1148	66,627
CUST1401	76,004
CUST1414	80,655
CUST2201	81,474
CUST1749	89,646
CUST1157	91,120
CUST1866	99,049
*/

        -- Find the 3 customers with the fewest orders placed


SELECT  TOP 3   customer_id,
                COUNT (order_id) AS order_count
FROM            PracticeDB.dbo.ecommerce_orders_final
WHERE           customer_id IS NOT NULL
GROUP BY        customer_id
order by        COUNT (order_id) DESC 

/*
customer_id	order_count
CUST2413	17
CUST1493	17
CUST1550	16
*/
-----------------------------------------------------------------------------------------------------------------------------------------
        -- 04. TRENDS AND CHANGE OVER TIME 
-----------------------------------------------------------------------------------------------------------------------------------------
        --Sales performance over time MONTH & YEAR
SELECT
        MONTH(order_date) AS num_month,
        YEAR(order_date) AS num_year,
        FORMAT(SUM(revenue), 'N0') As revenue
FROM
        PracticeDB.dbo.ecommerce_orders_final
GROUP BY
        YEAR(order_date),
        MONTH(order_date)
ORDER BY
        YEAR(order_date),
        MONTH(order_date)
/*
num_month	num_year	revenue
1	2025	67,564,462
2	2025	63,635,230
3	2025	70,288,726
4	2025	69,143,376
5	2025	70,840,859
6	2025	63,405,814
7	2025	63,338,734
8	2025	66,814,104
9	2025	68,704,363
10	2025	68,578,064
11	2025	66,432,307
12	2025	75,125,400
1	2026	70,782,341
2	2026	56,817,314
3	2026	76,869,644
4	2026	68,628,052
5	2026	76,190,311
6	2026	72,090,048
7	2026	62,268,877
*/

SELECT
        datename(year,(order_date)),
        datename(month,(order_date)),
        year(order_date),
        month(order_date),
        SUM(revenue)
FROM
        PracticeDB.dbo.ecommerce_orders_final
GROUP BY
        datename(year,(order_date)),
        datename(month,(order_date)),
        year(order_date),
        month(order_date)
ORDER BY
        year(order_date),
        month(order_date);

/*
(No column name)	(No column name)	(No column name)	(No column name)	(No column name)
2025	January	2025	1	67564462.24
2025	February	2025	2	63635229.59
2025	March	2025	3	70288726.47
2025	April	2025	4	69143375.63
2025	May	2025	5	70840858.68
2025	June	2025	6	63405814.04
2025	July	2025	7	63338734.27
2025	August	2025	8	66814103.53
2025	September	2025	9	68704363.05
2025	October	2025	10	68578064.39
2025	November	2025	11	66432306.78
2025	December	2025	12	75125400.29
2026	January	2026	1	70782340.97
2026	February	2026	2	56817314.28
2026	March	2026	3	76869644.28
2026	April	2026	4	68628052.39
2026	May	2026	5	76190310.97
2026	June	2026	6	72090048.42
2026	July	2026	7	62268877.43
*/


-----------------------------------------------------------------------------------------------------------------------------------------
-- 05. CUMULATIVE ANALYSIS
-----------------------------------------------------------------------------------------------------------------------------------------
-- Calculate the total sales per MONTH &  -- and the running total of sales over time
SELECT
        order_month,
        FORMAT(total_sales, 'N0') as monthly_sales,
        FORMAT(
                (
                        SUM(total_sales) OVER (
                                ORDER BY
                                        order_month
                        )
                ),
                'N0'
        ) AS running_total_sales
FROM
        (
                SELECT
                        DATETRUNC (MONTH,(order_date)) AS order_month,
                        SUM(revenue) AS total_sales
                FROM
                        PracticeDB.dbo.ecommerce_orders_final
                WHERE
                        order_date IS NOT NULL
                GROUP BY
                        DATETRUNC (MONTH,(order_date))
        ) t
ORDER BY
        order_month
/*

order_month	monthly_sales	running_total_sales
2025-01-01	67,564,462	67,564,462
2025-02-01	63,635,230	131,199,692
2025-03-01	70,288,726	201,488,418
2025-04-01	69,143,376	270,631,794
2025-05-01	70,840,859	341,472,653
2025-06-01	63,405,814	404,878,467
2025-07-01	63,338,734	468,217,201
2025-08-01	66,814,104	535,031,304
2025-09-01	68,704,363	603,735,668
2025-10-01	68,578,064	672,313,732
2025-11-01	66,432,307	738,746,039
2025-12-01	75,125,400	813,871,439
2026-01-01	70,782,341	884,653,780
2026-02-01	56,817,314	941,471,094
2026-03-01	76,869,644	1,018,340,738
2026-04-01	68,628,052	1,086,968,791
2026-05-01	76,190,311	1,163,159,102
2026-06-01	72,090,048	1,235,249,150
2026-07-01	62,268,877	1,297,518,028
*/


SELECT
        num_month,
        num_year,
        FORMAT(revenue, 'N0') AS monthly_revenue,
        FORMAT (
                SUM(revenue) OVER (PARTITION BY num_year ORDER BY num_month),'N0') AS running_total_sales              
        -- Always aggregate first, format second. FORMAT is for display/output, not for intermediate calculations.
FROM
        (
        SELECT
                MONTH(order_date) AS num_month,
                YEAR(order_date) AS num_year,
                SUM(revenue) As revenue
        FROM    PracticeDB.dbo.ecommerce_orders_final
        GROUP BY YEAR(order_date),
                MONTH(order_date)
        ) t 

/*
num_month       num_yearmonthly_revenue	running_total_sales
1	        2025	67,564,462	67,564,462
2	        2025	63,635,230	131,199,692
3	        2025	70,288,726	201,488,418
4	        2025	69,143,376	270,631,794
5	        2025	70,840,859	341,472,653
6	        2025	63,405,814	404,878,467
7	        2025	63,338,734	468,217,201
8	        2025	66,814,104	535,031,304
9	        2025	68,704,363	603,735,668
10	        2025	68,578,064	672,313,732
11	        2025	66,432,307	738,746,039
12	        2025	75,125,400	813,871,439

1	        2026	70,782,341	70,782,341
2	        2026	56,817,314	127,599,655
3	        2026	76,869,644	204,469,300
4	        2026	68,628,052	273,097,352
5	        2026	76,190,311	349,287,663
6	        2026	72,090,048	421,377,711
7	        2026	62,268,877	483,646,589
*/


--------------------------------------------------------------------------------------------------------------------------------
 -- 06. PERFORMANCE ANALYSIS
-----------------------------------------------------------------------------------------------------------------------------------------
        --Analyze the yearly performance of products by comparing their sales to both average sales performance of the product and \
        --the previous year sales
SELECT
        product,
        DATETRUNC(year, order_date) AS year,
        SUM(revenue) AS yearly_sales,
        AVG(SUM(revenue)) OVER (PARTITION BY product) AS avg_product_sales,
        LAG(SUM(revenue)) OVER (
                PARTITION BY product
                ORDER BY
                        DATETRUNC(year, order_date)
        ) AS prior_year_sales,
        SUM(revenue) - AVG(SUM(revenue)) OVER (PARTITION BY product) AS variance_from_avg,
        SUM(revenue) - LAG(SUM(revenue)) OVER (
                PARTITION BY product
                ORDER BY
                        DATETRUNC(year, order_date)
        ) AS yoy_change,
        ROUND(
                100.0 * (
                        SUM(revenue) - LAG(SUM(revenue)) OVER (
                                PARTITION BY product
                                ORDER BY
                                        DATETRUNC(year, order_date)
                        )
                ) / LAG(SUM(revenue)) OVER (
                        PARTITION BY product
                        ORDER BY
                                DATETRUNC(year, order_date)
                ),
                2
        ) AS yoy_growth_pct
FROM
        PracticeDB.dbo.ecommerce_orders_final
WHERE
        order_date IS NOT NULL
GROUP BY
        product,
        DATETRUNC(year, order_date)
ORDER BY
        product,
        year
SELECT
        *,
        AVG(annual_product_revenue) OVER (PARTITION BY product) AS avg_product_revenue,
        LAG(annual_product_revenue, 1) OVER (
                PARTITION BY product
                ORDER BY
                        yearn
        ) AS prior_year_revenue,
        annual_product_revenue - AVG(annual_product_revenue) OVER (PARTITION BY product) AS variance_from_avg,
        annual_product_revenue - LAG(annual_product_revenue, 1) OVER (
                PARTITION BY product
                ORDER BY
                        yearn
        ) AS yoy_change,
        (
                annual_product_revenue - LAG(annual_product_revenue, 1) OVER (
                        PARTITION BY product
                        ORDER BY
                                yearn
                )
        ) / LAG(annual_product_revenue, 1) OVER (
                PARTITION BY product
                ORDER BY
                        yearn
        ) * 100 AS yoy_pct_change
FROM
        (
                SELECT
                        product,
                        DATETRUNC(year, order_date) AS yearn,
                        SUM(revenue) AS annual_product_revenue,
                        AVG(revenue) AS avg_product_revenue
                FROM
                        PracticeDB.dbo.ecommerce_orders_final
                GROUP BY
                        product,
                        DATETRUNC(year, order_date)
        ) t -----------------------------------------------------------------------------------------------------------------------------------------
        -- 07. DATA SEGMENTATION  -- Segment products into cost ranges and count how many fall into each segment
        -----------------------------------------------------------------------------------------------------------------------------------------
SELECT
        unit_price
from
        PracticeDB.dbo.ecommerce_orders_final;

-------------
WITH grange AS (
        SELECT
                *,
                MAX(unit_price) OVER () - (MIN(unit_price) OVER () / 4) AS bucket_range
        FROM
                PracticeDB.dbo.ecommerce_orders_final
),
segment AS (
        SELECT
                *,
                CASE
                        WHEN unit_price <= bucket_range THEN 'budget'
                        WHEN unit_price > bucket_range
                        AND unit_price <= 2 * bucket_range THEN 'standard'
                        WHEN unit_price > 2 * bucket_range
                        AND unit_price <= 3 * bucket_range THEN 'premium'
                        WHEN unit_price > 3 * bucket_range THEN 'luxury'
                END AS price_range
        FROM
                grange
)
SELECT
        price_range,
        COUNT (order_id)
FROM
        segment
GROUP BY
        price_range -----------------------------------------------------------------------------------------------------------------------------------------
        -- 08. PART-TO-WHOLE ANALYSIS  -- Which categories contribute the most to the overall sales?
        -----------------------------------------------------------------------------------------------------------------------------------------
SELECT
        TOP 1 category,
        FORMAT(SUM(revenue), 'N0') As highest_selling_category
FROM
        PracticeDB.dbo.ecommerce_orders_final
GROUP BY
        category
ORDER BY
        SUM(revenue) DESC ------  Pareto-style cumulative contribution: category
        WITH category_sales AS (
                SELECT
                        category,
                        SUM(revenue) AS total_sales
                FROM
                        PracticeDB.dbo.ecommerce_orders_final
                GROUP BY
                        category
        )
SELECT
        category,
        FORMAT(total_sales, 'N0') AS total_sales,
        CAST(
                100.0 * total_sales / SUM(total_sales) OVER () AS DECIMAL(10, 2)
        ) AS sales_percent,
        CAST(
                100.0 * SUM(total_sales) OVER (
                        ORDER BY
                                total_sales DESC ROWS BETWEEN UNBOUNDED PRECEDING
                                AND CURRENT ROW
                ) / SUM(total_sales) OVER () AS DECIMAL(10, 2)
        ) AS cumulative_sales_percent
FROM
        category_sales
ORDER BY
        total_sales DESC;

------ Pareto-style cumulative contribution: payment_method
WITH payment_method_sales AS (
        SELECT
                payment_method,
                SUM(revenue) AS total_sales
        FROM
                PracticeDB.dbo.ecommerce_orders_final
        GROUP BY
                payment_method
)
SELECT
        payment_method,
        FORMAT(total_sales, 'N0') AS total_sales,
        CAST(
                100.0 * total_sales / SUM(total_sales) OVER () AS DECIMAL(10, 2)
        ) AS sales_percent,
        CAST(
                100.0 * SUM(total_sales) OVER (
                        ORDER BY
                                total_sales DESC ROWS BETWEEN UNBOUNDED PRECEDING
                                AND CURRENT ROW
                ) / SUM(total_sales) OVER () AS DECIMAL(10, 2)
        ) AS cumulative_sales_percent
FROM
        payment_method_sales
ORDER BY
        total_sales DESC;

--========================================================================================================================
-- BUSINESS INSIGHTS
--========================================================================================================================
/*
 
1. Executive summary


2. Objective and business context
3. Key insights
   3.1 Insight 1: headline + impact
   3.2 Insight 2: headline + impact
   3.3 Insight 3: headline + impact
4. Opportunities and risks by segment
5. Recommendations and priorities
6. Limitations and assumptions
7. Next steps / measurement plan
8. Appendix: methodology, detailed EDA, supporting tables

The main report should answer: 
What should the business do differently, why, and how will we know it worked?






------------------------------------------------------------------------------------------------------------------------------------
Keep raw descriptive EDA—distributions, null checks, outliers, and full correlation matrices
—in the appendix unless they directly affect a decision. 

 */
