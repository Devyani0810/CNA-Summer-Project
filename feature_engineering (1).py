"""
============================================================
STEP 1: DATA PREPARATION & FEATURE ENGINEERING
StyleCo D2C Fashion Brand — Customer Intelligence Project
Consulting & Analytics Club, IIT Guwahati — Summer '26
============================================================
"""

import pandas as pd
import numpy as np

# ──────────────────────────────────────────────────────────
# 1. LOAD RAW DATA
# ──────────────────────────────────────────────────────────
df = pd.read_csv('Dataset__3_.csv')
print(f"Raw data loaded: {df.shape[0]} rows × {df.shape[1]} columns")

# ──────────────────────────────────────────────────────────
# 2. DATA CLEANING
# ──────────────────────────────────────────────────────────

# 2a. Handle missing values
# Review Rating has 37 missing (0.95% of data) — fill with median
print(f"\nMissing values:\n{df.isnull().sum()[df.isnull().sum()>0]}")
df['Review Rating'] = df['Review Rating'].fillna(df['Review Rating'].median())
print(f"After imputation: {df['Review Rating'].isnull().sum()} missing Review Ratings")

# 2b. Convert binary categoricals to integer flags
# Rationale: enables arithmetic operations in metric construction
df['Discount_Flag']   = (df['Discount Applied']    == 'Yes').astype(int)
df['Promo_Flag']      = (df['Promo Code Used']      == 'Yes').astype(int)
df['Subscriber_Flag'] = (df['Subscription Status'] == 'Yes').astype(int)

# 2c. Map purchase frequency to annual purchase count
# Rationale: converts a categorical label to a numeric scale
# allowing revenue estimation; used in EAR calculation below
freq_map = {
    'Weekly':        52,
    'Bi-Weekly':     26,
    'Fortnightly':   26,   # synonym for Bi-Weekly
    'Monthly':       12,
    'Every 3 Months': 4,
    'Quarterly':      4,   # synonym for Every 3 Months
    'Annually':       1,
}
df['Purchase_Freq_Annual'] = df['Frequency of Purchases'].map(freq_map)
assert df['Purchase_Freq_Annual'].isnull().sum() == 0, "Unmapped frequency values!"

# ──────────────────────────────────────────────────────────
# 3. FEATURE ENGINEERING
# Each metric below answers a specific business question.
# ──────────────────────────────────────────────────────────

# ── METRIC 1: Estimated Annual Revenue (EAR) ──────────────
# Question it answers: What does this customer generate per year?
# Logic: The dataset records a single transaction amount and a
#        self-reported purchase frequency. EAR = spend × annual
#        frequency gives a first-order proxy for CLV before
#        margin adjustment. It is the primary value ranking metric.
# Risk: Does not account for returns, discounts already embedded
#       in the purchase price, or multi-category baskets. Treat
#       as directional, not precise.
df['Est_Annual_Revenue'] = df['Purchase Amount (USD)'] * df['Purchase_Freq_Annual']
print(f"\nEst. Annual Revenue — mean ${df['Est_Annual_Revenue'].mean():.0f}, "
      f"median ${df['Est_Annual_Revenue'].median():.0f}, "
      f"max ${df['Est_Annual_Revenue'].max():.0f}")


# ── METRIC 2: Promo Dependency Score (PDS) ────────────────
# Question it answers: How much does this customer rely on
#                      discounts to trigger a purchase?
# Logic: Two independent levers exist — a blanket Discount Applied
#        flag (applied at brand level) and a Promo Code Used flag
#        (customer-initiated). A customer who triggers both is the
#        most expensive to acquire and retain. Scores: 0 = organic,
#        1 = partially promo-dependent, 2 = fully promo-driven.
# Decision relevance: The promotional sunset plan targets PDS=2
#   customers in the "Loyal" segment — they are high-value but
#   margin-eroding.
df['Promo_Dependency_Score'] = df['Discount_Flag'] + df['Promo_Flag']
print(f"\nPromo Dependency distribution:\n{df['Promo_Dependency_Score'].value_counts()}")


# ── METRIC 3: Satisfaction Score (normalized) ─────────────
# Question it answers: Is this customer likely to churn or expand?
# Logic: Review Rating is on a 2.5–5.0 scale (no scores below 2.5
#        in data). Normalize to 0–1 for arithmetic use in composite
#        indices. Higher score = more likely to return and recommend.
# Limitation: Self-reported; subject to positivity bias.
df['Satisfaction_Score'] = (df['Review Rating'] - 2.5) / 2.5


