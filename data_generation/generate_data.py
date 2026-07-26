from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


SEED = 42
N_ACCOUNTS = 5_000
N_PAYMENTS = 200_000
N_SUBS_PER_ACCOUNT = 3
N_REQUESTS = 1_000

START_DATE = pd.Timestamp("2022-01-01")
END_DATE = pd.Timestamp("2026-06-30 23:59:59")
ANALYSIS_DATE = pd.Timestamp("2026-07-01")
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"

rng = np.random.default_rng(SEED)


# Synthetic commercial terms for this portfolio project.
# Decimal 0.030000 means 3.00%.
PAYMENT_SYSTEMS = pd.DataFrame(
    [
        [1, "alpha_bank", "bank_acquiring", 0.0300,
         "Synthetic universal-bank acquiring offer.",
         "Low acquiring cost, fast settlements, broad SME coverage and simple domestic card acceptance.", True],
        [2, "tbank", "bank_ecosystem", 0.0600,
         "Synthetic premium bank ecosystem offer.",
         "High conversion, installments, tokenization, advanced merchant tools and a strong consumer ecosystem.", True],
        [3, "cloudpayments", "payment_gateway", 0.0320,
         "Synthetic developer-focused gateway offer.",
         "Developer-friendly API, recurring payments, saved cards, flexible checkout and ecommerce tooling.", True],
        [4, "yookassa", "payment_gateway", 0.0290,
         "Synthetic multi-method checkout offer.",
         "Many payment methods, marketplace support, familiar checkout, simple onboarding and domestic coverage.", True],
        [5, "sberpay", "bank_wallet", 0.0270,
         "Synthetic bank-wallet and acquiring offer.",
         "Large retail user base, one-click bank payments, fast authorization and strong ecosystem conversion.", True],
        [6, "stripe", "international_gateway", 0.0390,
         "Synthetic international gateway offer.",
         "International cards, multi-currency payments, subscriptions, developer tooling and cross-border expansion.", True],
        [7, "paypal", "international_wallet", 0.0450,
         "Synthetic international wallet offer.",
         "Buyer trust, international wallet reach, dispute tooling and checkout without entering card details.", True],
        [8, "sbp", "bank_transfer", 0.0120,
         "Synthetic fast bank-transfer rail offer.",
         "Very low commission, instant bank-to-bank payments, QR checkout and suitability for low-margin merchants.", True],
    ],
    columns=[
        "payment_system_id", "payment_system_name", "provider_type",
        "base_market_fee_rate", "description", "benefits", "is_active",
    ],
)

TARIFFS = pd.DataFrame(
    [
        [1, "Free", 0.00,
         "No monthly fee, public-like processing rates, basic dashboard and standard support.", True],
        [2, "Pro", 20_000.00,
         "Lower processing rates, advanced analytics, recurring payments and priority support.", True],
        [3, "Enterprise", 50_000.00,
         "Best rates, payment routing, SLA, account management and custom integrations.", True],
    ],
    columns=["tariff_id", "tariff_name", "monthly_price", "description", "is_active"],
)

CLIENT_RATES = {
    1: {1: 0.0300, 2: 0.0280, 3: 0.0270},
    2: {1: 0.0600, 2: 0.0550, 3: 0.0500},
    3: {1: 0.0320, 2: 0.0290, 3: 0.0280},
    4: {1: 0.0290, 2: 0.0270, 3: 0.0260},
    5: {1: 0.0270, 2: 0.0250, 3: 0.0240},
    6: {1: 0.0390, 2: 0.0360, 3: 0.0330},
    7: {1: 0.0450, 2: 0.0420, 3: 0.0390},
    8: {1: 0.0120, 2: 0.0100, 3: 0.0090},
}

# Provider wholesale cost by aggregate monthly platform volume:
# <100m, 100m-500m, 500m-1bn, >=1bn RUB.
PROVIDER_COSTS = {
    1: [0.0260, 0.0250, 0.0240, 0.0230],
    2: [0.0500, 0.0470, 0.0440, 0.0400],
    3: [0.0280, 0.0270, 0.0260, 0.0250],
    4: [0.0250, 0.0240, 0.0230, 0.0220],
    5: [0.0230, 0.0220, 0.0210, 0.0200],
    6: [0.0330, 0.0310, 0.0290, 0.0270],
    7: [0.0390, 0.0370, 0.0350, 0.0330],
    8: [0.0090, 0.0080, 0.0070, 0.0060],
}

