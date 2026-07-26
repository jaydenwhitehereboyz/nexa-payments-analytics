SELECT 'accounts' AS table_name, COUNT(*) AS row_count
FROM accounts

UNION ALL

SELECT 'tariffs', COUNT(*)
FROM tariffs

UNION ALL

SELECT 'subscriptions', COUNT(*)
FROM subscriptions

UNION ALL

SELECT 'payments', COUNT(*)
FROM payments

UNION ALL

SELECT 'checkout_requests', COUNT(*)
FROM checkout_requests;

/* we need to make sure that we have 
accounts	5 000
tariffs	4
subscriptions	15 000
payments	200 000
checkout_requests	1 000
this amount of rows 
*/
SELECT
    email,
    COUNT(*) AS duplicate_count
FROM accounts
GROUP BY email
HAVING COUNT(*) > 1;
/* here we make sure that there is no duplicates*/
SELECT
    COUNT(*) FILTER (WHERE email IS NULL) AS null_email,
    COUNT(*) FILTER (WHERE region IS NULL) AS null_region,
    COUNT(*) FILTER (WHERE business_segment IS NULL) AS null_segment,
    COUNT(*) FILTER (WHERE company_size IS NULL) AS null_company_size
FROM accounts;

SELECT
    COUNT(*) FILTER (WHERE amount < 0) AS negative_amounts,
    COUNT(*) FILTER (WHERE commission_amount < 0) AS negative_commissions,
    COUNT(*) FILTER (WHERE commission_amount > amount) AS commission_above_amount,
    COUNT(*) FILTER (WHERE account_id IS NULL) AS null_account_id
FROM payments;

SELECT COUNT(*) AS payments_without_account
FROM payments p
LEFT JOIN accounts a
    ON p.account_id = a.account_id
WHERE a.account_id IS NULL;

SELECT COUNT(*) AS subscriptions_without_account
FROM subscriptions s
LEFT JOIN accounts a
    ON s.account_id = a.account_id
WHERE a.account_id IS NULL;

SELECT COUNT(*) AS subscriptions_without_tariff
FROM subscriptions s
LEFT JOIN tariffs t
    ON s.tariff_id = t.tariff_id
WHERE t.tariff_id IS NULL;

SELECT COUNT(*) AS invalid_subscription_dates
FROM subscriptions
WHERE
    purchased_at > valid_from
    OR valid_from >= paid_till;