# ── METRIC 4: Loyalty Index A — Behavioral Depth ─────────
# Question it answers: How entrenched is this customer's buying
#                      habit, independent of spend level?
# Logic: Uses Previous Purchases (length of relationship proxy)
#        + purchase frequency (engagement intensity) + subscription
#        status (brand commitment signal). Weighted toward history
#        (50%) because a long purchase history is harder to fake
#        than a single high-spend transaction.
# Competing definition chosen for primary analysis because:
#   → More grounded in repeat behavior (the core loyalty question)
#   → Previous Purchases is the most direct historical signal available
purch_norm = (df['Previous Purchases'] - df['Previous Purchases'].min()) / \
             (df['Previous Purchases'].max() - df['Previous Purchases'].min())
freq_norm  = (df['Purchase_Freq_Annual'] - df['Purchase_Freq_Annual'].min()) / \
             (df['Purchase_Freq_Annual'].max() - df['Purchase_Freq_Annual'].min())
df['Loyalty_Index_A'] = (0.50 * purch_norm +
                          0.35 * freq_norm +
                          0.15 * df['Subscriber_Flag'])


# ── METRIC 5: Loyalty Index B — Value Without Discount ────
# Question it answers: Is this customer's value genuine or
#                      entirely discount-manufactured?
# Logic: Revenue-weighted (40%), satisfaction-weighted (35%),
#        discount-adjusted (25%). The no-promo weight penalizes
#        customers who only buy on discount. A customer with high
#        EAR but PDS=2 scores lower here than in Loyalty A,
#        correctly flagging them as margin risk.
# Why Index A is preferred: Correlation with Index B = 0.075
#   (near-zero) — they capture genuinely different constructs.
#   Index A measures behavioral depth; Index B measures revenue
#   quality. For segmentation purposes, behavioral depth (A) is
#   more actionable because it predicts future purchase frequency.
ear_norm = (df['Est_Annual_Revenue'] - df['Est_Annual_Revenue'].min()) / \
           (df['Est_Annual_Revenue'].max() - df['Est_Annual_Revenue'].min())
no_promo_weight = 1 - (df['Promo_Dependency_Score'] / 2)
df['Loyalty_Index_B'] = (0.40 * ear_norm +
                          0.35 * df['Satisfaction_Score'] +
                          0.25 * no_promo_weight)

print(f"\nCorrelation between Loyalty Index A and B: "
      f"{df['Loyalty_Index_A'].corr(df['Loyalty_Index_B']):.3f}")
print("→ Near-zero: A measures behavioral depth; B measures revenue quality.")
print("  A is chosen as primary segmentation axis.")


# ── METRIC 6: Customer Value Tier ────────────────────────
# Question it answers: Which quartile of annual revenue does
#                      this customer fall in?
# Logic: Simple quartile bucketing of EAR. Deliberately uses
#        the data distribution (qcut), not arbitrary dollar
#        thresholds, so tiers are comparable in size.
df['Value_Tier'] = pd.qcut(
    df['Est_Annual_Revenue'], q=4,
    labels=['Low', 'Medium', 'High', 'Premium']
)


# ── METRIC 7: Retention Risk Flag ─────────────────────────
# Question it answers: Which customers are most likely to
#                      lapse within the next purchase cycle?
# Logic: Three simultaneous conditions define risk:
#   (a) At least one promo lever used → likely discount-triggered
#   (b) Below-median satisfaction → not organically delighted
#   (c) Very low purchase frequency (≤4/year) → shallow habit
# All three together identify the "discount tourist" who is
# not satisfied enough to return without a trigger.
df['Retention_Risk'] = (
    (df['Promo_Dependency_Score'] >= 1) &
    (df['Satisfaction_Score'] < 0.5) &
    (df['Purchase_Freq_Annual'] <= 4)
).astype(int)
print(f"\nAt-risk customers: {df['Retention_Risk'].sum()} "
      f"({df['Retention_Risk'].mean()*100:.1f}% of base)")


