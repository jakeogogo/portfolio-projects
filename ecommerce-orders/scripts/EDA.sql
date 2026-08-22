

----------------------------------------------------------------------------------------------------------------------
-- STEP 0: CREATE BACKUP OF RAW DATA
----------------------------------------------------------------------------------------------------------------------
-- Backup     >>  Create a backup of the raw data    >>`SELECT * INTO FROM`       
    
    DROP TABLE IF EXISTS PracticeDB.dbo.ecommerce_orders_backup;
    SELECT  * 
    INTO PracticeDB.dbo.ecommerce_orders_backup 
    FROM PracticeDB.dbo.ecommerce_orders_raw ;
    GO

    SELECT  * FROM PracticeDB.dbo.ecommerce_orders_backup ; --Check that backup is done


    ----------------------------------------------------------------------------------------------------------
    CREATE SYNONYM orders_raw FOR PracticeDB.dbo.ecommerce_orders_raw; 
   -- DROP  SYNONYM orders_raw       -- drop synonym when done
    GO



----------------------------------------------------------------------------------------------------------------------
-- STEP 1: PROFILE STRUCTURE
----------------------------------------------------------------------------------------------------------------------

SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ecommerce_orders_raw'
ORDER BY ORDINAL_POSITION;
GO
-- customer_id, email, phone are only NULLABLE columns
/*
order_date	datetime2
unit_price	float
discount	float
payment_method	nvarchar
shipping_city	nvarchar
shipping_state	nvarchar
order_status	nvarchar
order_id	nvarchar
customer_id	nvarchar
customer_name	nvarchar
email	nvarchar
phone	nvarchar
product	nvarchar
category	nvarchar
quantity	smallint
*/

----------------------------------------------------------------------------------------------------------------------
-- STEP 2: PROFILE COMPLETENESS (NULLs)
----------------------------------------------------------------------------------------------------------------------

    SELECT COUNT(*) FROM orders_raw         -- 12120 rows
    SELECT DISTINCT COUNT(customer_id)      -- 12020 unique customers
    FROM orders_raw      
    --
    SELECT    
        COUNT(*) - COUNT(order_id),
        COUNT(*) - COUNT(order_date),
        COUNT(*) - COUNT(customer_id), --- 100 nulls
        COUNT(*) - COUNT(customer_name),
        COUNT(*) - COUNT(email), -- 2440 nulls
        COUNT(*) - COUNT(phone), -- 3066 nulls
        COUNT(*) - COUNT(product),
        COUNT(*) - COUNT(category),
        COUNT(*) - COUNT([quantity]),
        COUNT(*) - COUNT([unit_price]),
        COUNT(*) - COUNT([discount]),
        COUNT(*) - COUNT([payment_method]),
        COUNT(*) - COUNT([shipping_city]),
        COUNT(*) - COUNT([shipping_state]),
        COUNT(*) - COUNT([order_status])
    FROM      orders_raw;