TIER_BOUNDS = [
    ("Tier 1", 0.00, 100_000_000.00),
    ("Tier 2", 100_000_000.00, 500_000_000.00),
    ("Tier 3", 500_000_000.00, 1_000_000_000.00),
    ("Tier 4", 1_000_000_000.00, None),
]

SYSTEM_IDS = np.arange(1, 9)
SYSTEM_PROBS = np.array([0.16, 0.14, 0.18, 0.22, 0.12, 0.08, 0.05, 0.05])


def random_dates(start_dates: pd.Series, end_dates: pd.Series) -> pd.Series:
    starts = pd.Series(pd.to_datetime(start_dates)).reset_index(drop=True)
    ends = pd.Series(pd.to_datetime(end_dates)).reset_index(drop=True)
    seconds = (ends - starts).dt.total_seconds().clip(lower=0).to_numpy()
    return starts + pd.to_timedelta(rng.random(len(starts)) * seconds, unit="s")


def save_csv(df: pd.DataFrame, filename: str) -> None:
    df.to_csv(OUTPUT_DIR / filename, index=False, encoding="utf-8")
    print(f"{filename:<42} {len(df):>10,} rows")


def generate_volume_tiers() -> pd.DataFrame:
    rows = []
    tier_id = 1
    for system_id in SYSTEM_IDS:
        for index, (name, min_volume, max_volume) in enumerate(TIER_BOUNDS):
            rows.append([
                tier_id, int(system_id), name, min_volume, max_volume,
                PROVIDER_COSTS[int(system_id)][index],
            ])
            tier_id += 1
    return pd.DataFrame(rows, columns=[
        "volume_tier_id", "payment_system_id", "tier_name",
        "min_monthly_volume", "max_monthly_volume", "provider_cost_rate",
    ])


def generate_tariff_conditions() -> pd.DataFrame:
    market_rates = PAYMENT_SYSTEMS.set_index(
        "payment_system_id"
    )["base_market_fee_rate"].to_dict()
    rows = []
    condition_id = 1
    for system_id, tariffs in CLIENT_RATES.items():
        for tariff_id, client_rate in tariffs.items():
            rows.append([
                condition_id, tariff_id, system_id, client_rate,
                market_rates[system_id] - client_rate,
            ])
            condition_id += 1
    return pd.DataFrame(rows, columns=[
        "condition_id", "tariff_id", "payment_system_id",
        "client_fee_rate", "discount_from_market_rate",
    ])


def generate_accounts() -> pd.DataFrame:
    ids = np.arange(1, N_ACCOUNTS + 1)
    max_created = pd.Timestamp("2025-09-30")
    created_at = START_DATE + pd.to_timedelta(
        rng.integers(
            0, int((max_created - START_DATE).total_seconds()), N_ACCOUNTS
        ),
        unit="s",
    )
    company_size = rng.choice(
        ["small", "medium", "large"], N_ACCOUNTS, p=[0.67, 0.25, 0.08]
    )
    churned = rng.random(N_ACCOUNTS) < 0.15
    closed_at = pd.Series(pd.NaT, index=range(N_ACCOUNTS), dtype="datetime64[ns]")

    indexes = np.where(churned)[0]
    earliest = pd.Series(created_at[indexes]).reset_index(drop=True) + pd.Timedelta(days=120)
    latest = pd.Series(pd.Timestamp("2026-05-31"), index=range(len(indexes)))
    closed_at.iloc[indexes] = random_dates(earliest, latest).to_numpy()

    return pd.DataFrame({
        "account_id": ids,
        "email": [f"company_{x:05d}@example.com" for x in ids],
        "created_at": created_at,
        "region": rng.choice(
            ["Moscow", "Saint Petersburg", "Central", "Volga", "South",
             "Ural", "Siberia", "Far East", "Northwest"],
            N_ACCOUNTS,
            p=[0.25, 0.13, 0.12, 0.14, 0.10, 0.09, 0.08, 0.04, 0.05],
        ),
        "business_segment": rng.choice(
            ["ecommerce", "retail", "education", "services", "travel",
             "saas", "entertainment", "other"],
            N_ACCOUNTS,
            p=[0.24, 0.18, 0.11, 0.17, 0.07, 0.10, 0.06, 0.07],
        ),
        "company_size": company_size,
        "account_status": np.where(churned, "churned", "active"),
        "closed_at": closed_at,
    }).sort_values("account_id").reset_index(drop=True)


