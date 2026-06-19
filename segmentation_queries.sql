

-- ──────────────────────────────────────────────────────────
-- Q1A: HIGH-VALUE vs LOW-VALUE — What separates them?
-- Separates customers by Value Tier and reveals the attribute
-- profile of each tier across spend, frequency, history, and
-- promo dependency.
-- ──────────────────────────────────────────────────────────
SELECT 
    Value_Tier,
    COUNT(*)                                          AS customer_count,
    ROUND(AVG("Purchase Amount (USD)"), 2)            AS avg_transaction_spend,
    ROUND(AVG(Purchase_Freq_Annual), 1)               AS avg_annual_frequency,
    ROUND(AVG(Est_Annual_Revenue), 0)                 AS avg_annual_revenue,
    ROUND(AVG("Previous Purchases"), 1)               AS avg_purchase_history,
    ROUND(AVG("Review Rating"), 2)                    AS avg_satisfaction,
    ROUND(AVG(Subscriber_Flag) * 100, 1)              AS pct_subscribed,
    ROUND(AVG(Organic_Buyer) * 100, 1)                AS pct_organic_buyers,
    ROUND(AVG(Promo_Dependency_Score), 2)             AS avg_promo_dependency
FROM customers
GROUP BY Value_Tier
ORDER BY avg_annual_revenue DESC;


-- ──────────────────────────────────────────────────────────
-- Q1B: REPEAT PURCHASE BEHAVIOR — Which profiles lead?
-- Compares the 4 behavioral segments on depth of repeat
-- purchase history — the best available loyalty proxy.
-- ──────────────────────────────────────────────────────────
SELECT 
    Segment,
    COUNT(*)                                          AS customer_count,
    ROUND(AVG("Previous Purchases"), 1)               AS avg_repeat_purchases,
    ROUND(AVG(Purchase_Freq_Annual), 1)               AS avg_annual_frequency,
    ROUND(AVG(Est_Annual_Revenue), 0)                 AS avg_annual_revenue,
    ROUND(AVG("Purchase Amount (USD)"), 2)            AS avg_transaction_value,
    ROUND(AVG("Review Rating"), 2)                    AS avg_satisfaction,
    ROUND(AVG(Subscriber_Flag) * 100, 1)              AS pct_subscribed
FROM customers
GROUP BY Segment
ORDER BY avg_repeat_purchases DESC;


-- ──────────────────────────────────────────────────────────
-- Q1C: IDEAL CUSTOMER PROFILE — Age & payment patterns
-- Identifies the demographic and behavioral fingerprint of
-- the top-tier organic, loyal customer.
-- ──────────────────────────────────────────────────────────
SELECT 
    "Payment Method",
    "Gender",
    CASE 
        WHEN Age < 30 THEN '18-29'
        WHEN Age < 45 THEN '30-44'
        WHEN Age < 60 THEN '45-59'
        ELSE '60+'
    END                                               AS age_band,
    COUNT(*)                                          AS customer_count,
    ROUND(AVG(Est_Annual_Revenue), 0)                 AS avg_annual_revenue,
    ROUND(AVG("Previous Purchases"), 1)               AS avg_purchase_history,
    ROUND(AVG(Organic_Buyer) * 100, 1)                AS pct_organic
FROM customers
WHERE Segment = 'Loyal Organic'
GROUP BY "Payment Method", "Gender", age_band
HAVING customer_count >= 10
ORDER BY avg_annual_revenue DESC
LIMIT 15;


-- ──────────────────────────────────────────────────────────
-- Q2: SEASON & CATEGORY vs CUSTOMER TENURE
-- Reveals which season–category combinations attract customers
-- with deeper purchase history (loyal) vs. shallow history
-- (newer or occasional buyers).
-- ──────────────────────────────────────────────────────────
SELECT 
    Season,
    Category,
    COUNT(*)                                          AS customer_count,
    ROUND(AVG("Previous Purchases"), 1)               AS avg_tenure_proxy,
    ROUND(AVG("Purchase Amount (USD)"), 2)            AS avg_spend,
    ROUND(AVG(Promo_Flag) * 100, 1)                   AS pct_promo_used,
    ROUND(AVG(Est_Annual_Revenue), 0)                 AS avg_annual_rev
FROM customers
GROUP BY Season, Category
ORDER BY avg_tenure_proxy DESC;


-- ──────────────────────────────────────────────────────────
-- Q2B: LOW-TENURE ENTRY POINTS — Outerwear in Fall/Spring
-- Zooms in on combinations where new/shallow customers buy
-- most often — these are acquisition entry points.
-- ──────────────────────────────────────────────────────────
SELECT 
    Season,
    Category,
    COUNT(*)                                          AS customer_count,
    ROUND(AVG("Previous Purchases"), 1)               AS avg_purchase_history,
    ROUND(AVG(Promo_Dependency_Score), 2)             AS avg_promo_dep,
    ROUND(AVG(Retention_Risk) * 100, 1)               AS pct_at_risk