----------------------------------------------------------------------------------------------------------------------
-- STEP 3: PROFILE UNIQUENESS & CARDINALITY
----------------------------------------------------------------------------------------------------------------------
-- Profile uniqueness >> Identify IDs, duplicates, cardinality  >> `COUNT`, `COUNT(DISTINCT)`    

    SELECT 'total_rows' AS #metric, COUNT(*) AS #result FROM PracticeDB.dbo.ecommerce_orders_raw
    UNION ALL
    SELECT 'unique_order_ids', COUNT(DISTINCT order_id) FROM PracticeDB.dbo.ecommerce_orders_raw
    UNION ALL
    SELECT 'unique_customers', COUNT(DISTINCT customer_id) FROM PracticeDB.dbo.ecommerce_orders_raw
    UNION ALL
    SELECT 'max_unit_price', ROUND(MAX(unit_price), 2)  FROM PracticeDB.dbo.ecommerce_orders_raw
    UNION ALL
    SELECT 'min_unit_price', ROUND(MIN(unit_price), 2) FROM PracticeDB.dbo.ecommerce_orders_raw
    UNION ALL
    SELECT 'max_discount', ROUND(MAX(discount), 2) FROM PracticeDB.dbo.ecommerce_orders_raw
    UNION ALL
    SELECT 'min_discount', ROUND(MIN(discount), 2)  FROM PracticeDB.dbo.ecommerce_orders_raw
    UNION ALL
    SELECT 'unit_price_negative_count', SUM(CASE WHEN unit_price < 0 THEN 1 ELSE 0 END) FROM PracticeDB.dbo.ecommerce_orders_raw
    UNION ALL
    SELECT 'discount_negative_count', SUM(CASE WHEN discount < 0 THEN 1 ELSE 0 END) FROM PracticeDB.dbo.ecommerce_orders_raw
    UNION ALL
    SELECT 'date_range_days', CAST(DATEDIFF(DAY, MIN(order_date), MAX(order_date)) AS VARCHAR) FROM PracticeDB.dbo.ecommerce_orders_raw;
    GO

    -- Check for duplicate rows on business key
    WITH dup_check AS (
        SELECT ROW_NUMBER() OVER (PARTITION BY order_id, customer_id, product, order_date ORDER BY order_id) AS rn
        FROM PracticeDB.dbo.ecommerce_orders_raw
        )
    SELECT COUNT(*) AS duplicate_rows FROM dup_check WHERE rn > 1;
    GO

    -- Distinct values for categorical fields
    SELECT DISTINCT payment_method , COUNT (order_id) AS total_count
    FROM PracticeDB.dbo.ecommerce_orders_raw
        GROUP BY payment_method
        ORDER BY total_count DESC


    SELECT DISTINCT product , COUNT (order_id) AS total_count
    FROM PracticeDB.dbo.ecommerce_orders_raw
        GROUP BY product
        ORDER BY product 

    SELECT order_status AS field_name, order_count  FROM (
        SELECT DISTINCT order_status, COUNT(order_id) AS order_count FROM PracticeDB.dbo.ecommerce_orders_raw
        GROUP BY order_status
        ) t;
    GO


    GO
    SELECT shipping_city, shipping_state, COUNT(order_id) AS order_count
    FROM orders_raw
    GROUP BY shipping_city, shipping_state
----------------------------------------------------------------------------------------------------------------------
-- STEP 4: DETECT INVALID DATA TYPES
----------------------------------------------------------------------------------------------------------------------
-- Detect invalid data types >> Test dates, numbers, integers, decimals   >> `TRY_CONVERT`, `TRY_CAST`  

    SELECT  'invalid_dates' AS metric , COUNT(*) AS #result
    FROM    orders_raw
    WHERE   TRY_CONVERT(DATE, order_date) IS NULL AND order_date IS NOT NULL
    UNION ALL
    SELECT  'invalid_numeric' AS metric, COUNT(*) AS #result
    FROM    orders_raw
    WHERE   (TRY_CONVERT(DECIMAL(18,2), unit_price) IS NULL AND unit_price IS NOT NULL)
        OR  (TRY_CONVERT(DECIMAL(10,2), discount) IS NULL AND discount IS NOT NULL);



----------------------------------------------------------------------------------------------------------------------
-- STEP 5-12: TRANSFORMATION PIPELINE (Clean & Transform)
----------------------------------------------------------------------------------------------------------------------
/*
| 5  | Clean whitespace          | Remove leading/trailing spaces             | `TRIM`, `LTRIM`, `RTRIM`          |
| 6  | Standardize text          | Case, spelling, formats, categories        | `UPPER`, `LOWER`, `CASE`          |
| 7  | Clean special fields      | Email, phone, postcode, URLs, etc.         | `REPLACE`, `PATINDEX`, `LIKE`     |
| 8  | Handle missing values     | Decide `NULL`, default, unknown, or remove | `NULLIF`, `COALESCE`              |
| 9  | Apply business rules      | Validate ranges and logical relationships  | `CASE`                            |
*/


SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'ecommerce_orders_raw' -- use the pre-synonym table name , then copy name from results window
ORDER BY data_type;

---------------------------------------------------------------------------------------------------------------------------------------
-- 10 >>  Handle duplicates  >>  Keep correct/latest record     >>   `ROW_NUMBER()`      
--   Resolve Business-key duplicates (order_id, order_date, customer_name, product)

DROP TABLE IF EXISTS PracticeDB.dbo.ecommerce_orders_clean
GO
--------------
WITH 
ranked AS 
    (                   -- Step 10: Remove duplicates, keep newest by order_date DESC
    SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id, order_date, customer_name, product ORDER BY order_date DESC) AS rn
    FROM orders_raw
    ),
--------------
deduped AS 
    (                   -- Keep newest (select rn = 1 after ordering by order_date DESC)
    SELECT * 
    FROM ranked 
    WHERE rn = 1    
    ),