def choose_initial_tariff(size: str) -> int:
    probs = {
        "small": [0.82, 0.17, 0.01],
        "medium": [0.25, 0.65, 0.10],
        "large": [0.03, 0.42, 0.55],
    }
    return int(rng.choice([1, 2, 3], p=probs[size]))


def choose_next_tariff(current: int, size: str) -> int:
    transitions = {
        1: {
            "small": [0.76, 0.23, 0.01],
            "medium": [0.42, 0.52, 0.06],
            "large": [0.10, 0.62, 0.28],
        },
        2: {
            "small": [0.15, 0.80, 0.05],
            "medium": [0.06, 0.76, 0.18],
            "large": [0.02, 0.48, 0.50],
        },
        3: {
            "small": [0.04, 0.26, 0.70],
            "medium": [0.01, 0.14, 0.85],
            "large": [0.00, 0.06, 0.94],
        },
    }
    return int(rng.choice([1, 2, 3], p=transitions[current][size]))


def generate_subscriptions(accounts: pd.DataFrame) -> pd.DataFrame:
    rows = []
    subscription_id = 1
    for account in accounts.itertuples(index=False):
        start = pd.Timestamp(account.created_at)
        end = pd.Timestamp(account.closed_at) if pd.notna(account.closed_at) else ANALYSIS_DATE
        lifetime = max(int((end - start).total_seconds()), N_SUBS_PER_ACCOUNT)
        split_1 = start + pd.to_timedelta(
            int(lifetime * rng.uniform(0.20, 0.36)), unit="s"
        )
        split_2 = start + pd.to_timedelta(
            int(lifetime * rng.uniform(0.58, 0.78)), unit="s"
        )
        boundaries = [start, split_1, split_2, end]
        tariff_id = choose_initial_tariff(account.company_size)

        for index in range(N_SUBS_PER_ACCOUNT):
            valid_from = boundaries[index]
            paid_till = boundaries[index + 1]
            rows.append([
                subscription_id, account.account_id, tariff_id,
                max(start, valid_from - pd.Timedelta(days=int(rng.integers(0, 16)))),
                valid_from, paid_till,
                "active" if index == 2 and account.account_status == "active" else "expired",
            ])
            subscription_id += 1
            if index < 2:
                tariff_id = choose_next_tariff(tariff_id, account.company_size)

    return pd.DataFrame(rows, columns=[
        "subscription_id", "account_id", "tariff_id", "purchased_at",
        "valid_from", "paid_till", "status",
    ]).sort_values(["account_id", "valid_from"]).reset_index(drop=True)


def generate_risk_profiles(accounts: pd.DataFrame) -> pd.DataFrame:
    segment_risk = {
        "saas": 0.05, "education": 0.08, "services": 0.10, "retail": 0.12,
        "ecommerce": 0.16, "entertainment": 0.19, "travel": 0.27, "other": 0.14,
    }
    score = (
        accounts["business_segment"].map(segment_risk).to_numpy()
        + accounts["company_size"].map(
            {"small": 0.05, "medium": 0.00, "large": -0.03}
        ).to_numpy()
        + rng.normal(0, 0.045, len(accounts))
    )
    score = np.clip(score, 0.01, 0.55)
    level = np.select(
        [score < 0.13, score < 0.25], ["low", "medium"], default="high"
    )
    surcharge = pd.Series(level).map(
        {"low": 0.0000, "medium": 0.0015, "high": 0.0040}
    ).to_numpy()

    return pd.DataFrame({
        "risk_profile_id": np.arange(1, len(accounts) + 1),
        "account_id": accounts["account_id"],
        "risk_level": level,
        "risk_score": np.round(score, 4),
        "chargeback_rate": np.round(
            np.clip(score * rng.uniform(0.035, 0.075, len(accounts)), 0.0001, 0.04),
            6,
        ),
        "refund_rate": np.round(
            np.clip(score * rng.uniform(0.10, 0.22, len(accounts)), 0.001, 0.12),
            6,
        ),
        "risk_surcharge_rate": np.round(surcharge, 6),
        "assessed_at": accounts["created_at"],
    })


