\set ON_ERROR_STOP on

-- ============================================================
-- TARIFF KPIS
-- Transaction economics by tariff and tariff/provider combination.
-- ============================================================

-- 1. Overall economics by tariff.
SELECT
    t.tariff_id,
    t.tariff_name,
    t.monthly_price,
    COUNT(p.payment_id) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ) AS successful_payments,
    COUNT(DISTINCT p.account_id) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ) AS transacting_accounts,
    COUNT(DISTINCT p.payment_system_id) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ) AS payment_systems_used,
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
    ROUND(SUM(p.amount * p.risk_surcharge_rate) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ), 2) AS risk_surcharge_revenue,
    ROUND(
        100.0 * SUM(
            p.amount * (p.client_fee_rate - p.risk_surcharge_rate)
        ) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        )
        / NULLIF(SUM(p.amount) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        ), 0),
        3
    ) AS weighted_base_client_fee_rate_pct,
    ROUND(
        100.0 * SUM(p.client_fee_amount) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        )
        / NULLIF(SUM(p.amount) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        ), 0),
        3
    ) AS weighted_effective_client_fee_rate_pct,
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
FROM tariffs t
LEFT JOIN payments p
    ON t.tariff_id = p.tariff_id
GROUP BY
    t.tariff_id,
    t.tariff_name,
    t.monthly_price
ORDER BY t.tariff_id;

-- 2. Tariff and payment-system pricing matrix with actual traffic.
SELECT
    t.tariff_name,
    ps.payment_system_name,
    ROUND(100.0 * tpc.client_fee_rate, 3) AS base_client_fee_rate_pct,
    ROUND(
        100.0 * tpc.discount_from_market_rate,
        3
    ) AS discount_from_market_pct_points,
    COUNT(p.payment_id) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ) AS successful_payments,
    COUNT(DISTINCT p.account_id) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ) AS transacting_accounts,
    ROUND(SUM(p.amount) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ), 2) AS gross_payment_volume,
    ROUND(
        100.0 * SUM(p.amount * p.risk_surcharge_rate) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        )
        / NULLIF(SUM(p.amount) FILTER (
            WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
        ), 0),
        3
    ) AS weighted_risk_surcharge_rate_pct,
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
    ) AS weighted_platform_margin_rate_pct,
    ROUND(SUM(p.platform_fee_amount) FILTER (
        WHERE p.status = 'succeeded' AND p.is_deleted = FALSE
    ), 2) AS platform_transaction_revenue
FROM tariff_payment_conditions tpc
JOIN tariffs t
    ON tpc.tariff_id = t.tariff_id
JOIN payment_systems ps
    ON tpc.payment_system_id = ps.payment_system_id
LEFT JOIN payments p
    ON tpc.tariff_id = p.tariff_id
   AND tpc.payment_system_id = p.payment_system_id
GROUP BY
    t.tariff_id,
    t.tariff_name,
    ps.payment_system_id,
    ps.payment_system_name,
    tpc.client_fee_rate,
    tpc.discount_from_market_rate
ORDER BY t.tariff_id, ps.payment_system_name;

-- 3. Tariff distribution in the latest subscription period per account.
WITH latest_subscription AS (
    SELECT
        account_id,
        tariff_id,
        status,
        valid_from,
        paid_till,
        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY valid_from DESC, subscription_id DESC
        ) AS row_num
    FROM subscriptions
)
SELECT
    t.tariff_name,
    t.monthly_price,
    ls.status AS subscription_status,
    COUNT(*) AS accounts
FROM latest_subscription ls
JOIN tariffs t
    ON ls.tariff_id = t.tariff_id
WHERE ls.row_num = 1
GROUP BY
    t.tariff_id,
    t.tariff_name,
    t.monthly_price,
    ls.status
ORDER BY t.tariff_id, ls.status;
