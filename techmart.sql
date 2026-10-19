-- =====================================================================
-- TechMart E-commerce Database (PostgreSQL, run in pgAdmin)
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