def generate_base_payments(accounts: pd.DataFrame) -> pd.DataFrame:
    weights = accounts["company_size"].map(
        {"small": 1.0, "medium": 4.0, "large": 14.0}
    ).to_numpy()
    selected_ids = rng.choice(
        accounts["account_id"].to_numpy(),
        N_PAYMENTS,
        replace=True,
        p=weights / weights.sum(),
    )
    selected = pd.DataFrame({"account_id": selected_ids}).merge(
        accounts[[
            "account_id", "created_at", "closed_at",
            "company_size", "business_segment",
        ]],
        on="account_id",
        how="left",
    )
    dates = random_dates(
        selected["created_at"],
        selected["closed_at"].fillna(END_DATE),
    )
    size_factor = selected["company_size"].map(
        {"small": 0.7, "medium": 3.2, "large": 11.5}
    ).to_numpy()
    segment_factor = selected["business_segment"].map({
        "ecommerce": 1.55, "retail": 1.25, "education": 0.70, "services": 0.90,
        "travel": 1.80, "saas": 1.15, "entertainment": 0.85, "other": 0.80,
    }).to_numpy()
    amount = np.round(
        np.clip(
            rng.lognormal(12.0, 1.05, N_PAYMENTS) * size_factor * segment_factor,
            500.00,
            50_000_000.00,
        ),
        2,
    )

    return pd.DataFrame({
        "payment_id": np.arange(1, N_PAYMENTS + 1),
        "account_id": selected_ids,
        "payment_system_id": rng.choice(
            SYSTEM_IDS, N_PAYMENTS, p=SYSTEM_PROBS
        ),
        "created_at": dates,
        "amount": amount,
        "status": rng.choice(
            ["succeeded", "failed", "refunded", "pending"],
            N_PAYMENTS,
            p=[0.93, 0.04, 0.02, 0.01],
        ),
        "is_deleted": rng.choice(
            [False, True], N_PAYMENTS, p=[0.995, 0.005]
        ),
    })


def choose_tier(system_id: int, volume: float, tiers: pd.DataFrame) -> int:
    candidates = tiers[tiers["payment_system_id"] == system_id].sort_values(
        "min_monthly_volume"
    )
    for row in candidates.itertuples(index=False):
        if volume >= row.min_monthly_volume and (
            pd.isna(row.max_monthly_volume) or volume < row.max_monthly_volume
        ):
            return int(row.volume_tier_id)
    raise ValueError(f"No tier for system={system_id}, volume={volume}")


def generate_monthly_pricing(
    base_payments: pd.DataFrame,
    tiers: pd.DataFrame,
) -> pd.DataFrame:
    valid = base_payments[
        (base_payments["status"] == "succeeded")
        & (~base_payments["is_deleted"])
    ].copy()
    valid["pricing_month"] = valid["created_at"].dt.to_period("M").dt.to_timestamp()
    monthly = (
        valid.groupby(["payment_system_id", "pricing_month"], as_index=False)["amount"]
        .sum()
        .rename(columns={"amount": "monthly_volume"})
    )
    rows = []
    for pricing_id, row in enumerate(monthly.itertuples(index=False), start=1):
        tier_id = choose_tier(
            int(row.payment_system_id), float(row.monthly_volume), tiers
        )
        cost = tiers.loc[
            tiers["volume_tier_id"] == tier_id, "provider_cost_rate"
        ].iloc[0]
        rows.append([
            pricing_id, int(row.payment_system_id), row.pricing_month,
            round(float(row.monthly_volume), 2), tier_id, float(cost),
        ])
    return pd.DataFrame(rows, columns=[
        "monthly_pricing_id", "payment_system_id", "pricing_month",
        "monthly_volume", "volume_tier_id", "provider_cost_rate",
    ])


