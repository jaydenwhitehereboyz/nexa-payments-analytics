from pathlib import Path

import numpy as np
import pandas as pd

RANDOM_SEED = 42
N_ACCOUNTS = 5_000
N_PAYMENTS = 200_000
N_SUBSCRIPTIONS = 15_000
N_CHECKOUT_REQUESTS = 1_000

START_DATE = pd.Timestamp("2022-01-01")
END_DATE = pd.Timestamp("2026-06-30")
ANALYSIS_DATE = pd.Timestamp("2026-07-01")

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"
rng = np.random.default_rng(RANDOM_SEED)


def random_dates_between(
    start_dates: pd.Series | pd.DatetimeIndex,
    end_date: pd.Timestamp,
) -> pd.Series:
    """Generate random datetimes between each start date and one end date."""
    starts = pd.Series(pd.to_datetime(start_dates)).reset_index(drop=True)
    available_seconds = (
        (end_date - starts).dt.total_seconds().clip(lower=0).to_numpy()
    )
    random_seconds = rng.random(len(starts)) * available_seconds
    return starts + pd.to_timedelta(random_seconds, unit="s")


def save_csv(dataframe: pd.DataFrame, filename: str) -> None:
    file_path = OUTPUT_DIR / filename
    dataframe.to_csv(file_path, index=False, encoding="utf-8")
    print(f"{filename:<30} {len(dataframe):>10,} rows")


def generate_accounts() -> pd.DataFrame:
    account_ids = np.arange(1, N_ACCOUNTS + 1)

    created_seconds = rng.integers(
        0,
        int((END_DATE - START_DATE).total_seconds()),
        size=N_ACCOUNTS,
    )

    accounts = pd.DataFrame(
        {
            "account_id": account_ids,
            "email": [
                f"company_{account_id:05d}@example.com"
                for account_id in account_ids
            ],
            "created_at": START_DATE
            + pd.to_timedelta(created_seconds, unit="s"),
            "region": rng.choice(
                [
                    "Moscow",
                    "Saint Petersburg",
                    "Central",
                    "Volga",
                    "South",
                    "Ural",
                    "Siberia",
                    "Far East",
                    "Northwest",
                ],
                size=N_ACCOUNTS,
                p=[0.25, 0.13, 0.12, 0.14, 0.10, 0.09, 0.08, 0.04, 0.05],
            ),
            "business_segment": rng.choice(
                [
                    "ecommerce",
                    "retail",
                    "education",
                    "services",
                    "travel",
                    "saas",
                    "entertainment",
                    "other",
                ],
                size=N_ACCOUNTS,
                p=[0.24, 0.18, 0.11, 0.17, 0.07, 0.10, 0.06, 0.07],
            ),
            "company_size": rng.choice(
                ["small", "medium", "large"],
                size=N_ACCOUNTS,
                p=[0.67, 0.25, 0.08],
            ),
        }
    )

    return accounts.sort_values("account_id").reset_index(drop=True)


def generate_tariffs() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "tariff_id": [1, 2, 3, 4],
            "tariff_name": [
                "Starter",
                "Business",
                "Professional",
                "Enterprise",
            ],
            "price": [990.00, 2_990.00, 7_990.00, 19_990.00],
            "duration_days": [30, 30, 30, 30],
            "is_active": [True, True, True, True],
            "created_at": pd.to_datetime(
                ["2022-01-01", "2022-01-01", "2022-06-01", "2023-01-01"]
            ),
        }
    )


def choose_tariff(company_size: str) -> int:
    probabilities = {
        "small": [0.62, 0.28, 0.09, 0.01],
        "medium": [0.12, 0.48, 0.32, 0.08],
        "large": [0.02, 0.13, 0.40, 0.45],
    }
    return int(rng.choice([1, 2, 3, 4], p=probabilities[company_size]))


