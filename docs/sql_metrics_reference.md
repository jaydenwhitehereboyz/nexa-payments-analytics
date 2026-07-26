# Справочник SQL-метрик проекта

Документ описывает метрики из файлов:

- `sql/06_payment_model_overview.sql`
- `sql/07_monthly_payment_kpis.sql`
- `sql/08_payment_system_kpis.sql`
- `sql/09_tariff_kpis.sql`
- `sql/10_risk_and_customer_kpis.sql`

## Общие правила

Почти все денежные KPI считаются только по валидным успешным платежам:

```sql
WHERE status = 'succeeded'
  AND is_deleted = FALSE
```

`amount` — сумма покупки конечного покупателя у бизнеса.

`client_fee_amount` — вся комиссия, удержанная с бизнеса.

`payment_system_fee_amount` — часть комиссии, переданная платёжной системе.

`platform_fee_amount` — наша валовая транзакционная выручка.

`merchant_net_amount` — сумма, оставшаяся бизнесу после комиссии.

```text
client_fee_amount
= payment_system_fee_amount + platform_fee_amount

merchant_net_amount
= amount - client_fee_amount

platform_margin_rate
= client_fee_rate - provider_cost_rate
```

Ставки хранятся десятичными дробями:

```text
0.030 = 3%
0.005 = 0,5%
```

Метрики `weighted_*` считаются через денежные суммы:

```text
weighted_rate
= SUM(соответствующей комиссии) / SUM(amount)
```

Это корректнее простого `AVG(rate)`, потому что крупные платежи получают больший вес.

### Удобный вывод в psql

```sql
\x auto
```

Принудительно вертикально:

```sql
\x on
```

Вернуться к обычной таблице:

```sql
\x off
```

---

# `06_payment_model_overview.sql`

Общая картина базы, главные KPI и проверки формул.

## Запрос 1. Количество строк

`table_name` — название таблицы.

`row_count`:

```text
COUNT(*)
```

Проверяет полноту загрузки данных.

## Запрос 2. Статусы платежей

`status` — `succeeded`, `failed`, `refunded`, `pending`.

`is_deleted` — логическое удаление строки.

`payment_count`:

```text
COUNT(*)
```

Количество платежей в группе `status + is_deleted`.

`share_of_all_payments_pct`:

```text
payment_count / все строки payments × 100
```

## Запрос 3. Главные показатели

`successful_payments`:

```text
COUNT(*)
```

Количество успешных неудалённых платежей.

`transacting_accounts`:

```text
COUNT(DISTINCT account_id)
```

Количество бизнесов хотя бы с одним успешным платежом.

`payment_systems_used`:

```text
COUNT(DISTINCT payment_system_id)
```

Количество реально использованных платёжных систем.

`gross_payment_volume` / `GMV`:

```text
SUM(amount)
```

Общий оборот. Это не наша выручка.

`average_payment_amount`:

```text
AVG(amount)
```

Средний успешный платёж.

`median_payment_amount`:

```text
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount)
```

Половина платежей меньше медианы, половина больше.

`total_client_fees`:

```text
SUM(client_fee_amount)
```

Вся комиссия, удержанная с бизнесов.

`total_provider_cost`:

```text
SUM(payment_system_fee_amount)
```

Сумма, переданная платёжным системам.

`platform_transaction_revenue`:

```text
SUM(platform_fee_amount)
```

Наша валовая транзакционная выручка до операционных расходов и убытков.

`merchant_net_volume`:

```text
SUM(merchant_net_amount)
```

Сумма, оставшаяся бизнесам после комиссий.

`weighted_client_fee_rate_pct`:

```text
SUM(client_fee_amount) / SUM(amount) × 100
```

Средняя эффективная комиссия бизнеса.

`weighted_provider_cost_rate_pct`:

```text
SUM(payment_system_fee_amount) / SUM(amount) × 100
```

Средняя закупочная ставка платёжных систем.

`weighted_platform_margin_rate_pct`:

```text
SUM(platform_fee_amount) / SUM(amount) × 100
```

Средняя транзакционная маржа платформы.

```text
weighted_client_fee_rate_pct
≈ weighted_provider_cost_rate_pct
+ weighted_platform_margin_rate_pct
```