def attach_tariffs(
    payments: pd.DataFrame,
    subscriptions: pd.DataFrame,
) -> pd.DataFrame:
    result = payments.sort_values(
        ["account_id", "created_at", "payment_id"]
    ).reset_index(drop=True)
    result["tariff_id"] = np.nan

    for period in range(N_SUBS_PER_ACCOUNT):
        sub = (
            subscriptions.groupby("account_id", as_index=False)
            .nth(period)
            .reset_index(drop=True)[
                ["account_id", "tariff_id", "valid_from", "paid_till"]
            ]
            .rename(columns={
                "tariff_id": f"tariff_{period}",
                "valid_from": f"start_{period}",
                "paid_till": f"end_{period}",
            })
        )
        result = result.merge(sub, on="account_id", how="left")
        mask = (
            (result["created_at"] >= result[f"start_{period}"])
            & (result["created_at"] < result[f"end_{period}"])
        )
        result.loc[mask, "tariff_id"] = result.loc[mask, f"tariff_{period}"]

    result = result.drop(columns=[
        column for column in result.columns
        if (
            column.startswith("tariff_") and column != "tariff_id"
        )
        or column.startswith("start_")
        or column.startswith("end_")
    ])
    if result["tariff_id"].isna().any():
        raise ValueError("Some payments do not have a matching subscription.")
    result["tariff_id"] = result["tariff_id"].astype(int)
    return result


def calculate_payment_economics(
    base_payments: pd.DataFrame,
    subscriptions: pd.DataFrame,
    risk_profiles: pd.DataFrame,
    conditions: pd.DataFrame,
    monthly_pricing: pd.DataFrame,
) -> pd.DataFrame:
    payments = attach_tariffs(base_payments, subscriptions)
    payments["pricing_month"] = payments["created_at"].dt.to_period("M").dt.to_timestamp()
    payments = payments.merge(
        monthly_pricing,
        on=["payment_system_id", "pricing_month"],
        how="left",
        validate="many_to_one",
    )
    payments = payments.merge(
        conditions[["tariff_id", "payment_system_id", "client_fee_rate"]],
        on=["tariff_id", "payment_system_id"],
        how="left",
        validate="many_to_one",
    )
    payments = payments.merge(
        risk_profiles[["account_id", "risk_surcharge_rate"]],
        on="account_id",
        how="left",
        validate="many_to_one",
    )
    if payments[[
        "monthly_pricing_id", "provider_cost_rate",
        "client_fee_rate", "risk_surcharge_rate",
    ]].isna().any().any():
        raise ValueError("Missing pricing data after payment joins.")

    payments["client_fee_rate"] = (
        payments["client_fee_rate"].astype(float)
        + payments["risk_surcharge_rate"].astype(float)
    )
    payments["provider_cost_rate"] = payments["provider_cost_rate"].astype(float)
    if (payments["client_fee_rate"] < payments["provider_cost_rate"]).any():
        raise ValueError("Client fee is below provider cost.")

    successful = (
        (payments["status"] == "succeeded")
        & (~payments["is_deleted"])
    )
    payments["client_fee_amount"] = np.where(
        successful, payments["amount"] * payments["client_fee_rate"], 0
    )
    payments["payment_system_fee_amount"] = np.where(
        successful, payments["amount"] * payments["provider_cost_rate"], 0
    )
    payments["platform_fee_amount"] = (
        payments["client_fee_amount"] - payments["payment_system_fee_amount"]
    )
    payments["merchant_net_amount"] = np.where(
        successful, payments["amount"] - payments["client_fee_amount"], 0
    )

    money = [
        "client_fee_amount", "payment_system_fee_amount",
        "platform_fee_amount", "merchant_net_amount",
    ]
    rates = ["client_fee_rate", "provider_cost_rate", "risk_surcharge_rate"]
    payments[money] = payments[money].round(2)
    payments[rates] = payments[rates].round(6)

    return payments[[
        "payment_id", "account_id", "payment_system_id", "tariff_id",
        "monthly_pricing_id", "created_at", "amount", "client_fee_rate",
        "provider_cost_rate", "risk_surcharge_rate", "client_fee_amount",
        "payment_system_fee_amount", "platform_fee_amount",
        "merchant_net_amount", "status", "is_deleted",
    ]].sort_values(["created_at", "payment_id"]).reset_index(drop=True)


