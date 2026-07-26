from pathlib import Path
import numpy as np
import pandas as pd

SEED = 42
N_ACCOUNTS = 5000
N_PAYMENTS = 200000
rng = np.random.default_rng(SEED)

OUT = Path(__file__).resolve().parent.parent / "data" / "raw"


PAYMENT_SYSTEMS = pd.DataFrame([
    [1, 'alpha_bank', 'low acquiring cost, fast settlements, strong SMB coverage', 0.030],
    [2, 'tinkoff', 'high conversion, installments, advanced merchant tools', 0.060],
    [3, 'cloudpayments', 'developer friendly API, ecommerce focus, recurring payments', 0.030],
    [4, 'yookassa', 'simple integration, many payment methods, marketplaces', 0.029],
    [5, 'stripe', 'international payments, subscriptions, global cards', 0.029],
], columns=['payment_system_id','payment_system','benefits','market_fee'])


TARIFFS = pd.DataFrame([
    [1,'Free',0],
    [2,'Pro',20000],
    [3,'Enterprise',50000],
], columns=['tariff_id','tariff_name','monthly_price'])


def generate_tariff_conditions():
    rows=[]
    rules={
        'Free': {0.0:0.030},
        'Pro': {0.0:0.027},
        'Enterprise': {0.0:0.025},
    }

    for _, ps in PAYMENT_SYSTEMS.iterrows():
        for tariff, fees in [('Free',0),('Pro',0),('Enterprise',0)]:
            if tariff=='Free':
                client_fee = ps.market_fee
                cost = ps.market_fee-0.002
            elif tariff=='Pro':
                client_fee = max(ps.market_fee-0.003,0.005)
                cost = client_fee-0.004
            else:
                client_fee = max(ps.market_fee-0.005,0.005)
                cost = client_fee-0.005
            rows.append([
                tariff,
                ps.payment_system_id,
                round(client_fee,4),
                round(cost,4),
                round(client_fee-cost,4)
            ])

    return pd.DataFrame(rows, columns=[
        'tariff_name','payment_system_id','client_fee',
        'payment_system_fee','platform_fee'
    ])


def generate_payments(accounts):
    tariff = rng.choice([1,2,3], size=len(accounts), p=[0.7,0.25,0.05])
    accounts = accounts.copy()
    accounts['tariff_id']=tariff

    selected = rng.choice(accounts.index, size=N_PAYMENTS)
    payments = accounts.loc[selected].reset_index(drop=True)

    ps = rng.choice(PAYMENT_SYSTEMS.payment_system_id, size=N_PAYMENTS)

    conditions = generate_tariff_conditions()
    temp = pd.DataFrame({'tariff_id':payments.tariff_id,'payment_system_id':ps})

    temp = temp.merge(
        TARIFFS,
        on='tariff_id'
    ).merge(
        conditions,
        left_on=['tariff_name','payment_system_id'],
        right_on=['tariff_name','payment_system_id']
    )

    amount = np.round(rng.lognormal(10,1,N_PAYMENTS),2)

    return pd.DataFrame({
        'payment_id':range(1,N_PAYMENTS+1),
        'account_id':payments.account_id,
        'payment_system_id':ps,
        'tariff_id':payments.tariff_id,
        'amount':amount,
        'client_fee':temp.client_fee,
        'payment_system_fee':np.round(amount*temp.payment_system_fee,2),
        'platform_fee':np.round(amount*temp.platform_fee,2),
        'created_at':pd.Timestamp('2026-01-01')
    })


if __name__=='__main__':
    print('Generate pricing model v2')
    PAYMENT_SYSTEMS.to_csv(OUT/'payment_systems.csv',index=False)
    TARIFFS.to_csv(OUT/'tariffs.csv',index=False)
    generate_tariff_conditions().to_csv(OUT/'tariff_payment_conditions.csv',index=False)
    print('Pricing tables created')
