-- =====================================================================
-- TechMart E-commerce Database (PostgreSQL, run in pgAdmin)
--
-- How to run:
--   * Run CREATE DATABASE on its own in a Query Tool on "postgres".
--   * Open a Query Tool on techmart for everything else.
--   * Run statements one at a time (highlight + F5). The tests in
--     Part 3.2 and the first DELETE in Part 3.4 are EXPECTED to fail.
-- =====================================================================

-- =====================================================================
-- PART 1: DATABASE CREATION AND DDL
-- =====================================================================

-- 1. Create the database (run on its own while connected to "postgres",
--    then open a Query Tool on techmart for everything below)
CREATE DATABASE TechMart;

-- 2. Customers
CREATE TABLE Customers (
    CustomerID  INT           NOT NULL,
    FirstName   VARCHAR(50)   NOT NULL,
    LastName    VARCHAR(50)   NOT NULL,
    Email       VARCHAR(100)  NOT NULL,
    JoinDate    DATE          DEFAULT CURRENT_DATE,
    CONSTRAINT pk_customers         PRIMARY KEY (CustomerID),
    CONSTRAINT uq_customers_email   UNIQUE (Email),
    CONSTRAINT chk_customers_fname  CHECK (TRIM(FirstName) <> ''),
    CONSTRAINT chk_customers_lname  CHECK (TRIM(LastName)  <> '')
);

-- 3. Products (ProductName gets NOT NULL in Part 2)
CREATE TABLE Products (
    ProductID      INT            NOT NULL,
    ProductName    VARCHAR(100),
    Price          NUMERIC(10,2)  NOT NULL,
    StockQuantity  INT            NOT NULL DEFAULT 0,
    CONSTRAINT pk_products        PRIMARY KEY (ProductID),
    CONSTRAINT chk_products_price CHECK (Price > 0),
    CONSTRAINT chk_products_stock CHECK (StockQuantity >= 0)
);

-- 4. Orders
CREATE TABLE Orders (
    OrderID     INT          NOT NULL,
    CustomerID  INT          NOT NULL,
    OrderDate   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    Status      VARCHAR(20)  NOT NULL DEFAULT 'Pending',
    CONSTRAINT pk_orders          PRIMARY KEY (OrderID),
    CONSTRAINT chk_orders_status  CHECK (Status IN ('Pending', 'Shipped', 'Delivered')),
    CONSTRAINT fk_orders_customer FOREIGN KEY (CustomerID)
        REFERENCES Customers (CustomerID)
        ON DELETE RESTRICT      -- can't delete a customer who has orders
        ON UPDATE CASCADE
);

-- 5. OrderItems
CREATE TABLE OrderItems (
    OrderItemID  INT  NOT NULL,
    OrderID      INT  NOT NULL,
    ProductID    INT  NOT NULL,
    Quantity     INT  NOT NULL,
    CONSTRAINT pk_orderitems          PRIMARY KEY (OrderItemID),
    CONSTRAINT chk_orderitems_qty     CHECK (Quantity > 0),
    CONSTRAINT fk_orderitems_order    FOREIGN KEY (OrderID)
        REFERENCES Orders (OrderID)
        ON DELETE CASCADE       -- deleting an order removes its items
        ON UPDATE CASCADE,
    CONSTRAINT fk_orderitems_product  FOREIGN KEY (ProductID)
        REFERENCES Products (ProductID)
        ON DELETE RESTRICT      -- protects order history (see Part 3.4)
        ON UPDATE CASCADE
);


-- =====================================================================
-- PART 2: SCHEMA MODIFICATION (DDL)
-- =====================================================================

-- 2.1 Make ProductName NOT NULL (done before any data is inserted)
ALTER TABLE Products
    ALTER COLUMN ProductName SET NOT NULL;

-- 2.2 Add the Category column
ALTER TABLE Products
    ADD COLUMN Category VARCHAR(50);