def generate_checkout_requests(
    accounts: pd.DataFrame,
    payments: pd.DataFrame,
) -> pd.DataFrame:
    selected = accounts.sample(
        N_REQUESTS, replace=False, random_state=SEED
    ).reset_index(drop=True)
    primary = (
        payments[
            (payments["status"] == "succeeded")
            & (~payments["is_deleted"])
        ]
        .groupby(["account_id", "payment_system_id"], as_index=False)["amount"]
        .sum()
        .sort_values(["account_id", "amount"], ascending=[True, False])
        .drop_duplicates("account_id")
        .set_index("account_id")["payment_system_id"]
        .to_dict()
    )
    requested = []
    for account_id in selected["account_id"]:
        available = SYSTEM_IDS[SYSTEM_IDS != primary.get(int(account_id))]
        requested.append(int(rng.choice(available)))

    return pd.DataFrame({
        "request_id": np.arange(1, N_REQUESTS + 1),
        "account_id": selected["account_id"],
        "requested_payment_system_id": requested,
        "created_at": random_dates(
            selected["created_at"], selected["closed_at"].fillna(END_DATE)
        ),
        "status": rng.choice(
            ["new", "in_progress", "approved", "rejected"],
            N_REQUESTS,
            p=[0.12, 0.18, 0.58, 0.12],
        ),
        "request_reason": rng.choice(
            ["lower_fee", "international_payments", "higher_conversion",
             "installments", "additional_payment_methods", "provider_backup"],
            N_REQUESTS,
            p=[0.34, 0.12, 0.20, 0.10, 0.14, 0.10],
        ),
    }).sort_values(["created_at", "request_id"]).reset_index(drop=True)


def validate(
    accounts: pd.DataFrame,
    systems: pd.DataFrame,
    tiers: pd.DataFrame,
    tariffs: pd.DataFrame,
    conditions: pd.DataFrame,
    subscriptions: pd.DataFrame,
    risks: pd.DataFrame,
    monthly_pricing: pd.DataFrame,
    payments: pd.DataFrame,
    requests: pd.DataFrame,
) -> None:
    assert len(accounts) == 5_000
    assert len(systems) == 8
    assert len(tiers) == 32
    assert len(tariffs) == 3
    assert len(conditions) == 24
    assert len(subscriptions) == 15_000
    assert len(risks) == 5_000
    assert len(payments) == 200_000
    assert len(requests) == 1_000
    assert not payments.isna().any().any()
    assert (payments["client_fee_rate"] >= payments["provider_cost_rate"]).all()
    assert (payments["platform_fee_amount"] >= 0).all()
    assert (
        subscriptions["paid_till"] > subscriptions["valid_from"]
    ).all()
    print("\nValidation passed successfully.")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print("Generating payment orchestration data...\n")

    accounts = generate_accounts()
    systems = PAYMENT_SYSTEMS.copy()
    tiers = generate_volume_tiers()
    tariffs = TARIFFS.copy()
    conditions = generate_tariff_conditions()
    subscriptions = generate_subscriptions(accounts)
    risks = generate_risk_profiles(accounts)
    base_payments = generate_base_payments(accounts)
    monthly_pricing = generate_monthly_pricing(base_payments, tiers)
    payments = calculate_payment_economics(
        base_payments, subscriptions, risks, conditions, monthly_pricing
    )
    requests = generate_checkout_requests(accounts, payments)

    validate(
        accounts, systems, tiers, tariffs, conditions, subscriptions,
        risks, monthly_pricing, payments, requests,
    )

    print("\nSaving CSV files...\n")
    save_csv(accounts, "accounts.csv")
    save_csv(systems, "payment_systems.csv")
    save_csv(tiers, "payment_system_volume_tiers.csv")
    save_csv(tariffs, "tariffs.csv")
    save_csv(conditions, "tariff_payment_conditions.csv")
    save_csv(subscriptions, "subscriptions.csv")
    save_csv(risks, "account_risk_profiles.csv")
    save_csv(monthly_pricing, "payment_system_monthly_pricing.csv")
    save_csv(payments, "payments.csv")
    save_csv(requests, "checkout_requests.csv")
    print(f"\nFiles saved to:\n{OUTPUT_DIR}")


if __name__ == "__main__":
    main()