## Запрос 4. Проверки формул

Все результаты должны быть `0`.

`invalid_fee_split_rows`:

```text
client_fee_amount
≠ payment_system_fee_amount + platform_fee_amount
```

`invalid_merchant_net_rows`:

```text
merchant_net_amount
≠ amount - client_fee_amount
```

`invalid_margin_rate_rows`:

```text
platform_margin_rate
≠ client_fee_rate - provider_cost_rate
```

`non_successful_rows_with_money` — неуспешные или удалённые строки с ненулевыми денежными полями.

## Запрос 5. Проверка risk surcharge

`checked_rows` — число проверенных платежей.

`invalid_risk_surcharge_rows` — строки, где нарушено:

```text
payments.client_fee_rate
= tariff_payment_conditions.client_fee_rate
+ payments.risk_surcharge_rate
```

`maximum_rate_difference` — максимальное отклонение от формулы.

Ожидаемый результат:

```text
invalid_risk_surcharge_rows = 0
maximum_rate_difference = 0
```

---

# `07_monthly_payment_kpis.sql`

Динамика бизнеса по месяцам.

## Запрос 1. Месячные KPI

`payment_month`:

```text
DATE_TRUNC('month', created_at)
```

`all_attempts` — все попытки платежа за месяц, включая все статусы и удалённые строки.

`successful_payments` — успешные неудалённые платежи.

`transacting_accounts`:

```text
COUNT(DISTINCT account_id)
```

Активные платящие бизнесы месяца.

`success_rate_pct`:

```text
successful_payments / all_attempts × 100
```

`gross_payment_volume`:

```text
SUM(amount)
```

Месячный GMV успешных платежей.

`average_payment_amount`:

```text
AVG(amount)
```

Средний успешный платёж месяца.

`total_client_fees`:

```text
SUM(client_fee_amount)
```

`total_provider_cost`:

```text
SUM(payment_system_fee_amount)
```

`platform_transaction_revenue`:

```text
SUM(platform_fee_amount)
```

`merchant_net_volume`:

```text
SUM(merchant_net_amount)
```

`risk_surcharge_revenue`:

```text
SUM(amount × risk_surcharge_rate)
```

`weighted_client_fee_rate_pct`:

```text
total_client_fees / gross_payment_volume × 100
```

`weighted_provider_cost_rate_pct`:

```text
total_provider_cost / gross_payment_volume × 100
```

`weighted_platform_margin_rate_pct`:

```text
platform_transaction_revenue / gross_payment_volume × 100
```

`cumulative_gross_payment_volume` — накопительный GMV от первого месяца до текущего.

`cumulative_platform_revenue` — накопительная транзакционная выручка платформы.

## Запрос 2. Структура статусов

`payment_count` — количество платежей статуса в месяце.

`monthly_status_share_pct`:

```text
платежи статуса / все неудалённые платежи месяца × 100
```

---

# `08_payment_system_kpis.sql`

Сравнение платёжных систем.

## Запрос 1. KPI платёжных систем

`payment_system_id` — ID платёжной системы.

`payment_system_name` — название.

`provider_type` — банк, gateway, wallet, transfer rail и т. п.

`base_market_fee_rate_pct`:

```text
payment_systems.base_market_fee_rate × 100
```

Условная публичная ставка без нашей оптовой скидки.

`all_attempts` — все платежи через ПС.

`successful_payments` — успешные неудалённые платежи.

`transacting_accounts` — уникальные бизнесы с успешными платежами через ПС.

`success_rate_pct`:

```text
successful_payments / all_attempts × 100
```

`gross_payment_volume` — успешный оборот через ПС.

`average_payment_amount` — средний успешный платёж через ПС.

`total_client_fees` — комиссии бизнесов на платежах через ПС.

`total_provider_cost` — сколько получила сама ПС.

`platform_transaction_revenue` — сколько заработала платформа.

`weighted_client_fee_rate_pct`:

```text
SUM(client_fee_amount) / SUM(amount) × 100
```

`weighted_provider_cost_rate_pct`:

```text
SUM(payment_system_fee_amount) / SUM(amount) × 100
```

`weighted_platform_margin_rate_pct`:

```text
SUM(platform_fee_amount) / SUM(amount) × 100
```

## Запрос 2. Tiered pricing

`pricing_month` — месяц действия ставки.

`monthly_volume` — суммарный месячный оборот всех бизнесов через ПС.

`tier_name` — достигнутый `Tier 1–4`.

`tier_min_volume` — минимальный оборот tier.

`tier_max_volume` — верхняя граница; у последнего tier может быть `NULL`.

`market_fee_rate_pct` — условная публичная ставка.

`provider_cost_rate_pct` — наша фактическая оптовая ставка.

`wholesale_discount_vs_market_pct_points`:

```text
base_market_fee_rate - provider_cost_rate
```

Пример:

```text
3,0% - 2,5% = 0,5 процентного пункта
```

## Запрос 3. Доля ПС в GMV

`payment_volume_share_pct`:

```text
оборот ПС / общий оборот всех ПС × 100
```

---

# `09_tariff_kpis.sql`

Сравнение `Free`, `Pro`, `Enterprise`.

## Запрос 1. Экономика тарифов

`tariff_id` — ID тарифа.

`tariff_name` — название.

`monthly_price` — стоимость подписки в месяц.

`successful_payments` — успешные платежи на тарифе.

`transacting_accounts` — бизнесы с платежами на тарифе.

`payment_systems_used` — количество использованных ПС.

`gross_payment_volume` — оборот тарифа.

`average_payment_amount` — средний платёж.

`total_client_fees` — комиссия бизнесов.

`total_provider_cost` — расходы на ПС.

`platform_transaction_revenue` — транзакционная выручка платформы. Подписка сюда не входит.

`risk_surcharge_revenue`:

```text
SUM(amount × risk_surcharge_rate)
```

`weighted_base_client_fee_rate_pct`:

```text
SUM(amount × (client_fee_rate - risk_surcharge_rate))
/ SUM(amount) × 100
```

Средняя ставка до risk surcharge.

`weighted_effective_client_fee_rate_pct`:

```text
SUM(client_fee_amount) / SUM(amount) × 100
```

Фактическая ставка после risk surcharge.

`weighted_provider_cost_rate_pct`:

```text
SUM(payment_system_fee_amount) / SUM(amount) × 100
```

`weighted_platform_margin_rate_pct`:

```text
SUM(platform_fee_amount) / SUM(amount) × 100
```

## Запрос 2. Матрица «тариф × ПС»

`base_client_fee_rate_pct` — ставка комбинации до риска.

`discount_from_market_pct_points`:

```text
base_market_fee_rate - base_client_fee_rate
```

`successful_payments` — успешные платежи комбинации.

`transacting_accounts` — бизнесы, использовавшие комбинацию.

`gross_payment_volume` — оборот комбинации.

`weighted_risk_surcharge_rate_pct`:

```text
SUM(amount × risk_surcharge_rate) / SUM(amount) × 100
```

`weighted_provider_cost_rate_pct` — оптовая ставка ПС для комбинации.

`weighted_platform_margin_rate_pct` — маржа платформы для комбинации.

`platform_transaction_revenue` — транзакционная выручка комбинации.

## Запрос 3. Последний тариф клиента

`ROW_NUMBER()` нумерует подписки от новой к старой внутри каждого `account_id`.

`subscription_status` — статус последней подписки.

`accounts` — количество клиентов с данным последним тарифом и статусом.

---

# `10_risk_and_customer_kpis.sql`

Риск, отдельные клиенты и сегменты.

## Запрос 1. Экономика по risk level

`risk_level` — `low`, `medium`, `high`.

`transacting_accounts` — уникальные платящие бизнесы группы.

`successful_payments` — успешные платежи группы.

`average_risk_score`:

```text
AVG(risk_score)
```

В текущем запросе это среднее по строкам платежей: клиенты с большим количеством платежей получают больший вес.

`average_chargeback_rate_pct` — средний chargeback rate по строкам платежей.

`average_refund_rate_pct` — средний refund rate по строкам платежей.

`configured_risk_surcharge_pct` — средняя настроенная риск-надбавка по строкам платежей.

`gross_payment_volume` — оборот risk-группы.

