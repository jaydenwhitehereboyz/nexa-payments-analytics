\set ON_ERROR_STOP on

-- ============================================================
-- Load synthetic payment orchestration data.
--
-- Run from psql:
-- \i 'C:/py/pet_project_git/saas-revenue-retention-analytics/database/02_load_data.sql'
--
-- Expected CSV directory:
-- C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/
--
-- IMPORTANT:
-- psql \copy is a meta-command and every \copy command below must
-- remain on one physical line.
-- ============================================================

BEGIN;

TRUNCATE TABLE
    checkout_requests,
    payments,
    payment_system_monthly_pricing,
    account_risk_profiles,
    subscriptions,
    tariff_payment_conditions,
    payment_system_volume_tiers,
    tariffs,
    payment_systems,
    accounts
RESTART IDENTITY CASCADE;

\copy accounts (account_id, email, created_at, region, business_segment, company_size, account_status, closed_at) FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/accounts.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy payment_systems (payment_system_id, payment_system_name, provider_type, base_market_fee_rate, description, benefits, is_active) FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/payment_systems.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy payment_system_volume_tiers (volume_tier_id, payment_system_id, tier_name, min_monthly_volume, max_monthly_volume, provider_cost_rate) FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/payment_system_volume_tiers.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy tariffs (tariff_id, tariff_name, monthly_price, description, is_active) FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/tariffs.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy tariff_payment_conditions (condition_id, tariff_id, payment_system_id, client_fee_rate, discount_from_market_rate) FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/tariff_payment_conditions.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy subscriptions (subscription_id, account_id, tariff_id, purchased_at, valid_from, paid_till, status) FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/subscriptions.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy account_risk_profiles (risk_profile_id, account_id, risk_level, risk_score, chargeback_rate, refund_rate, risk_surcharge_rate, assessed_at) FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/account_risk_profiles.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy payment_system_monthly_pricing (monthly_pricing_id, payment_system_id, pricing_month, monthly_volume, volume_tier_id, provider_cost_rate) FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/payment_system_monthly_pricing.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy payments (payment_id, account_id, payment_system_id, tariff_id, monthly_pricing_id, created_at, amount, client_fee_rate, provider_cost_rate, risk_surcharge_rate, client_fee_amount, payment_system_fee_amount, platform_fee_amount, merchant_net_amount, status, is_deleted) FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/payments.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy checkout_requests (request_id, account_id, requested_payment_system_id, created_at, status, request_reason) FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/checkout_requests.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');


-- Move identity sequences after the highest imported IDs.
SELECT setval(pg_get_serial_sequence('accounts', 'account_id'), COALESCE(MAX(account_id), 1), MAX(account_id) IS NOT NULL) FROM accounts;
SELECT setval(pg_get_serial_sequence('payment_systems', 'payment_system_id'), COALESCE(MAX(payment_system_id), 1), MAX(payment_system_id) IS NOT NULL) FROM payment_systems;
SELECT setval(pg_get_serial_sequence('payment_system_volume_tiers', 'volume_tier_id'), COALESCE(MAX(volume_tier_id), 1), MAX(volume_tier_id) IS NOT NULL) FROM payment_system_volume_tiers;
SELECT setval(pg_get_serial_sequence('tariffs', 'tariff_id'), COALESCE(MAX(tariff_id), 1), MAX(tariff_id) IS NOT NULL) FROM tariffs;
SELECT setval(pg_get_serial_sequence('tariff_payment_conditions', 'condition_id'), COALESCE(MAX(condition_id), 1), MAX(condition_id) IS NOT NULL) FROM tariff_payment_conditions;
SELECT setval(pg_get_serial_sequence('subscriptions', 'subscription_id'), COALESCE(MAX(subscription_id), 1), MAX(subscription_id) IS NOT NULL) FROM subscriptions;
SELECT setval(pg_get_serial_sequence('account_risk_profiles', 'risk_profile_id'), COALESCE(MAX(risk_profile_id), 1), MAX(risk_profile_id) IS NOT NULL) FROM account_risk_profiles;
SELECT setval(pg_get_serial_sequence('payment_system_monthly_pricing', 'monthly_pricing_id'), COALESCE(MAX(monthly_pricing_id), 1), MAX(monthly_pricing_id) IS NOT NULL) FROM payment_system_monthly_pricing;
SELECT setval(pg_get_serial_sequence('payments', 'payment_id'), COALESCE(MAX(payment_id), 1), MAX(payment_id) IS NOT NULL) FROM payments;
SELECT setval(pg_get_serial_sequence('checkout_requests', 'request_id'), COALESCE(MAX(request_id), 1), MAX(request_id) IS NOT NULL) FROM checkout_requests;

COMMIT;


-- ============================================================
-- Verification
-- ============================================================

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


-- Fee allocation check. A small difference is possible because every
-- transaction component is rounded independently to kopecks.
SELECT
    ROUND(SUM(client_fee_amount), 2) AS total_client_fees,
    ROUND(
        SUM(payment_system_fee_amount) + SUM(platform_fee_amount),
        2
    ) AS provider_cost_plus_platform_revenue,
    ROUND(
        SUM(client_fee_amount)
        - SUM(payment_system_fee_amount)
        - SUM(platform_fee_amount),
        2
    ) AS rounding_difference
FROM payments
WHERE status = 'succeeded'
  AND is_deleted = FALSE;


-- Tier distribution proves that aggregate traffic changes provider pricing.
SELECT
    ps.payment_system_name,
    vt.tier_name,
    COUNT(*) AS months_in_tier,
    ROUND(MIN(mp.monthly_volume), 2) AS min_monthly_volume,
    ROUND(MAX(mp.monthly_volume), 2) AS max_monthly_volume
FROM payment_system_monthly_pricing mp
JOIN payment_systems ps
    ON ps.payment_system_id = mp.payment_system_id
JOIN payment_system_volume_tiers vt
    ON vt.volume_tier_id = mp.volume_tier_id
GROUP BY
    ps.payment_system_name,
    vt.tier_name
ORDER BY
    ps.payment_system_name,
    vt.tier_name;
