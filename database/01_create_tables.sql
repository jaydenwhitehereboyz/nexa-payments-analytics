-- ===========================================
-- 1. ACCOUNTS
-- ===========================================

CREATE TABLE accounts (
    account_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    region VARCHAR(100) NOT NULL,
    business_segment VARCHAR(50) NOT NULL,
    company_size VARCHAR(20) NOT NULL
        CHECK (company_size IN ('small', 'medium', 'large'))
);

-- ===========================================
-- 2. TARIFFS
-- ===========================================

CREATE TABLE tariffs (
    tariff_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tariff_name VARCHAR(100) UNIQUE NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    duration_days INTEGER NOT NULL CHECK (duration_days > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ===========================================
-- 3. SUBSCRIPTIONS
-- ===========================================

CREATE TABLE subscriptions (
    subscription_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    account_id BIGINT NOT NULL,
    tariff_id BIGINT NOT NULL,

    purchased_at TIMESTAMP NOT NULL,
    valid_from TIMESTAMP NOT NULL,
    paid_till TIMESTAMP NOT NULL,

    status VARCHAR(20) NOT NULL,

    FOREIGN KEY (account_id)
        REFERENCES accounts(account_id),

    FOREIGN KEY (tariff_id)
        REFERENCES tariffs(tariff_id)
);

-- ===========================================
-- 4. PAYMENTS
-- ===========================================

CREATE TABLE payments (

    payment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    account_id BIGINT NOT NULL,

    payment_system VARCHAR(50) NOT NULL,

    created_at TIMESTAMP NOT NULL,

    amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),

    commission_amount NUMERIC(12,2) NOT NULL CHECK (commission_amount >= 0),

    status VARCHAR(30) NOT NULL,

    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,

    FOREIGN KEY (account_id)
        REFERENCES accounts(account_id)
);

-- ===========================================
-- 5. CHECKOUT REQUESTS
-- ===========================================

CREATE TABLE checkout_requests (

    request_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    account_id BIGINT NOT NULL,

    requested_payment_system VARCHAR(50) NOT NULL,

    created_at TIMESTAMP NOT NULL,

    status VARCHAR(30) NOT NULL,

    FOREIGN KEY (account_id)
        REFERENCES accounts(account_id)
);