--------------
standardized AS 
    (                   -- Steps 5-9: Clean whitespace, standardize text, validate formats, handle nulls, apply business rules
    SELECT 
        NULLIF(NULLIF(NULLIF (TRIM (order_id),''), 'NULL'), 'N/A') AS order_id,
        TRY_CONVERT(DATE, order_date) AS order_date,
        NULLIF(NULLIF(NULLIF (TRIM (customer_id),''), 'NULL'), 'N/A') AS customer_id,
        COALESCE (NULLIF(NULLIF(NULLIF (TRIM (customer_name),''), 'NULL'), 'N/A'), 'Unknown') AS customer_name,
        COALESCE (NULLIF(NULLIF(NULLIF (TRIM (email),''), 'NULL'), 'N/A'), 'Unknown')	AS  email,

        phone,          -- Clean Phone: strip out non-digit characters using a pattern
        TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(phone,' ', ''),'-', ''),'(', ''),')', ''),'/', ''),'+', ''),'.', '')) 	
        AS cleaned_phone,             
        COALESCE (NULLIF(NULLIF(NULLIF (TRIM (product),''), 'NULL'), 'N/A'), 'Unknown')	AS  product,     
        COALESCE (NULLIF(NULLIF(NULLIF (TRIM (category),''), 'NULL'), 'N/A'), 'Unknown')	AS  category,     
        TRY_CONVERT (INT, (quantity)) AS quantity,
        TRY_CONVERT (DECIMAL (18,2), unit_price) AS unit_price,
        TRY_CONVERT(DECIMAL (10,2), discount ) AS discount,
        COALESCE (NULLIF(NULLIF(NULLIF (TRIM (payment_method),''), 'NULL'), 'N/A'), 'Unknown')	AS payment_method,
        UPPER (COALESCE (NULLIF(NULLIF(NULLIF (TRIM (shipping_city),''), 'NULL'), 'N/A'), 'Unknown')) AS shipping_city,
        UPPER (COALESCE (NULLIF(NULLIF(NULLIF (TRIM (shipping_state),''), 'NULL'), 'N/A'), 'Unknown'))	AS shipping_state,      
        COALESCE (NULLIF(NULLIF(NULLIF (TRIM (order_status),''), 'NULL'), 'N/A'), 'Unknown')	AS  order_status,
        rn  
    FROM deduped
    ),
--------------
flagged AS
    (SELECT
        *,
        CASE WHEN TRIM(customer_id) IS NULL OR customer_id IN ('NULL, N/A','',' ') THEN 1 ELSE 0  END AS is_customer_id_missing,
        CASE WHEN TRIM(email) IS NULL OR email IN ('NULL, N/A','',' ') THEN 1 ELSE 0  END AS is_email_id_missing,
        CASE WHEN TRIM(phone) IS NULL OR phone IN ('NULL, N/A','',' ') THEN 1 ELSE 0  END AS is_phone_missing
    FROM standardized    
    ),
--------------
validated AS            -- Step 7: Validate email and phone formats
    (SELECT
        *,                     
        CASE            -- email Validation 
            WHEN email LIKE '%_@_%_._%'    -- CAN have any of the chaeracter set > use 'LIKE'
                AND email NOT LIKE '%[^A-Za-z0-9._%+@-]%'  -- -- hyphen moved to end, MUST have all the character set > use 'NOT LIKE'
                AND email NOT LIKE '%@%@%' THEN 'Valid'  -- MUST have all the character set > use 'NOT LIKE'
            ELSE 'Invalid'
        END AS email_status,      
        CASE
            WHEN product LIKE '%Office%' THEN 'Office Chair'
            WHEN product LIKE '%USB%' THEN 'USB-C Charger'
            WHEN product LIKE '%Running%' THEN 'Running Shoes'
            WHEN product LIKE '%Wireless%' THEN 'Wireless Headphones'
            ELSE product
        END AS product_valid,
        CASE            -- phone Validation 
            WHEN cleaned_phone NOT LIKE '%[^0-9]%' -- MUST have all the character set > use 'NOT LIKE'
            AND LEN(cleaned_phone) BETWEEN 7 AND 15 THEN 'Valid'
            ELSE 'Invalid'
        END AS phone_status,
                        -- STEP 9: Apply business logic -- Lagos Abuja city/state reconciliation
        CASE 
            WHEN shipping_state != 'lagos' AND shipping_city IN ('lagos', 'LAGOS', 'Ikeja', 'Lagos', 'Lekki') THEN 'LAGOS' 
            WHEN shipping_state != 'FCT' AND shipping_city IN ('ABUJA', 'Abuja') THEN 'FCT' 
            ELSE shipping_state 
        END AS shipping_state_valid
    FROM flagged
    )
