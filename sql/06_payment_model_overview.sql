\set ON_ERROR_STOP on

-- ============================================================
-- PAYMENT MODEL OVERVIEW
-- Baseline counts, payment statuses, headline KPIs and formula checks.
-- ============================================================

-- 1. Row counts across the current model.
SELECT 'accounts' AS table_name, COUNT(*) AS row_count FROM accounts
UNION ALL
SELECT 'payment_systems', COUNT(*) FROM payment_systems
UNION ALL
SELECT 'payment_system_volume_tiers', COUNT(*) FROM payment_system_volume_tiers
UNION ALL
SELECT 'tariffs', COUNT(*) FROM tariffs
UNION ALL
SELECT 'tariff_payment_conditions', COUNT(*) FROM tariff_payment_conditions
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'account_risk_profiles', COUNT(*) FROM account_risk_profiles
UNION ALL
SELECT 'payment_system_monthly_pricing', COUNT(*) FROM payment_system_monthly_pricing
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'checkout_requests', COUNT(*) FROM checkout_requests
ORDER BY table_name;

-- 2. Payment status distribution.
SELECT
    status,
    is_deleted,
    COUNT(*) AS payment_count,
    ROUND(
        100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS share_of_all_payments_pct
FROM payments
GROUP BY status, is_deleted
ORDER BY payment_count DESC;

-- 3. Headline economics for valid successful payments.
WITH valid_payments AS (
    SELECT *
    FROM payments
    WHERE status = 'succeeded'
      AND is_deleted = FALSE
)
SELECT
    COUNT(*) AS successful_payments,
    COUNT(DISTINCT account_id) AS transacting_accounts,
    COUNT(DISTINCT payment_system_id) AS payment_systems_used,
    ROUND(SUM(amount), 2) AS gross_payment_volume,
    ROUND(AVG(amount), 2) AS average_payment_amount,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount)::NUMERIC,
        2
    ) AS median_payment_amount,
    ROUND(SUM(client_fee_amount), 2) AS total_client_fees,
    ROUND(SUM(payment_system_fee_amount), 2) AS total_provider_cost,
    ROUND(SUM(platform_fee_amount), 2) AS platform_transaction_revenue,
    ROUND(SUM(merchant_net_amount), 2) AS merchant_net_volume,
    ROUND(
        100.0 * SUM(client_fee_amount) / NULLIF(SUM(amount), 0),
        3
    ) AS weighted_client_fee_rate_pct,
    ROUND(
        100.0 * SUM(payment_system_fee_amount) / NULLIF(SUM(amount), 0),
        3
    ) AS weighted_provider_cost_rate_pct,
    ROUND(
        100.0 * SUM(platform_fee_amount) / NULLIF(SUM(amount), 0),
        3
    ) AS weighted_platform_margin_rate_pct
FROM valid_payments;

-- 4. Formula and pricing reconciliation.
SELECT
    COUNT(*) FILTER (
        WHERE ABS(
            client_fee_amount
            - payment_system_fee_amount
            - platform_fee_amount
        ) > 0.01
    ) AS invalid_fee_split_rows,
    COUNT(*) FILTER (
        WHERE status = 'succeeded'
          AND is_deleted = FALSE
          AND ABS(
              merchant_net_amount - (amount - client_fee_amount)
          ) > 0.01
    ) AS invalid_merchant_net_rows,
    COUNT(*) FILTER (
        WHERE ABS(
            platform_margin_rate
            - (client_fee_rate - provider_cost_rate)
        ) > 0.000001
    ) AS invalid_margin_rate_rows,
    COUNT(*) FILTER (
        WHERE (status <> 'succeeded' OR is_deleted = TRUE)
          AND (
              client_fee_amount <> 0
              OR payment_system_fee_amount <> 0
              OR platform_fee_amount <> 0
              OR merchant_net_amount <> 0
          )
    ) AS non_successful_rows_with_money
FROM payments;

-- 5. Risk surcharge must explain the difference between the effective
-- payment rate and the base tariff/provider rate.
SELECT
    COUNT(*) AS checked_rows,
    COUNT(*) FILTER (
        WHERE ABS(
            p.client_fee_rate
            - tpc.client_fee_rate
            - p.risk_surcharge_rate
        ) > 0.000001
    ) AS invalid_risk_surcharge_rows,
    ROUND(
        MAX(ABS(
            p.client_fee_rate
            - tpc.client_fee_rate
            - p.risk_surcharge_rate
        )),
        6
    ) AS maximum_rate_difference
FROM payments p
JOIN tariff_payment_conditions tpc
    ON p.tariff_id = tpc.tariff_id
   AND p.payment_system_id = tpc.payment_system_id;
