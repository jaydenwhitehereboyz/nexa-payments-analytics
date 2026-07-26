\set ON_ERROR_STOP on

-- ============================================================
-- MONTHLY PAYMENT KPIS
-- Time series of traffic, conversion and transaction economics.
-- ============================================================

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', created_at)::DATE AS payment_month,
        COUNT(*) AS all_attempts,
        COUNT(*) FILTER (
            WHERE status = 'succeeded' AND is_deleted = FALSE
        ) AS successful_payments,
        COUNT(DISTINCT account_id) FILTER (
            WHERE status = 'succeeded' AND is_deleted = FALSE
        ) AS transacting_accounts,
        SUM(amount) FILTER (
            WHERE status = 'succeeded' AND is_deleted = FALSE
        ) AS gross_payment_volume,
        AVG(amount) FILTER (
            WHERE status = 'succeeded' AND is_deleted = FALSE
        ) AS average_payment_amount,
        SUM(client_fee_amount) FILTER (
            WHERE status = 'succeeded' AND is_deleted = FALSE
        ) AS total_client_fees,
        SUM(payment_system_fee_amount) FILTER (
            WHERE status = 'succeeded' AND is_deleted = FALSE
        ) AS total_provider_cost,
        SUM(platform_fee_amount) FILTER (
            WHERE status = 'succeeded' AND is_deleted = FALSE
        ) AS platform_transaction_revenue,
        SUM(merchant_net_amount) FILTER (
            WHERE status = 'succeeded' AND is_deleted = FALSE
        ) AS merchant_net_volume,
        SUM(amount * risk_surcharge_rate) FILTER (
            WHERE status = 'succeeded' AND is_deleted = FALSE
        ) AS risk_surcharge_revenue
    FROM payments
    GROUP BY DATE_TRUNC('month', created_at)::DATE
)
SELECT
    payment_month,
    all_attempts,
    successful_payments,
    transacting_accounts,
    ROUND(
        100.0 * successful_payments / NULLIF(all_attempts, 0),
        2
    ) AS success_rate_pct,
    ROUND(gross_payment_volume, 2) AS gross_payment_volume,
    ROUND(average_payment_amount, 2) AS average_payment_amount,
    ROUND(total_client_fees, 2) AS total_client_fees,
    ROUND(total_provider_cost, 2) AS total_provider_cost,
    ROUND(platform_transaction_revenue, 2) AS platform_transaction_revenue,
    ROUND(merchant_net_volume, 2) AS merchant_net_volume,
    ROUND(risk_surcharge_revenue, 2) AS risk_surcharge_revenue,
    ROUND(
        100.0 * total_client_fees / NULLIF(gross_payment_volume, 0),
        3
    ) AS weighted_client_fee_rate_pct,
    ROUND(
        100.0 * total_provider_cost / NULLIF(gross_payment_volume, 0),
        3
    ) AS weighted_provider_cost_rate_pct,
    ROUND(
        100.0 * platform_transaction_revenue
        / NULLIF(gross_payment_volume, 0),
        3
    ) AS weighted_platform_margin_rate_pct,
    ROUND(
        SUM(gross_payment_volume) OVER (
            ORDER BY payment_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS cumulative_gross_payment_volume,
    ROUND(
        SUM(platform_transaction_revenue) OVER (
            ORDER BY payment_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS cumulative_platform_revenue
FROM monthly
ORDER BY payment_month;

-- Monthly payment status mix.
SELECT
    DATE_TRUNC('month', created_at)::DATE AS payment_month,
    status,
    COUNT(*) AS payment_count,
    ROUND(
        100.0 * COUNT(*)
        / NULLIF(
            SUM(COUNT(*)) OVER (
                PARTITION BY DATE_TRUNC('month', created_at)::DATE
            ),
            0
        ),
        2
    ) AS monthly_status_share_pct
FROM payments
WHERE is_deleted = FALSE
GROUP BY
    DATE_TRUNC('month', created_at)::DATE,
    status
ORDER BY payment_month, payment_count DESC;