`average_payment_amount` — средний платёж группы.

`total_client_fees` — комиссии клиентов группы.

`total_provider_cost` — расходы на ПС.

`platform_transaction_revenue` — транзакционная выручка платформы.

`risk_surcharge_revenue`:

```text
SUM(amount × risk_surcharge_rate)
```

`base_margin_revenue`:

```text
SUM(
    platform_fee_amount
    - amount × risk_surcharge_rate
)
```

Маржа без risk surcharge.

`weighted_effective_client_fee_rate_pct`:

```text
SUM(client_fee_amount) / SUM(amount) × 100
```

`weighted_provider_cost_rate_pct`:

```text
SUM(payment_system_fee_amount) / SUM(amount) × 100
```

`weighted_platform_margin_rate_pct`:

```text
SUM(platform_fee_amount) / SUM(amount) × 100
```

## Запрос 2. Сводка по клиентам

`successful_payments` — успешные платежи клиента.

`payment_systems_used` — число ПС клиента.

`tariffs_used` — число тарифов, встречавшихся в его платежах.

`first_payment_at` — первый успешный платёж.

`last_payment_at` — последний успешный платёж.

`gross_payment_volume` — общий оборот клиента.

`average_payment_amount` — средний платёж клиента.

`total_client_fees` — комиссия клиента.

`total_provider_cost` — часть комиссии, переданная ПС.

`platform_transaction_revenue` — наша транзакционная выручка от клиента.

`merchant_net_volume` — сумма, оставшаяся бизнесу.

`risk_surcharge_revenue` — выручка от risk surcharge.

`weighted_platform_margin_rate_pct`:

```text
platform_transaction_revenue / gross_payment_volume × 100
```

Результат отсортирован по нашей выручке и ограничен топ-100 клиентами.

Из **accounts** также выводятся:

- `email`
- `region`
- `business_segment`
- `company_size`
- `account_status`

Из **account_risk_profiles**:

- `risk_level`
- `risk_score`
- `chargeback_rate_pct`
- `refund_rate_pct`

## Запрос 3. Сегмент и размер бизнеса

Группировка:

```text
business_segment + company_size
```

`transacting_accounts` — платящие бизнесы группы.

`successful_payments` — успешные платежи.

`gross_payment_volume` — оборот.

`platform_transaction_revenue` — наша транзакционная выручка.

`weighted_platform_margin_rate_pct`:

```text
SUM(platform_fee_amount) / SUM(amount) × 100
```

`average_payment_amount` — средний платёж группы.

---

# Главные KPI для первого погружения

## Масштаб

`gross_payment_volume` — сколько денег прошло через платформу.

`successful_payments` — сколько платежей обработано успешно.

`transacting_accounts` — сколько бизнесов реально пользуются продуктом.

`average_payment_amount` и `median_payment_amount` — размер типичного платежа.

## Качество платежей

`success_rate_pct` — доля успешных попыток.

`monthly_status_share_pct` — структура ошибок, возвратов и ожидания.

## Экономика

`total_client_fees` — сколько заплатили бизнесы.

`total_provider_cost` — сколько получили платёжные системы.

`platform_transaction_revenue` — сколько осталось платформе.

`weighted_platform_margin_rate_pct` — сколько платформе остаётся с каждого рубля GMV.

## Pricing

`weighted_client_fee_rate_pct` — фактическая ставка клиента.

`weighted_provider_cost_rate_pct` — закупочная ставка платформы.

`wholesale_discount_vs_market_pct_points` — эффект агрегированного оборота.

`tier_name` — достигнутый уровень оптовой ставки.

## Риск

`risk_surcharge_revenue` — доход от риск-надбавки.

`base_margin_revenue` — маржа без риск-надбавки.

`chargeback_rate_pct` и `refund_rate_pct` — риск-характеристики.

---

# Что не является чистой прибылью

`platform_transaction_revenue` — валовая транзакционная выручка, не чистая прибыль.

Для прибыли позже нужно вычесть:

```text
chargeback losses
dispute fees
fraud losses
операционные расходы
поддержку
инфраструктуру
налоги
```

Стоимость подписок в этих пяти файлах пока не прибавляется к транзакционной выручке.