--------------
SELECT 
    *,
    CASE    WHEN phone_status = 'Valid' THEN cleaned_phone ---COALESCE(cleaned_phone, email, 'Unknown')  
            WHEN email_status = 'Valid' THEN email ---COALESCE(cleaned_phone, email, 'Unknown')  
            ELSE 'No valid contact'
    END AS contact_primary,
    TRY_CONVERT(DECIMAL(10,2), (quantity * unit_price *(1-discount))) AS revenue
INTO PracticeDB.dbo.ecommerce_orders_clean 
FROM validated 
--------------         
GO
SELECT * FROM PracticeDB.dbo.ecommerce_orders_clean


----------------------------------------------------------------------------------------------------------------------
-- STEP 13: FINAL QUALITY AUDIT
----------------------------------------------------------------------------------------------------------------------

SELECT 'cleaned_total_rows' AS #metric, COUNT(*) AS #result FROM PracticeDB.dbo.ecommerce_orders_clean
UNION ALL
SELECT 'rows_with_invalid_email', COUNT(*) FROM PracticeDB.dbo.ecommerce_orders_clean WHERE email_status = 'Invalid'
UNION ALL
SELECT 'rows_with_invalid_phone', COUNT(*) FROM PracticeDB.dbo.ecommerce_orders_clean WHERE phone_status = 'Invalid'
UNION ALL
SELECT 'rows_with_no_contact', COUNT(*) FROM PracticeDB.dbo.ecommerce_orders_clean WHERE contact_primary = 'No valid contact'
UNION ALL
SELECT 'rows_with_zero_quantity', COUNT(*) FROM PracticeDB.dbo.ecommerce_orders_clean WHERE quantity = 0
UNION ALL
SELECT 'rows_with_negative_quantity', COUNT(*) FROM PracticeDB.dbo.ecommerce_orders_clean WHERE quantity < 0;
GO


----------------------------------------------------------------------------------------------------------------------
-- STEP 14: LOAD FINAL TABLE FOR ANALYSIS
----------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS PracticeDB.dbo.ecommerce_orders_final

SELECT
    order_id,
    order_date,
    order_status,
    customer_id,
    customer_name,
    contact_primary,
    payment_method,
    shipping_city,
    shipping_state_valid as shipping_state,
    product_valid AS product,
    category,
    quantity,
    unit_price,
    discount,
    revenue
INTO PracticeDB.dbo.ecommerce_orders_final
FROM
    PracticeDB.dbo.ecommerce_orders_clean

SELECT * FROM PracticeDB.dbo.ecommerce_orders_final



--| 11 | Detect outliers           | Statistical validation                     | `AVG`, `STDEV`, `PERCENTILE_CONT` |
-- IQR-based outlier count (no hardcoded thresholds) for the float and integer columns
-- Check for outlier for 'unit_price and "discount" one after the other
WITH 
    o_stats AS 
    (SELECT 
        PERCENTILE_CONT(0.25)WITHIN GROUP(ORDER BY discount) OVER () AS q1, -- replace discount with unit_price and repeat
        PERCENTILE_CONT(0.75)WITHIN GROUP(ORDER BY discount) OVER () AS q3  
    FROM orders_raw
    WHERE discount IS NOT NULL), 

    bounds AS 
    (SELECT DISTINCT 
        q1-1.5 *(q3-q1) AS lower_fence, 
        q3+1.5 *(q3-q1) AS upper_fence
    FROM o_stats)
SELECT 
    b.lower_fence, b.upper_fence, COUNT(*) AS outlier_count, 
    ROUND(COUNT(*)* 100.0 /(SELECT COUNT(*)FROM orders_raw), 2) AS outlier_pct
FROM orders_raw r
        CROSS JOIN bounds b
        WHERE r.discount<b.lower_fence OR r.discount>b.upper_fence  -- replace discount with unit_price and repeat
        GROUP BY b.lower_fence, b.upper_fence

-- NO outliers for unit_price OR discount were discovered


