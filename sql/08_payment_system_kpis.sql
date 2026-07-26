\set ON_ERROR_STOP on

-- ============================================================
-- PAYMENT SYSTEM KPIS
-- Provider-level traffic, conversion, fees and tiered pricing.
-- ============================================================

-- 1. Overall performance by payment system.
SELECT
    ps.payment_system_id,
    ps.payment_system_name,
    ps.provider_type,
    ROUND(100.0 * ps.base_market_fee_rate, 3) AS base_market_fee_rate_pct,
    COUNT(p.payment_id) AS all_attempts,
    COUNT(p.payment_id) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ) AS successful_payments,
    COUNT(DISTINCT p.account_id) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ) AS transacting_accounts,
    ROUND(
        100.0 * COUNT(p.payment_id) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        ) / NULLIF(COUNT(p.payment_id), 0),
        2
    ) AS success_rate_pct,
    ROUND(SUM(p.amount) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ), 2) AS gross_payment_volume,
    ROUND(AVG(p.amount) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ), 2) AS average_payment_amount,
    ROUND(SUM(p.client_fee_amount) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ), 2) AS total_client_fees,
    ROUND(SUM(p.payment_system_fee_amount) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ), 2) AS total_provider_cost,
    ROUND(SUM(p.platform_fee_amount) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ), 2) AS platform_transaction_revenue,
    ROUND(
        100.0 * SUM(p.client_fee_amount) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        )
        / NULLIF(SUM(p.amount) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        ), 0),
        3
    ) AS weighted_client_fee_rate_pct,
    ROUND(
        100.0 * SUM(p.payment_system_fee_amount) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        )
        / NULLIF(SUM(p.amount) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        ), 0),
        3
    ) AS weighted_provider_cost_rate_pct,
    ROUND(
        100.0 * SUM(p.platform_fee_amount) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        )
        / NULLIF(SUM(p.amount) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        ), 0),
        3
    ) AS weighted_platform_margin_rate_pct
FROM payment_systems ps
LEFT JOIN payments p
    ON ps.payment_system_id = p.payment_system_id
GROUP BY
    ps.payment_system_id,
    ps.payment_system_name,
    ps.provider_type,
    ps.base_market_fee_rate
ORDER BY gross_payment_volume DESC NULLS LAST;

-- 2. Monthly tier and wholesale cost history.
SELECT
    mp.pricing_month,
    ps.payment_system_name,
    ROUND(mp.monthly_volume, 2) AS monthly_volume,
    vt.tier_name,
    ROUND(vt.min_monthly_volume, 2) AS tier_min_volume,
    ROUND(vt.max_monthly_volume, 2) AS tier_max_volume,
    ROUND(100.0 * ps.base_market_fee_rate, 3) AS market_fee_rate_pct,
    ROUND(100.0 * mp.provider_cost_rate, 3) AS provider_cost_rate_pct,
    ROUND(
        100.0 * (
            ps.base_market_fee_rate - mp.provider_cost_rate
        ),
        3
    ) AS wholesale_discount_vs_market_pct_points
FROM payment_system_monthly_pricing mp
JOIN payment_systems ps
    ON mp.payment_system_id = ps.payment_system_id
JOIN payment_system_volume_tiers vt
    ON mp.volume_tier_id = vt.volume_tier_id
ORDER BY mp.pricing_month, ps.payment_system_name;

-- 3. Provider share of total successful payment volume.
WITH provider_volume AS (
    SELECT
        payment_system_id,
        SUM(amount) AS gross_payment_volume
    FROM payments
    WHERE status = 'succeeded'
      AND is_deleted = FALSE
    GROUP BY payment_system_id
)
SELECT
    ps.payment_system_name,
    ROUND(pv.gross_payment_volume, 2) AS gross_payment_volume,
    ROUND(
        100.0 * pv.gross_payment_volume
        / NULLIF(SUM(pv.gross_payment_volume) OVER (), 0),
        2
    ) AS payment_volume_share_pct
FROM provider_volume pv
JOIN payment_systems ps
    ON pv.payment_system_id = ps.payment_system_id
ORDER BY gross_payment_volume DESC;
