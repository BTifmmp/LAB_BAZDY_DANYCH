-- Created by Redgate Data Modeler (https://datamodeler.redgate-platform.com)
-- Last modification date: 2025-12-15 21:27:34.621

-- tables
-- Table: CustomerType
CREATE TABLE CustomerType (
    TypeID int  NOT NULL IDENTITY(1, 1),
    TypeName varchar(50)  NOT NULL,
    CONSTRAINT CustomerType_pk PRIMARY KEY  (TypeID)
);

-- Table: Customers
CREATE TABLE Customers (
    CustomerID int  NOT NULL IDENTITY(1, 1),
    CustomerType int  NOT NULL,
    CustomerName varchar(50)  NOT NULL,
    Address varchar(50)  NULL,
    Country varchar(50)  NULL,
    City varchar(50)  NULL,
    Region varchar(50)  NULL,
    PostalCode varchar(20)  NULL,
    Phone varchar(20)  NULL,
    CONSTRAINT customerID PRIMARY KEY  (CustomerID)
);

-- Table: OrderDetails
CREATE TABLE OrderDetails (
    OrderID int  NOT NULL,
    ProductId int  NOT NULL,
    Quantity int  NOT NULL CHECK (Quantity>0),
    UnitPrice money  NOT NULL CHECK (UnitPrice>0),
    Discount decimal(5,2)  NOT NULL DEFAULT 0 CHECK (Discount>=0 AND Discount<=1),
    CONSTRAINT OrderDetails_pk PRIMARY KEY  (OrderID,ProductId)
);

-- Table: OrderStatus
CREATE TABLE OrderStatus (
    OrderStatusID int  NOT NULL IDENTITY(1, 1),
    OrderStatusName varchar(20)  NOT NULL,
    CONSTRAINT OrderStatus_pk PRIMARY KEY  (OrderStatusID)
);

-- Table: Orders
CREATE TABLE Orders (
    OrderID int  NOT NULL IDENTITY(1, 1),
    CustomerID int  NOT NULL,
    Status int  NOT NULL,
    ShipAddress varchar(50)  NOT NULL,
    ShipCountry varchar(50)  NOT NULL,
    ShipCity varchar(50)  NOT NULL,
    ShipRegion varchar(50)  NOT NULL,
    ShipPostalCode varchar(10)  NOT NULL,
    OrderDate date  NOT NULL,
    CompletionDate date  NULL,
    ShipDate date  NULL,
    CONSTRAINT CHK_DATE CHECK ((CompletionDate is NULL OR OrderDate<=CompletionDate )  AND ( ShipDate is NULL OR CompletionDate<=ShipDate )),
    CONSTRAINT Orders_pk PRIMARY KEY  (OrderID)
);

-- Table: Parts
CREATE TABLE Parts (
    PartId int  NOT NULL IDENTITY(1, 1),
    PartCategoryId int  NOT NULL,
    PartName varchar(50)  NOT NULL,
    PartPrice money  NOT NULL CHECK (PartPrice>0),
    CONSTRAINT Parts_pk PRIMARY KEY  (PartId)
);

-- Table: PartsCategories
CREATE TABLE PartsCategories (
    PartCategoryId int  NOT NULL IDENTITY(1, 1),
    CategoryName varchar(50)  NOT NULL,
    CONSTRAINT PartsCategories_pk PRIMARY KEY  (PartCategoryId)
);

-- Table: Payments
CREATE TABLE Payments (
    PaymentID int  NOT NULL IDENTITY(1, 1),
    OrderID int  NOT NULL,
    Amount money  NOT NULL CHECK (Amount>=0),
    PaymentMethod varchar(20)  NOT NULL,
    TransactionDate date  NOT NULL,
    CONSTRAINT Payments_pk PRIMARY KEY  (PaymentID)
);

-- Table: ProductCategories
CREATE TABLE ProductCategories (
    ProductCategoryID int  NOT NULL IDENTITY(1, 1),
    CategoryName varchar(50)  NOT NULL,
    CONSTRAINT ProductCategories_pk PRIMARY KEY  (ProductCategoryID)
);

-- Table: ProductReservation
CREATE TABLE ProductReservation (
    ProductID int  NOT NULL,
    OrderID int  NOT NULL,
    Quantity int  NOT NULL CHECK (Quantity>0),
    CONSTRAINT ProductReservation_pk PRIMARY KEY  (ProductID,OrderID)
);

-- Table: ProductionHistory
CREATE TABLE ProductionHistory (
    ProductionHistoryId int  NOT NULL IDENTITY(1, 1),
    ProductionOrderID int  NOT NULL,
    ProductId int  NOT NULL,
    ProducedDate date  NOT NULL,
    ProductionCost money  NOT NULL CHECK (ProductionCost>0),
    Quantity int  NOT NULL CHECK (Quantity>0),
    RejectedQuantity int  NOT NULL CHECK (RejectedQuantity>=0),
    CONSTRAINT ProductionHistory_pk PRIMARY KEY  (ProductionHistoryId)
);

-- Table: ProductionLine
CREATE TABLE ProductionLine (
    ProductionLineId int  NOT NULL IDENTITY(1, 1),
    ProductCategoryId int  NOT NULL,
    CONSTRAINT ProductionLine_pk PRIMARY KEY  (ProductionLineId)
);

-- Table: ProductionLineTimeAllocation
CREATE TABLE ProductionLineTimeAllocation (
    ProductionLineTimeAllocationID int  NOT NULL IDENTITY(1, 1),
    ProductionLineId int  NOT NULL,
    HoursTotal decimal(6,2)  NOT NULL CHECK (HoursTotal>=0),
    HoursAllocated decimal(6,2)  NOT NULL DEFAULT 0 CHECK (HoursAllocated>=0),
    Date date  NOT NULL,
    DowntimeHours int  NOT NULL DEFAULT 0 CHECK (DowntimeHours>=0),
    ShiftStart time(0)  NOT NULL,
    ShiftEnd time(0)  NOT NULL,
    CONSTRAINT ProductionLine_Date UNIQUE (ProductionLineId, Date),
    CONSTRAINT CK_hours CHECK (HoursTotal>=HoursAllocated),
    CONSTRAINT CK_Shift CHECK (ShiftStart<=ShiftEnd),
    CONSTRAINT ProductionLineTimeAllocation_pk PRIMARY KEY  (ProductionLineTimeAllocationID)
);

-- Table: ProductionOrder
CREATE TABLE ProductionOrder (
    ProductionOrderID int  NOT NULL IDENTITY(1, 1),
    ProductionLineId int  NOT NULL,
    ProductionOrderStatus int  NOT NULL,
    ProductId int  NOT NULL,
    Quantity int  NOT NULL CHECK (Quantity>0),
    QuantityProduced int  NOT NULL DEFAULT 0 CHECK (QuantityProduced>=0),
    QuantityAllocated int  NOT NULL DEFAULT 0 CHECK (QuantityAllocated>=0),
    AddedDate date  NOT NULL,
    PlannedStartDate datetime  NOT NULL,
    PlannedEndDate datetime  NOT NULL,
    StartDate datetime  NULL,
    EndDate datetime  NULL,
    CONSTRAINT CHK_AddDate CHECK (AddedDate<=PlannedStartDate),
    CONSTRAINT CHK_PlannedDates CHECK (PlannedStartDate<=PlannedEndDate),
    CONSTRAINT CHK_RealDates CHECK (EndDate is Null OR StartDate<=EndDate ),
    CONSTRAINT CHK_QuantityAllocated_Quantity CHECK (Quantity>=QuantityAllocated),
    CONSTRAINT ProductionOrder_pk PRIMARY KEY  (ProductionOrderID)
);

-- Table: ProductionOrderStatus
CREATE TABLE ProductionOrderStatus (
    ProductionOrderStatus int  NOT NULL IDENTITY(1, 1),
    Status varchar(20)  NOT NULL,
    CONSTRAINT ProductionOrderStatus_pk PRIMARY KEY  (ProductionOrderStatus)
);

-- Table: Products
CREATE TABLE Products (
    ProductId int  NOT NULL IDENTITY(1, 1),
    ProductCategoryId int  NOT NULL,
    ProductName varchar(50)  NOT NULL,
    EstimatedProductionTime decimal(4,2)  NOT NULL CHECK (EstimatedProductionTime>0),
    CurrentSellPrice money  NOT NULL CHECK (CurrentSellPrice>0),
    CurrentProductionCost money  NOT NULL CHECK (CurrentProductionCost>0),
    Available int  NOT NULL DEFAULT 0 CHECK (Available>=0),
    Reserved int  NOT NULL DEFAULT 0 CHECK (Reserved>=0),
    MinimalQuantity int  NOT NULL CHECK (MinimalQuantity>=0),
    CONSTRAINT ProductID PRIMARY KEY  (ProductId)
);

-- Table: ProductsDetails
CREATE TABLE ProductsDetails (
    ProductId int  NOT NULL,
    PartId int  NOT NULL,
    Quantity int  NOT NULL CHECK (Quantity>0),
    CONSTRAINT ProductsDetails_pk PRIMARY KEY  (ProductId,PartId)
);

-- foreign keys
-- Reference: CustomerType_Customers (table: Customers)
ALTER TABLE Customers ADD CONSTRAINT CustomerType_Customers
    FOREIGN KEY (CustomerType)
    REFERENCES CustomerType (TypeID);

-- Reference: OrderDetails_Orders (table: OrderDetails)
ALTER TABLE OrderDetails ADD CONSTRAINT OrderDetails_Orders
    FOREIGN KEY (OrderID)
    REFERENCES Orders (OrderID)
    ON DELETE  CASCADE;

-- Reference: OrderDetails_Products (table: OrderDetails)
ALTER TABLE OrderDetails ADD CONSTRAINT OrderDetails_Products
    FOREIGN KEY (ProductId)
    REFERENCES Products (ProductId);

-- Reference: OrdersReservation_Orders (table: ProductReservation)
ALTER TABLE ProductReservation ADD CONSTRAINT OrdersReservation_Orders
    FOREIGN KEY (OrderID)
    REFERENCES Orders (OrderID);

-- Reference: OrdersReservation_Products (table: ProductReservation)
ALTER TABLE ProductReservation ADD CONSTRAINT OrdersReservation_Products
    FOREIGN KEY (ProductID)
    REFERENCES Products (ProductId);

-- Reference: Orders_Customers (table: Orders)
ALTER TABLE Orders ADD CONSTRAINT Orders_Customers
    FOREIGN KEY (CustomerID)
    REFERENCES Customers (CustomerID);

-- Reference: Orders_Status (table: Orders)
ALTER TABLE Orders ADD CONSTRAINT Orders_Status
    FOREIGN KEY (Status)
    REFERENCES OrderStatus (OrderStatusID);

-- Reference: Parts_PartsCategories (table: Parts)
ALTER TABLE Parts ADD CONSTRAINT Parts_PartsCategories
    FOREIGN KEY (PartCategoryId)
    REFERENCES PartsCategories (PartCategoryId);

-- Reference: Payments_Orders (table: Payments)
ALTER TABLE Payments ADD CONSTRAINT Payments_Orders
    FOREIGN KEY (OrderID)
    REFERENCES Orders (OrderID)
    ON DELETE  CASCADE;

-- Reference: PlannedProduction_Products (table: ProductionOrder)
ALTER TABLE ProductionOrder ADD CONSTRAINT PlannedProduction_Products
    FOREIGN KEY (ProductId)
    REFERENCES Products (ProductId);

-- Reference: ProductionHistory_ProductionOrder (table: ProductionHistory)
ALTER TABLE ProductionHistory ADD CONSTRAINT ProductionHistory_ProductionOrder
    FOREIGN KEY (ProductionOrderID)
    REFERENCES ProductionOrder (ProductionOrderID);

-- Reference: ProductionHistory_Products (table: ProductionHistory)
ALTER TABLE ProductionHistory ADD CONSTRAINT ProductionHistory_Products
    FOREIGN KEY (ProductId)
    REFERENCES Products (ProductId);

-- Reference: ProductionLineTimeAllocation_ProductionLine (table: ProductionLineTimeAllocation)
ALTER TABLE ProductionLineTimeAllocation ADD CONSTRAINT ProductionLineTimeAllocation_ProductionLine
    FOREIGN KEY (ProductionLineId)
    REFERENCES ProductionLine (ProductionLineId)
    ON DELETE  CASCADE;

-- Reference: ProductionLine_ProductCategories (table: ProductionLine)
ALTER TABLE ProductionLine ADD CONSTRAINT ProductionLine_ProductCategories
    FOREIGN KEY (ProductCategoryId)
    REFERENCES ProductCategories (ProductCategoryID)
    ON DELETE  CASCADE;

-- Reference: ProductionOrder_ProductionLine (table: ProductionOrder)
ALTER TABLE ProductionOrder ADD CONSTRAINT ProductionOrder_ProductionLine
    FOREIGN KEY (ProductionLineId)
    REFERENCES ProductionLine (ProductionLineId);

-- Reference: ProductionOrder_ProductionOrderStatus (table: ProductionOrder)
ALTER TABLE ProductionOrder ADD CONSTRAINT ProductionOrder_ProductionOrderStatus
    FOREIGN KEY (ProductionOrderStatus)
    REFERENCES ProductionOrderStatus (ProductionOrderStatus);

-- Reference: ProductsDetails_Parts (table: ProductsDetails)
ALTER TABLE ProductsDetails ADD CONSTRAINT ProductsDetails_Parts
    FOREIGN KEY (PartId)
    REFERENCES Parts (PartId);

-- Reference: ProductsDetails_Products (table: ProductsDetails)
ALTER TABLE ProductsDetails ADD CONSTRAINT ProductsDetails_Products
    FOREIGN KEY (ProductId)
    REFERENCES Products (ProductId)
    ON DELETE  CASCADE;

-- Reference: Products_ProductCategories (table: Products)
ALTER TABLE Products ADD CONSTRAINT Products_ProductCategories
    FOREIGN KEY (ProductCategoryId)
    REFERENCES ProductCategories (ProductCategoryID);

-- End of file.


