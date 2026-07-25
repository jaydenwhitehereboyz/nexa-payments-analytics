\set ON_ERROR_STOP on

-- Run this file from psql with:
-- \i 'C:/py/pet_project_git/saas-revenue-retention-analytics/database/02_load_data.sql'
--
-- The CSV files are expected in:
-- C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/

BEGIN;

-- Clear old data and reset identity counters.
-- CASCADE is needed because tables are connected by foreign keys.
TRUNCATE TABLE
    checkout_requests,
    payments,
    subscriptions,
    tariffs,
    accounts
RESTART IDENTITY CASCADE;

-- Identity columns are intentionally omitted from \copy.
-- PostgreSQL will generate IDs in the same 1..N order as the CSV files.

\copy accounts (
    email,
    created_at,
    region,
    business_segment,
    company_size
)
FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/accounts.csv'
WITH (
    FORMAT csv,
    HEADER true,
    ENCODING 'UTF8'
);

\copy tariffs (
    tariff_name,
    price,
    duration_days,
    is_active,
    created_at
)
FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/tariffs.csv'
WITH (
    FORMAT csv,
    HEADER true,
    ENCODING 'UTF8'
);

\copy subscriptions (
    account_id,
    tariff_id,
    purchased_at,
    valid_from,
    paid_till,
    status
)
FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/subscriptions.csv'
WITH (
    FORMAT csv,
    HEADER true,
    ENCODING 'UTF8'
);

\copy payments (
    account_id,
    payment_system,
    created_at,
    amount,
    commission_amount,
    status,
    is_deleted
)
FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/payments.csv'
WITH (
    FORMAT csv,
    HEADER true,
    ENCODING 'UTF8'
);

\copy checkout_requests (
    account_id,
    requested_payment_system,
    created_at,
    status
)
FROM 'C:/py/pet_project_git/saas-revenue-retention-analytics/data/raw/checkout_requests.csv'
WITH (
    FORMAT csv,
    HEADER true,
    ENCODING 'UTF8'
);

COMMIT;

-- Verification: expected counts are 5000, 4, 15000, 200000 and 1000.
SELECT 'accounts' AS table_name, COUNT(*) AS row_count FROM accounts
UNION ALL
SELECT 'tariffs', COUNT(*) FROM tariffs
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'checkout_requests', COUNT(*) FROM checkout_requests
ORDER BY table_name;
