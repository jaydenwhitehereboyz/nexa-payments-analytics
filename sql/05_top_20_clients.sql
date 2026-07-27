WITH payment_system_stats AS (
    SELECT
        account_id,
        payment_system,
        SUM(amount) AS system_revenue
    FROM payments
    WHERE
        status = 'succeeded'
        AND is_deleted = FALSE
    GROUP BY
        account_id,
        payment_system
),

ranked_systems AS (
    SELECT
        account_id,
        payment_system,
        system_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY system_revenue DESC
        ) AS system_rank
    FROM payment_system_stats
),

main_payment_system AS (
    SELECT
        account_id,
        payment_system
    FROM ranked_systems
    WHERE system_rank = 1
),

customer_revenue AS (
    SELECT
        account_id,
        COUNT(*) AS successful_payments,
        SUM(amount) AS gross_revenue,
        SUM(commission_amount) AS total_commission,
        SUM(amount - commission_amount) AS net_revenue
    FROM payments
    WHERE
        status = 'succeeded'
        AND is_deleted = FALSE
    GROUP BY account_id
)

SELECT
    a.account_id,
    a.email,
    a.region,
    a.business_segment,
    a.company_size,
    mps.payment_system AS main_payment_system,
    cr.successful_payments,
    cr.gross_revenue,
    cr.total_commission,
    cr.net_revenue,

    ROUND(
        cr.gross_revenue
        / SUM(cr.gross_revenue) OVER ()
        * 100,
        2
    ) AS revenue_share_pct

FROM customer_revenue cr

JOIN accounts a
    ON cr.account_id = a.account_id

LEFT JOIN main_payment_system mps
    ON cr.account_id = mps.account_id

ORDER BY cr.gross_revenue DESC

LIMIT 20; 
