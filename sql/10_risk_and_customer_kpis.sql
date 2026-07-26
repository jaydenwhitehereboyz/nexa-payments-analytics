\set ON_ERROR_STOP on

-- ============================================================
-- RISK AND CUSTOMER KPIS
-- Risk-level economics and account-level payment summaries.
-- ============================================================

-- 1. Payment economics by risk level.
WITH risk_accounts AS (
    SELECT
        risk_level,
        COUNT(*) AS accounts_in_profile,
        ROUND(AVG(risk_score), 4) AS average_risk_score,
        ROUND(100.0 * AVG(chargeback_rate), 3) AS average_chargeback_rate_pct,
        ROUND(100.0 * AVG(refund_rate), 3) AS average_refund_rate_pct,
        ROUND(100.0 * AVG(risk_surcharge_rate), 3) AS configured_risk_surcharge_pct
    FROM account_risk_profiles
    GROUP BY risk_level
),
risk_payments AS (
    SELECT
        arp.risk_level,
        COUNT(DISTINCT p.account_id) AS transacting_accounts,
        COUNT(*) AS successful_payments,
        SUM(p.amount) AS gross_payment_volume,
        AVG(p.amount) AS average_payment_amount,
        SUM(p.client_fee_amount) AS total_client_fees,
        SUM(p.payment_system_fee_amount) AS total_provider_cost,
        SUM(p.platform_fee_amount) AS platform_transaction_revenue,
        SUM(p.amount * p.risk_surcharge_rate) AS risk_surcharge_revenue,
        SUM(
            p.platform_fee_amount
            - p.amount * p.risk_surcharge_rate
        ) AS base_margin_revenue
    FROM payments p
    JOIN account_risk_profiles arp
        ON p.account_id = arp.account_id
    WHERE p.status = 'succeeded'
      AND p.is_deleted = FALSE
    GROUP BY arp.risk_level
)
SELECT
    ra.risk_level,
    ra.accounts_in_profile,
    rp.transacting_accounts,
    rp.successful_payments,
    ra.average_risk_score,
    ra.average_chargeback_rate_pct,
    ra.average_refund_rate_pct,
    ra.configured_risk_surcharge_pct,
    ROUND(rp.gross_payment_volume, 2) AS gross_payment_volume,
    ROUND(rp.average_payment_amount, 2) AS average_payment_amount,
    ROUND(rp.total_client_fees, 2) AS total_client_fees,
    ROUND(rp.total_provider_cost, 2) AS total_provider_cost,
    ROUND(rp.platform_transaction_revenue, 2) AS platform_transaction_revenue,
    ROUND(rp.risk_surcharge_revenue, 2) AS risk_surcharge_revenue,
    ROUND(rp.base_margin_revenue, 2) AS base_margin_revenue,
    ROUND(
        100.0 * rp.total_client_fees
        / NULLIF(rp.gross_payment_volume, 0),
        3
    ) AS weighted_effective_client_fee_rate_pct,
    ROUND(
        100.0 * rp.total_provider_cost
        / NULLIF(rp.gross_payment_volume, 0),
        3
    ) AS weighted_provider_cost_rate_pct,
    ROUND(
        100.0 * rp.platform_transaction_revenue
        / NULLIF(rp.gross_payment_volume, 0),
        3
    ) AS weighted_platform_margin_rate_pct
FROM risk_accounts ra
LEFT JOIN risk_payments rp
    ON ra.risk_level = rp.risk_level
ORDER BY CASE ra.risk_level
    WHEN 'low' THEN 1
    WHEN 'medium' THEN 2
    WHEN 'high' THEN 3
END;

-- 2. Customer-level payment summary.
WITH account_payments AS (
    SELECT
        p.account_id,
        COUNT(*) AS successful_payments,
        COUNT(DISTINCT p.payment_system_id) AS payment_systems_used,
        COUNT(DISTINCT p.tariff_id) AS tariffs_used,
        MIN(p.created_at) AS first_payment_at,
        MAX(p.created_at) AS last_payment_at,
        SUM(p.amount) AS gross_payment_volume,
        AVG(p.amount) AS average_payment_amount,
        SUM(p.client_fee_amount) AS total_client_fees,
        SUM(p.payment_system_fee_amount) AS total_provider_cost,
        SUM(p.platform_fee_amount) AS platform_transaction_revenue,
        SUM(p.merchant_net_amount) AS merchant_net_volume,
        SUM(p.amount * p.risk_surcharge_rate) AS risk_surcharge_revenue
    FROM payments p
    WHERE p.status = 'succeeded'
      AND p.is_deleted = FALSE
    GROUP BY p.account_id
)
SELECT
    a.account_id,
    a.email,
    a.region,
    a.business_segment,
    a.company_size,
    a.account_status,
    arp.risk_level,
    arp.risk_score,
    ROUND(100.0 * arp.chargeback_rate, 3) AS chargeback_rate_pct,
    ROUND(100.0 * arp.refund_rate, 3) AS refund_rate_pct,
    ap.successful_payments,
    ap.payment_systems_used,
    ap.tariffs_used,
    ap.first_payment_at,
    ap.last_payment_at,
    ROUND(ap.gross_payment_volume, 2) AS gross_payment_volume,
    ROUND(ap.average_payment_amount, 2) AS average_payment_amount,
    ROUND(ap.total_client_fees, 2) AS total_client_fees,
    ROUND(ap.total_provider_cost, 2) AS total_provider_cost,
    ROUND(ap.platform_transaction_revenue, 2) AS platform_transaction_revenue,
    ROUND(ap.risk_surcharge_revenue, 2) AS risk_surcharge_revenue,
    ROUND(ap.merchant_net_volume, 2) AS merchant_net_volume,
    ROUND(
        100.0 * ap.platform_transaction_revenue
        / NULLIF(ap.gross_payment_volume, 0),
        3
    ) AS weighted_platform_margin_rate_pct
FROM account_payments ap
JOIN accounts a
    ON ap.account_id = a.account_id
JOIN account_risk_profiles arp
    ON ap.account_id = arp.account_id
ORDER BY ap.platform_transaction_revenue DESC
LIMIT 100;

-- 3. Customer mix by segment and company size.
SELECT
    a.business_segment,
    a.company_size,
    COUNT(DISTINCT p.account_id) AS transacting_accounts,
    COUNT(*) AS successful_payments,
    ROUND(SUM(p.amount), 2) AS gross_payment_volume,
    ROUND(SUM(p.platform_fee_amount), 2) AS platform_transaction_revenue,
    ROUND(
        100.0 * SUM(p.platform_fee_amount) / NULLIF(SUM(p.amount), 0),
        3
    ) AS weighted_platform_margin_rate_pct,
    ROUND(AVG(p.amount), 2) AS average_payment_amount
FROM payments p
JOIN accounts a
    ON p.account_id = a.account_id
WHERE p.status = 'succeeded'
  AND p.is_deleted = FALSE
GROUP BY
    a.business_segment,
    a.company_size
ORDER BY gross_payment_volume DESC;
