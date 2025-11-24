-- Create database
CREATE DATABASE IF NOT EXISTS chatbot_db;
USE chatbot_db;

-- Customers table
CREATE TABLE IF NOT EXISTS customers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(20),
  city VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products table
CREATE TABLE IF NOT EXISTS products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  stock INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  product VARCHAR(150) NOT NULL,
  quantity INT NOT NULL,
  total_price DECIMAL(10,2) NOT NULL,
  order_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- Search history (bonus)
CREATE TABLE IF NOT EXISTS search_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  question TEXT NOT NULL,
  generated_sql TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed customers
INSERT INTO customers (name, phone, city) VALUES
  ('Alice Johnson', '555-0101', 'New York'),
  ('Brian Smith', '555-0112', 'Austin'),
  ('Carla Ruiz', '555-0133', 'San Francisco'),
  ('Deepak Nair', '555-0165', 'Seattle'),
  ('Ella Zhang', '555-0199', 'Chicago');

-- Seed products
INSERT INTO products (name, price, stock) VALUES
  ('Wireless Keyboard', 49.99, 25),
  ('Noise Canceling Headphones', 129.00, 8),
  ('4K Monitor', 329.00, 6),
  ('USB-C Hub', 34.50, 42),
  ('Laptop Stand', 58.00, 15);

-- Seed orders
INSERT INTO orders (customer_id, product, quantity, total_price, order_date) VALUES
  (1, 'Wireless Keyboard', 2, 99.98, CURDATE()),
  (2, '4K Monitor', 1, 329.00, CURDATE()),
  (3, 'Noise Canceling Headphones', 1, 129.00, DATE_SUB(CURDATE(), INTERVAL 1 DAY)),
  (4, 'USB-C Hub', 3, 103.50, DATE_SUB(CURDATE(), INTERVAL 2 DAY)),
  (5, 'Laptop Stand', 2, 116.00, DATE_SUB(CURDATE(), INTERVAL 7 DAY));

