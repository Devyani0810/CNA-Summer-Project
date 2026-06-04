CREATE DATABASE fashion_brand;

USE fashion_brand;

SELECT 
    `Promo Dependency Score`,
    COUNT(*) AS Total_Customers,
    ROUND(AVG(`Purchase Amount (USD)`), 2) AS Avg_Spend,
    ROUND(AVG(`Previous Purchases`), 2) AS Avg_Previous_Purchases,
    ROUND(AVG(`Loyalty Score`), 2) AS Avg_Loyalty_Score
FROM cleaned_data
GROUP BY `Promo Dependency Score`
ORDER BY `Promo Dependency Score`;

USE fashion_brand;

SELECT
    `Customer Value Tier`,
    COUNT(*) AS Total_Customers,
    ROUND(AVG(`Purchase Amount (USD)`), 2) AS Avg_Spend,
    ROUND(AVG(`Previous Purchases`), 2) AS Avg_Previous_Purchases,
    ROUND(AVG(`Loyalty Score`), 2) AS Avg_Loyalty_Score,
    ROUND(AVG(`Promo Dependency Score`), 2) AS Avg_Promo_Dependency
FROM cleaned_data
GROUP BY `Customer Value Tier`
ORDER BY Avg_Loyalty_Score DESC;


USE fashion_brand;

SELECT
    Location,
    COUNT(*) AS Total_Customers,
    ROUND(AVG(`Purchase Amount (USD)`), 2) AS Avg_Spend,
    ROUND(AVG(`Promo Dependency Score`), 2) AS Avg_Promo_Dependency,
    ROUND(AVG(`Loyalty Score`), 2) AS Avg_Loyalty_Score,
    ROUND(AVG(`Previous Purchases`), 2) AS Avg_Previous_Purchases
FROM cleaned_data
GROUP BY Location
ORDER BY Avg_Spend DESC, Avg_Promo_Dependency ASC
LIMIT 10;

USE fashion_brand;

SELECT
    `Customer Value Tier`,
    `Satisfaction Flag`,
    COUNT(*) AS Total_Customers,
    ROUND(AVG(`Purchase Amount (USD)`), 2) AS Avg_Spend,
    ROUND(AVG(`Loyalty Score`), 2) AS Avg_Loyalty_Score,
    ROUND(AVG(`Promo Dependency Score`), 2) AS Avg_Promo_Dependency,
    SUM(CASE WHEN `Promo Dependency Score` = 0 THEN 1 ELSE 0 END) AS No_Promo_Customers,
    SUM(CASE WHEN `Promo Dependency Score` = 2 THEN 1 ELSE 0 END) AS Promo_Customers
FROM cleaned_data
GROUP BY `Customer Value Tier`, `Satisfaction Flag`
ORDER BY `Customer Value Tier`, Avg_Loyalty_Score DESC;

USE fashion_brand;

SELECT
    Gender,
    ROUND(AVG(Age), 0) AS Avg_Age,
    ROUND(AVG(`Purchase Amount (USD)`), 2) AS Avg_Spend,
    ROUND(AVG(`Loyalty Score`), 2) AS Avg_Loyalty_Score,
    ROUND(AVG(`Previous Purchases`), 2) AS Avg_Previous_Purchases,
    `Payment Method`,
    `Subscription Status`,
    COUNT(*) AS Total_Customers
FROM cleaned_data
WHERE `Customer Value Tier` = 'High Value'
AND `Satisfaction Flag` = 'Happy'
AND `Promo Dependency Score` = 0
GROUP BY Gender, `Payment Method`, `Subscription Status`
ORDER BY Total_Customers DESC
LIMIT 10;