WITH payment_system_stats AS (
    SELECT
        account_id,
        payment_system,
        COUNT(*) AS payment_count,
        SUM(amount) AS revenue
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
        payment_count,
        revenue,
        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY revenue DESC
        ) AS system_rank
    FROM payment_system_stats
)
SELECT
    account_id,
    payment_system,
    payment_count,
    revenue
FROM ranked_systems
WHERE system_rank = 1
ORDER BY revenue DESC;