def generate_subscriptions(accounts: pd.DataFrame) -> pd.DataFrame:
    account_weights = accounts["company_size"].map(
        {"small": 1.0, "medium": 1.8, "large": 3.0}
    ).to_numpy()
    account_weights = account_weights / account_weights.sum()

    subscription_counts = rng.multinomial(
        N_SUBSCRIPTIONS,
        account_weights,
    )

    lead_day_weights = np.array(
        [
            0.18, 0.12, 0.09, 0.07, 0.06, 0.05, 0.04, 0.04,
            0.035, 0.03, 0.03, 0.025, 0.025, 0.02, 0.02, 0.02,
            0.018, 0.018, 0.016, 0.016, 0.014, 0.014, 0.012,
            0.012, 0.010, 0.010, 0.008, 0.008, 0.006, 0.006, 0.004,
        ],
        dtype=float,
    )
    lead_day_probabilities = lead_day_weights / lead_day_weights.sum()

    rows: list[dict] = []
    subscription_id = 1

    for account, subscription_count in zip(
        accounts.itertuples(index=False),
        subscription_counts,
    ):
        if subscription_count == 0:
            continue

        next_valid_from = pd.Timestamp(account.created_at) + pd.Timedelta(
            days=int(rng.integers(0, 120))
        )

        for _ in range(subscription_count):
            tariff_id = choose_tariff(account.company_size)
            purchase_lead_days = int(
                rng.choice(np.arange(31), p=lead_day_probabilities)
            )

            valid_from = next_valid_from
            purchased_at = max(
                valid_from - pd.Timedelta(days=purchase_lead_days),
                pd.Timestamp(account.created_at),
            )
            paid_till = valid_from + pd.Timedelta(days=30)

            if rng.random() < 0.04:
                status = "cancelled"
            elif paid_till >= ANALYSIS_DATE:
                status = "active"
            else:
                status = "expired"

            rows.append(
                {
                    "subscription_id": subscription_id,
                    "account_id": account.account_id,
                    "tariff_id": tariff_id,
                    "purchased_at": purchased_at,
                    "valid_from": valid_from,
                    "paid_till": paid_till,
                    "status": status,
                }
            )
            subscription_id += 1

            gap_days = int(
                rng.choice(
                    [0, 7, 14, 30, 60],
                    p=[0.83, 0.06, 0.04, 0.04, 0.03],
                )
            )
            next_valid_from = paid_till + pd.Timedelta(days=gap_days)

    return pd.DataFrame(rows).sort_values(
        ["account_id", "valid_from", "subscription_id"]
    ).reset_index(drop=True)


def generate_payments(accounts: pd.DataFrame) -> pd.DataFrame:
    account_weights = accounts["company_size"].map(
        {"small": 1.0, "medium": 3.5, "large": 10.0}
    ).to_numpy()
    account_weights = account_weights / account_weights.sum()

    selected_account_ids = rng.choice(
        accounts["account_id"].to_numpy(),
        size=N_PAYMENTS,
        replace=True,
        p=account_weights,
    )

    payment_accounts = pd.DataFrame(
        {"account_id": selected_account_ids}
    ).merge(
        accounts[
            ["account_id", "created_at", "company_size", "business_segment"]
        ],
        on="account_id",
        how="left",
    )

    payment_system = rng.choice(
        ["stripe", "paypal", "cloudpayments", "yookassa", "tinkoff"],
        size=N_PAYMENTS,
        p=[0.24, 0.12, 0.25, 0.25, 0.14],
    )

    size_multiplier = payment_accounts["company_size"].map(
        {"small": 1.0, "medium": 3.5, "large": 10.0}
    ).to_numpy()

    segment_multiplier = payment_accounts["business_segment"].map(
        {
            "ecommerce": 1.45,
            "retail": 1.25,
            "education": 0.75,
            "services": 0.90,
            "travel": 1.70,
            "saas": 1.10,
            "entertainment": 0.85,
            "other": 0.80,
        }
    ).to_numpy()

    amount = rng.lognormal(mean=7.2, sigma=1.0, size=N_PAYMENTS)
    amount = np.round(
        np.clip(amount * size_multiplier * segment_multiplier, 100, 1_500_000),
        2,
    )

    statuses = rng.choice(
        ["succeeded", "failed", "refunded", "pending"],
        size=N_PAYMENTS,
        p=[0.93, 0.04, 0.02, 0.01],
    )

    commission_rates = pd.Series(payment_system).map(
        {
            "stripe": 0.029,
            "paypal": 0.035,
            "cloudpayments": 0.026,
            "yookassa": 0.028,
            "tinkoff": 0.024,
        }
    ).to_numpy()

    commission_amount = np.round(
        np.where(statuses == "succeeded", amount * commission_rates, 0),
        2,
    )

    payments = pd.DataFrame(
        {
            "payment_id": np.arange(1, N_PAYMENTS + 1),
            "account_id": selected_account_ids,
            "payment_system": payment_system,
            "created_at": random_dates_between(
                payment_accounts["created_at"],
                END_DATE,
            ),
            "amount": amount,
            "commission_amount": commission_amount,
            "status": statuses,
            "is_deleted": rng.choice(
                [False, True],
                size=N_PAYMENTS,
                p=[0.995, 0.005],
            ),
        }
    )

    return payments.sort_values(
        ["created_at", "payment_id"]
    ).reset_index(drop=True)