FROM customers
WHERE "Previous Purchases" < 15          -- shallow history = newer/casual customers
GROUP BY Season, Category
HAVING customer_count >= 30
ORDER BY pct_at_risk DESC;


-- ──────────────────────────────────────────────────────────
-- Q3: GEOGRAPHY — Organic demand vs. discount-driven volume
-- The Organic Revenue Index = pct_organic × avg_annual_rev.
-- High index = genuine brand pull; NOT discount-manufactured.
-- ──────────────────────────────────────────────────────────
SELECT 
    Location,
    COUNT(*)                                          AS total_customers,
    ROUND(AVG("Purchase Amount (USD)"), 2)            AS avg_spend,
    ROUND(AVG(Organic_Buyer) * 100, 1)                AS pct_organic_buyers,
    ROUND(AVG(Promo_Dependency_Score), 2)             AS avg_promo_dependency,
    ROUND(AVG(Est_Annual_Revenue), 0)                 AS avg_annual_rev,
    ROUND(AVG(Organic_Buyer) * AVG(Est_Annual_Revenue), 0)  AS organic_rev_index,
    ROUND(AVG(Retention_Risk) * 100, 1)               AS pct_at_risk
FROM customers
GROUP BY Location
HAVING total_customers >= 50
ORDER BY organic_rev_index DESC
LIMIT 20;


-- ──────────────────────────────────────────────────────────
-- Q3B: GEOGRAPHY — Promo-heavy states (margin risk zones)
-- States where avg promo dependency is high AND volume is
-- significant are discount-dependent markets. De-prioritize
-- or restructure promotional approach here.
-- ──────────────────────────────────────────────────────────
SELECT 
    Location,
    COUNT(*)                                          AS total_customers,
    ROUND(AVG(Promo_Dependency_Score), 2)             AS avg_promo_dep,
    ROUND(AVG(Organic_Buyer) * 100, 1)                AS pct_organic,
    ROUND(AVG(Est_Annual_Revenue), 0)                 AS avg_annual_rev
FROM customers
GROUP BY Location
HAVING total_customers >= 50
  AND avg_promo_dep > 1.0                -- more than half of customers use BOTH levers
ORDER BY avg_promo_dep DESC
LIMIT 10;


-- ──────────────────────────────────────────────────────────
-- Q4: PROMO SUNSET CANDIDATES
-- Loyal Promo-Driven customers with high revenue but
-- full promo dependency. These are the primary targets
-- for gradual discount removal — they have the relationship
-- depth to survive it.
-- ──────────────────────────────────────────────────────────
SELECT 
    "Customer ID",
    Age,
    "Gender",
    Location,
    "Purchase Amount (USD)"                           AS last_spend,
    "Previous Purchases"                              AS purchase_history,
    Purchase_Freq_Annual                              AS annual_freq,
    Est_Annual_Revenue                                AS annual_rev,
    "Review Rating"                                   AS satisfaction,
    Promo_Dependency_Score
FROM customers
WHERE Segment = 'Loyal Promo-Driven'
  AND Est_Annual_Revenue >= 1000           -- high-value threshold
  AND "Previous Purchases" >= 30           -- deep relationship
ORDER BY Est_Annual_Revenue DESC
LIMIT 20;


-- ──────────────────────────────────────────────────────────
-- Q5: CATEGORY FUNNEL — Entry vs Retention categories
-- Uses Previous Purchases as a tenure proxy.
-- High avg = bought more by established customers (retention).
-- Low avg = bought more by new/casual customers (entry).
-- ──────────────────────────────────────────────────────────
SELECT 
    Category,
    COUNT(*)                                          AS customer_count,
    ROUND(AVG("Previous Purchases"), 1)               AS avg_prior_purchases,
    ROUND(AVG("Purchase Amount (USD)"), 2)            AS avg_spend,
    ROUND(AVG(Promo_Flag) * 100, 1)                   AS pct_promo_used,
    ROUND(AVG(Est_Annual_Revenue), 0)                 AS avg_annual_rev,
    ROUND(AVG(Organic_Buyer) * 100, 1)                AS pct_organic,
    CASE 
        WHEN AVG("Previous Purchases") >= 25.5 THEN 'Retention Category'
        ELSE 'Entry-Point Category'
    END                                               AS category_role
FROM customers
GROUP BY Category
ORDER BY avg_prior_purchases DESC;
