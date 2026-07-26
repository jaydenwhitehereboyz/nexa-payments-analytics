SELECT
    TO_CHAR(DATE_TRUNC('month', created_at), 'YYYY-MM') AS payment_month,
    COUNT(*) AS successful_payments, COUNT(DISTINCT account_id) as unique_clients, SUM(amount) as gross_revenue, 
    SUM(commission_amount) as total_commission, SUM(amount - commission_amount) AS net_revenue
FROM payments
WHERE
    status = 'succeeded'
    AND is_deleted = FALSE
GROUP BY
    DATE_TRUNC('month', created_at)
ORDER BY
    payment_month;


