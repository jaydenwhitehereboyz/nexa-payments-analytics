SELECT payment_system, COUNT(*) as successful_payments, COUNT(DISTINCT account_id),
SUM(amount) as gross_revenue, ROUND(AVG(amount),2) AS AOV, SUM(commission_amount), SUM(amount - commission_amount) 
AS net_revenue, ROUND(SUM(commission_amount)/NULLIF(SUM(amount),0) * 100,2) AS avg_ECR
FROM payments
WHERE
    status = 'succeeded' AND is_deleted = FALSE
GROUP BY payment_system
ORDER BY gross_revenue DESC;