def generate_checkout_requests(accounts: pd.DataFrame) -> pd.DataFrame:
    selected_accounts = accounts.sample(
        n=N_CHECKOUT_REQUESTS,
        replace=False,
        random_state=RANDOM_SEED,
    ).reset_index(drop=True)

    requests = pd.DataFrame(
        {
            "request_id": np.arange(1, N_CHECKOUT_REQUESTS + 1),
            "account_id": selected_accounts["account_id"],
            "requested_payment_system": rng.choice(
                ["stripe", "paypal", "cloudpayments", "yookassa", "tinkoff"],
                size=N_CHECKOUT_REQUESTS,
                p=[0.18, 0.10, 0.25, 0.28, 0.19],
            ),
            "created_at": random_dates_between(
                selected_accounts["created_at"],
                END_DATE,
            ),
            "status": rng.choice(
                ["new", "in_progress", "approved", "rejected"],
                size=N_CHECKOUT_REQUESTS,
                p=[0.12, 0.18, 0.58, 0.12],
            ),
        }
    )

    return requests.sort_values(
        ["created_at", "request_id"]
    ).reset_index(drop=True)


def validate_data(
    accounts: pd.DataFrame,
    tariffs: pd.DataFrame,
    subscriptions: pd.DataFrame,
    payments: pd.DataFrame,
    checkout_requests: pd.DataFrame,
) -> None:
    assert len(accounts) == N_ACCOUNTS
    assert len(payments) == N_PAYMENTS
    assert len(subscriptions) == N_SUBSCRIPTIONS
    assert len(checkout_requests) == N_CHECKOUT_REQUESTS

    assert accounts["account_id"].is_unique
    assert accounts["email"].is_unique
    assert payments["payment_id"].is_unique
    assert subscriptions["subscription_id"].is_unique
    assert checkout_requests["request_id"].is_unique

    assert payments["account_id"].isin(accounts["account_id"]).all()
    assert subscriptions["account_id"].isin(accounts["account_id"]).all()
    assert subscriptions["tariff_id"].isin(tariffs["tariff_id"]).all()
    assert checkout_requests["account_id"].isin(accounts["account_id"]).all()

    assert (payments["amount"] >= 0).all()
    assert (payments["commission_amount"] >= 0).all()
    assert (subscriptions["paid_till"] > subscriptions["valid_from"]).all()

    print("\nValidation passed successfully.")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print("Generating data...\n")

    accounts = generate_accounts()
    tariffs = generate_tariffs()
    subscriptions = generate_subscriptions(accounts)
    payments = generate_payments(accounts)
    checkout_requests = generate_checkout_requests(accounts)

    validate_data(
        accounts=accounts,
        tariffs=tariffs,
        subscriptions=subscriptions,
        payments=payments,
        checkout_requests=checkout_requests,
    )

    print("\nSaving CSV files...\n")
    save_csv(accounts, "accounts.csv")
    save_csv(tariffs, "tariffs.csv")
    save_csv(subscriptions, "subscriptions.csv")
    save_csv(payments, "payments.csv")
    save_csv(checkout_requests, "checkout_requests.csv")

    print(f"\nFiles saved to:\n{OUTPUT_DIR}")


if __name__ == "__main__":
    main()