-- 2.3 Add PhoneNumber to Customers, UNIQUE
-- VARCHAR, not INT: phone numbers contain '+' and can start with 0.
ALTER TABLE Customers
    ADD COLUMN PhoneNumber VARCHAR(20),
    ADD CONSTRAINT uq_customers_phone UNIQUE (PhoneNumber);

-- Verify the changes (run each SELECT on its own)
SELECT column_name, data_type, is_nullable, column_default
FROM   information_schema.columns
WHERE  table_name = 'products'
ORDER BY ordinal_position;

SELECT column_name, data_type, is_nullable, column_default
FROM   information_schema.columns
WHERE  table_name = 'customers'
ORDER BY ordinal_position;

SELECT conname AS constraint_name,
       pg_get_constraintdef(oid) AS definition
FROM   pg_constraint
WHERE  conrelid = 'customers'::regclass;


-- =====================================================================
-- PART 3: DATA MANIPULATION (DML)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3.1 INSERT
-- ---------------------------------------------------------------------

-- Customers 1 and 2: JoinDate supplied
-- (Customer 2's email has a typo, "gmial", fixed in Part 3.3)
INSERT INTO Customers (CustomerID, FirstName, LastName, Email, JoinDate, PhoneNumber)
VALUES
    (1, 'Aline', 'Uwase',   'aline.uwase@gmail.com',  '2026-01-15', '+250788111111'),
    (2, 'Eric',  'Mugisha', 'eric.mugisha@gmial.com', '2026-03-02', '+250788222222');

-- Customer 3: JoinDate OMITTED -> tests the DEFAULT (today's date)
INSERT INTO Customers (CustomerID, FirstName, LastName, Email, PhoneNumber)
VALUES
    (3, 'Diane', 'Ingabire', 'diane.ingabire@gmail.com', '+250788333333');

-- Products 1-3: StockQuantity supplied
INSERT INTO Products (ProductID, ProductName, Category, Price, StockQuantity)
VALUES
    (1, 'Dell Latitude 5440 Laptop',   'Laptops',     899.99, 15),
    (2, 'Logitech MX Master 3S Mouse', 'Accessories',  99.99, 40),
    (3, 'Mechanical Keyboard',         'Accessories',  79.50, 25);

-- Product 4: StockQuantity OMITTED -> tests the DEFAULT (0)
INSERT INTO Products (ProductID, ProductName, Category, Price)
VALUES
    (4, 'USB-C Hub 7-in-1', 'Accessories', 34.99);

-- Order 1 (customer 1): every value supplied
INSERT INTO Orders (OrderID, CustomerID, OrderDate, Status)
VALUES
    (1, 1, '2026-10-10 14:30:00', 'Shipped');

-- Order 2 (customer 3, a different customer): OrderDate and Status OMITTED
-- -> tests the DEFAULTs (current timestamp and 'Pending')
INSERT INTO Orders (OrderID, CustomerID)
VALUES
    (2, 3);

-- 3 order items tying products to orders
INSERT INTO OrderItems (OrderItemID, OrderID, ProductID, Quantity)
VALUES
    (1, 1, 1, 1),   -- Order 1: 1 x Laptop
    (2, 1, 2, 2),   -- Order 1: 2 x Mouse
    (3, 2, 3, 1);   -- Order 2: 1 x Keyboard

-- Verify the data and the defaults (run each SELECT on its own)
SELECT * FROM Customers;    -- Diane's JoinDate = today's date
SELECT * FROM Products;     -- USB-C Hub StockQuantity = 0
SELECT * FROM Orders;       -- Order 2: OrderDate = now, Status = 'Pending'
SELECT * FROM OrderItems;


-- ---------------------------------------------------------------------
-- 3.2 TEST CONSTRAINTS (each statement below is EXPECTED to fail)
-- ---------------------------------------------------------------------

-- Test A: insert a customer with an email that already exists
INSERT INTO Customers (CustomerID, FirstName, LastName, Email)
VALUES (4, 'Grace', 'Keza', 'aline.uwase@gmail.com');
-- BLOCKED BY: UNIQUE constraint uq_customers_email.
-- Email must be unique across all customers, and aline.uwase@gmail.com
-- already belongs to customer 1.
-- ERROR: duplicate key value violates unique constraint "uq_customers_email"
-- DETAIL: Key (email)=(aline.uwase@gmail.com) already exists.   [SQLSTATE 23505]

-- Test B: insert a product with a price of -5.00
INSERT INTO Products (ProductID, ProductName, Category, Price, StockQuantity)
VALUES (5, 'Faulty Cable', 'Accessories', -5.00, 10);
-- BLOCKED BY: CHECK constraint chk_products_price (Price > 0).
-- ERROR: new row for relation "products" violates check constraint "chk_products_price"   [SQLSTATE 23514]

-- Test C: insert an order for a CustomerID that does not exist
INSERT INTO Orders (OrderID, CustomerID)
VALUES (3, 999);
-- BLOCKED BY: FOREIGN KEY constraint fk_orders_customer.
-- CustomerID 999 has no matching row in Customers (referential integrity).
-- ERROR: insert or update on table "orders" violates foreign key constraint "fk_orders_customer"
-- DETAIL: Key (customerid)=(999) is not present in table "customers".   [SQLSTATE 23503]


-- ---------------------------------------------------------------------
-- 3.3 UPDATE
-- ---------------------------------------------------------------------

-- Fix customer 2's email typo ("gmial" -> "gmail").
-- The WHERE on the primary key makes sure only ONE customer changes.
UPDATE Customers
SET    Email = 'eric.mugisha@gmail.com'
WHERE  CustomerID = 2;

-- Restock: increase the keyboard's stock by 50 (25 -> 75).
-- StockQuantity + 50 adds to the current value instead of overwriting it.
UPDATE Products
SET    StockQuantity = StockQuantity + 50
WHERE  ProductID = 3;

-- Verify the updates
SELECT CustomerID, Email FROM Customers WHERE CustomerID = 2;
SELECT ProductID, ProductName, StockQuantity FROM Products WHERE ProductID = 3;


-- ---------------------------------------------------------------------
-- 3.4 DELETE
-- ---------------------------------------------------------------------

-- Step 1: try to delete a product that is already linked in OrderItems
-- (EXPECTED to fail)
DELETE FROM Products
WHERE  ProductID = 1;
-- BLOCKED BY: FOREIGN KEY fk_orderitems_product (ON DELETE RESTRICT).
-- The laptop appears in OrderItems (order 1). Deleting it would leave an
-- order line pointing to a product that no longer exists, so PostgreSQL
-- refuses. This protects the order history.
-- ERROR: update or delete on table "products" violates foreign key constraint
--        "fk_orderitems_product" on table "orderitems"
-- DETAIL: Key (productid)=(1) is still referenced from table "orderitems".   [SQLSTATE 23503]
--
-- Other options and why they were not chosen:
--   ON DELETE CASCADE  -> would silently delete the laptop from customers'
--                         past orders, corrupting sales records.
--   ON DELETE SET NULL -> would leave order lines with no product, and
--                         conflicts with ProductID being NOT NULL.
-- In a real system, a discontinued product that has been sold is usually
-- "soft-deleted" (e.g. an IsActive flag set to FALSE) instead of removed.

-- Step 2: find products that have never been ordered
SELECT p.ProductID, p.ProductName
FROM   Products p
LEFT JOIN OrderItems oi ON oi.ProductID = p.ProductID
WHERE  oi.OrderItemID IS NULL;      -- returns the USB-C Hub (ProductID 4)

-- Step 3: delete the discontinued product that has no orders (succeeds)
DELETE FROM Products
WHERE  ProductID = 4;

-- Verify the delete
SELECT * FROM Products;   -- USB-C Hub is gone; products 1-3 remain