# ── METRIC 8: Organic Buyer Flag ─────────────────────────
# Question it answers: Is this customer's purchase driven by
#                      genuine brand preference?
# Logic: Both discount levers = 0. This is the clearest signal
#        of brand pull available in the dataset. Organic buyers
#        in high-revenue tiers are the brand's most valuable
#        and defensible customers.
df['Organic_Buyer'] = (
    (df['Discount_Flag'] == 0) & (df['Promo_Flag'] == 0)
).astype(int)
print(f"Organic buyers: {df['Organic_Buyer'].sum()} "
      f"({df['Organic_Buyer'].mean()*100:.1f}% of base)")


# ──────────────────────────────────────────────────────────
# 4. CUSTOMER SEGMENTATION (4 archetypes)
# ──────────────────────────────────────────────────────────
# Segment axis 1: Loyalty (above/below median Loyalty Index A)
# Segment axis 2: Promo usage (Organic vs Promo-Driven)
# Result: 4 actionable quadrants each requiring a different strategy

median_loyalty = df['Loyalty_Index_A'].median()
conditions = [
    (df['Loyalty_Index_A'] >= median_loyalty) & (df['Organic_Buyer'] == 1),
    (df['Loyalty_Index_A'] >= median_loyalty) & (df['Organic_Buyer'] == 0),
    (df['Loyalty_Index_A'] <  median_loyalty) & (df['Organic_Buyer'] == 1),
    (df['Loyalty_Index_A'] <  median_loyalty) & (df['Organic_Buyer'] == 0),
]
labels = ['Loyal Organic', 'Loyal Promo-Driven', 'Casual Organic', 'Casual Promo-Driven']
df['Segment'] = np.select(conditions, labels)

print("\n=== SEGMENT SUMMARY ===")
print(df.groupby('Segment').agg(
    n=('Customer ID', 'count'),
    avg_annual_rev=('Est_Annual_Revenue', 'mean'),
    avg_prev_purchases=('Previous Purchases', 'mean'),
    avg_freq=('Purchase_Freq_Annual', 'mean'),
    avg_rating=('Review Rating', 'mean'),
    pct_subscribed=('Subscriber_Flag', 'mean'),
).round(2))

# ──────────────────────────────────────────────────────────
# 5. KEY EDA FINDINGS
# ──────────────────────────────────────────────────────────
print("\n=== Q1: Loyal vs Promo-Only Customers ===")
print(df[df['Segment'].isin(['Loyal Organic','Casual Promo-Driven'])].groupby('Segment').agg(
    avg_annual_rev=('Est_Annual_Revenue','mean'),
    avg_prev_purchases=('Previous Purchases','mean'),
)).round(1))

print("\n=== Q2: Seasonal Tenure Patterns ===")
print(df.groupby('Season').agg(avg_prev=('Previous Purchases','mean'), pct_promo=('Promo_Flag','mean')).round(2))

print("\n=== Q3: Geographic Organic Revenue ===")
geo = df.groupby('Location').agg(n=('Customer ID','count'), pct_org=('Organic_Buyer','mean'), avg_rev=('Est_Annual_Revenue','mean'))
geo['organic_idx'] = geo['pct_org'] * geo['avg_rev']
print(geo[geo['n']>=50].sort_values('organic_idx',ascending=False).head(8).round(0))

# ──────────────────────────────────────────────────────────
# 6. SAVE ENRICHED DATASET
# ──────────────────────────────────────────────────────────
output_cols = [
    'Customer ID','Age','Gender','Item Purchased','Category',
    'Purchase Amount (USD)','Location','Size','Color','Season',
    'Review Rating','Subscription Status','Shipping Type',
    'Discount Applied','Promo Code Used','Previous Purchases',
    'Payment Method','Frequency of Purchases',
    # Engineered
    'Discount_Flag','Promo_Flag','Subscriber_Flag',
    'Purchase_Freq_Annual','Est_Annual_Revenue',
    'Promo_Dependency_Score','Satisfaction_Score',
    'Loyalty_Index_A','Loyalty_Index_B',
    'Value_Tier','Retention_Risk','Organic_Buyer','Segment'
]
df[output_cols].to_csv('styleco_enriched_customers.csv', index=False)
print("\nEnriched dataset saved: styleco_enriched_customers.csv")
print(f"Final shape: {df.shape[0]} rows × {len(output_cols)} columns")
