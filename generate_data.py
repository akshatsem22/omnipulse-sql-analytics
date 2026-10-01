import pandas as pd
from faker import Faker
import random
from datetime import datetime, timedelta

fake = Faker()
Faker.seed(42)
random.seed(42)

print("Generating synthetic data...")

# 1. Dim_Customer (1,500 records)
customers = []
channels = ['Organic Search', 'Paid Ads', 'Social Media', 'Email Campaign', 'Affiliate']
countries = ['United States', 'United Kingdom', 'Germany', 'Canada', 'India', 'Australia']

for i in range(1, 1501):
    customers.append({
        'customer_id': i,
        'full_name': fake.name(),
        'email': f"user_{i}_{fake.unique.email()}",
        'country': random.choice(countries),
        'signup_date': fake.date_between(start_date='-2y', end_date='-30d'),
        'acquisition_channel': random.choice(channels)
    })
df_customer = pd.DataFrame(customers)
df_customer.to_csv('Dim_Customer.csv', index=False)

# 2. Dim_Product (15 records)
products = [
    (1, 'Analytics Cloud Basic', 'Software', 'Starter', 49.00),
    (2, 'Analytics Cloud Pro', 'Software', 'Professional', 149.00),
    (3, 'Analytics Cloud Enterprise', 'Software', 'Enterprise', 499.00),
    (4, 'Data Connector Plugin', 'Add-on', 'Standard', 19.00),
    (5, 'Warehouse ETL Bridge', 'Add-on', 'Standard', 39.00),
    (6, 'Executive Dashboard Suite', 'Software', 'Professional', 199.00),
    (7, 'Security Audit Add-on', 'Security', 'Enterprise', 99.00),
    (8, 'API Extra Requests (100k)', 'Usage', 'Standard', 15.00),
    (9, 'Single Sign-On Module', 'Security', 'Enterprise', 79.00),
    (10, 'Custom Branding Pack', 'Add-on', 'Starter', 25.00),
    (11, 'Dedicated Support Tier', 'Service', 'Enterprise', 299.00),
    (12, 'Automated Reporting Bot', 'Add-on', 'Professional', 59.00),
    (13, 'Real-time Alerts Engine', 'Add-on', 'Professional', 45.00),
    (14, 'Cold Storage Archive', 'Storage', 'Starter', 10.00),
    (15, 'Predictive ML Add-on', 'Software', 'Enterprise', 349.00)
]
df_product = pd.DataFrame(products, columns=['product_id', 'product_name', 'category', 'tier', 'base_price'])
df_product.to_csv('Dim_Product.csv', index=False)

# 3. Dim_Subscription_Plan (4 records)
plans = [
    (1, 'Starter Monthly', 'Monthly', 49.00),
    (2, 'Pro Monthly', 'Monthly', 149.00),
    (3, 'Enterprise Monthly', 'Monthly', 499.00),
    (4, 'Annual Enterprise', 'Annual', 4990.00)
]
df_plan = pd.DataFrame(plans, columns=['plan_id', 'plan_name', 'billing_cycle', 'monthly_fee'])
df_plan.to_csv('Dim_Subscription_Plan.csv', index=False)

# 4. Fact_Order (6,000 transactions)
orders = []
statuses = ['Completed', 'Completed', 'Completed', 'Refunded', 'Cancelled']
product_prices = dict(zip(df_product['product_id'], df_product['base_price']))

for i in range(1, 6001):
    c_id = random.randint(1, 1500)
    p_id = random.randint(1, 15)
    qty = random.choices([1, 2, 3, 5], weights=[70, 20, 8, 2])[0]
    discount = random.choices([0.0, 0.05, 0.10, 0.20], weights=[60, 20, 15, 5])[0]
    
    base_val = product_prices[p_id] * qty
    net_val = round(base_val * (1.0 - discount), 2)
    order_date = fake.date_time_between(start_date='-18m', end_date='now')

    orders.append({
        'order_id': i,
        'customer_id': c_id,
        'product_id': p_id,
        'order_date': order_date.strftime('%Y-%m-%d %H:%M:%S'),
        'quantity': qty,
        'discount_rate': discount,
        'gross_amount': round(base_val, 2),
        'net_amount': net_val,
        'order_status': random.choice(statuses)
    })
df_order = pd.DataFrame(orders)
df_order.to_csv('Fact_Order.csv', index=False)

# 5. Fact_Subscription_Billing (8,000 monthly invoices)
billings = []
billing_statuses = ['Paid', 'Paid', 'Paid', 'Failed']

for i in range(1, 8001):
    c_id = random.randint(1, 1500)
    pl_id = random.choices([1, 2, 3, 4], weights=[40, 35, 20, 5])[0]
    fee = df_plan.loc[df_plan['plan_id'] == pl_id, 'monthly_fee'].values[0]
    b_date = fake.date_between(start_date='-18m', end_date='today')
    status = random.choice(billing_statuses)
    is_churned = 1 if status == 'Failed' and random.random() < 0.6 else 0

    billings.append({
        'billing_id': i,
        'customer_id': c_id,
        'plan_id': pl_id,
        'billing_date': b_date,
        'amount_paid': fee if status == 'Paid' else 0.00,
        'payment_status': status,
        'is_churned': is_churned
    })
df_billing = pd.DataFrame(billings)
df_billing.to_csv('Fact_Subscription_Billing.csv', index=False)

print("Successfully generated all 5 CSV files in the project directory.")