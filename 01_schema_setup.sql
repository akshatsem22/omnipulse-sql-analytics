-- Create Database
CREATE DATABASE IF NOT EXISTS omnipulse_db;
USE omnipulse_db;

-- 1. Customers Dimension Table
CREATE TABLE Dim_Customer (
    customer_id INT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    country VARCHAR(50) NOT NULL,
    signup_date DATE NOT NULL,
    acquisition_channel VARCHAR(50) NOT NULL
);

-- 2. Products Dimension Table
CREATE TABLE Dim_Product (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    tier VARCHAR(20) NOT NULL,
    base_price DECIMAL(10,2) NOT NULL
);

-- 3. Subscriptions Dimension Table
CREATE TABLE Dim_Subscription_Plan (
    plan_id INT PRIMARY KEY,
    plan_name VARCHAR(50) NOT NULL,
    billing_cycle VARCHAR(20) NOT NULL,
    monthly_fee DECIMAL(10,2) NOT NULL
);

-- 4. Orders Fact Table (E-commerce Transactions)
CREATE TABLE Fact_Order (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    order_date TIMESTAMP NOT NULL,
    quantity INT NOT NULL,
    discount_rate DECIMAL(4,2) DEFAULT 0.00,
    gross_amount DECIMAL(10,2) NOT NULL,
    net_amount DECIMAL(10,2) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES Dim_Customer(customer_id),
    FOREIGN KEY (product_id) REFERENCES Dim_Product(product_id)
);

-- 5. Subscriptions Fact Table (Recurring Billing)
CREATE TABLE Fact_Subscription_Billing (
    billing_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    plan_id INT NOT NULL,
    billing_date DATE NOT NULL,
    amount_paid DECIMAL(10,2) NOT NULL,
    payment_status VARCHAR(20) NOT NULL,
    is_churned TINYINT(1) DEFAULT 0,
    FOREIGN KEY (customer_id) REFERENCES Dim_Customer(customer_id),
    FOREIGN KEY (plan_id) REFERENCES Dim_Subscription_Plan(plan_id)
);