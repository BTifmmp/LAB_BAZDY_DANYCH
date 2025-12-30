-- ======================================================
-- KONFIGURACJA TESTU - ZDEFINIOWANE ID
-- ======================================================
DECLARE @TestCategoryID INT = 20000;
DECLARE @TestProductID  INT = 20000;
DECLARE @TestCustomerID INT = 20000;
DECLARE @TestOrderID    INT = 20000;
DECLARE @TestLineID     INT = 20000;
DECLARE @TestProdOrderID INT = 20000;
DECLARE @TestHistoryID  INT = 20000;

DELETE FROM ProductReservation WHERE ProductId = @TestCategoryID;
DELETE FROM Payments WHERE OrderID = @TestOrderID;
DELETE FROM OrderDetails WHERE OrderID = @TestOrderID;
DELETE FROM Orders WHERE OrderID = @TestOrderID;
DELETE FROM Customers WHERE CustomerID = @TestCustomerID;
DELETE FROM ProductionHistory WHERE ProductionHistoryId = @TestHistoryID;
DELETE FROM ProductionOrder WHERE ProductionOrderID = @TestProdOrderID;
DELETE FROM ProductionLine WHERE ProductionLineId = @TestLineID;
DELETE FROM Products WHERE ProductId = @TestProductID;
DELETE FROM ProductCategories WHERE ProductCategoryID = @TestCategoryID;

-- 1. Dodanie Kategorii i Produktu
SET IDENTITY_INSERT ProductCategories ON;
INSERT INTO ProductCategories (ProductCategoryID, CategoryName) VALUES (@TestCategoryID, 'Elektronika Testowa');
SET IDENTITY_INSERT ProductCategories OFF;

SET IDENTITY_INSERT Products ON;
INSERT INTO Products (ProductId, ProductCategoryId, ProductName, EstimatedProductionTime, CurrentSellPrice, CurrentProductionCost, MinimalQuantity)
VALUES (@TestProductID, @TestCategoryID, 'Smartfon Testowy', 1.0, 2000.00, 1200.00, 10);
SET IDENTITY_INSERT Products OFF;

-- 2. Dodanie Klienta i Zamówienia (Trigger Test)
SET IDENTITY_INSERT Customers ON;
INSERT INTO Customers (CustomerID, CustomerType, CustomerName, City) VALUES (@TestCustomerID, 1, 'Jan Testowy', 'Kraków');
SET IDENTITY_INSERT Customers OFF;



SET IDENTITY_INSERT Orders ON;
INSERT INTO Orders (OrderID, CustomerID, Status, ShipAddress, ShipCountry, ShipCity, ShipRegion, ShipPostalCode, OrderDate)
VALUES (@TestOrderID, @TestCustomerID, 1, 'ul. Testowa 1', 'Polska', 'Kraków', 'Małopolska', '31-000', GETDATE());
SET IDENTITY_INSERT Orders OFF;

INSERT INTO OrderDetails (OrderID, ProductId, Quantity, UnitPrice, Discount)
VALUES (@TestOrderID, @TestProductID, 1, 2000.00, 0);

-- 3. Dodanie Infrastruktury Produkcyjnej (Pod historię)
SET IDENTITY_INSERT ProductionLine ON;
INSERT INTO ProductionLine (ProductionLineId, ProductCategoryId) VALUES (@TestLineID, @TestCategoryID);
SET IDENTITY_INSERT ProductionLine OFF;

SET IDENTITY_INSERT ProductionOrder ON;
INSERT INTO ProductionOrder (ProductionOrderID, ProductionLineId, ProductionOrderStatus, ProductId, Quantity, AddedDate, PlannedStartDate, PlannedEndDate)
VALUES (@TestProdOrderID, @TestLineID, 1, @TestProductID, 10, GETDATE(), GETDATE(), DATEADD(day, 1, GETDATE()));
SET IDENTITY_INSERT ProductionOrder OFF;

SELECT * FROM Products
WHERE ProductId = @TestProductID

-- 4. Dodanie Historii Produkcji
SET IDENTITY_INSERT ProductionHistory ON;
INSERT INTO ProductionHistory (ProductionHistoryId, ProductionOrderID, ProductId, ProducedDate, ProductionCost, Quantity, RejectedQuantity)
VALUES (@TestHistoryID, @TestProdOrderID, @TestProductID, GETDATE(), 1000.00, 10, 0);
SET IDENTITY_INSERT ProductionHistory OFF;

SELECT * FROM Products
WHERE ProductId = @TestProductID

-- ======================================================
-- URUCHOMIENIE TESTU TRIGGERA I PODGLĄD DANYCH
-- ======================================================

SELECT * FROM ProductionHistory WHERE ProductionHistoryId = @TestHistoryID;

INSERT INTO Payments (OrderID, Amount, PaymentMethod, TransactionDate)
VALUES (@TestOrderID, 500.00, 'Karta', GETDATE());

SELECT o.OrderID, os.OrderStatusName, (SELECT SUM(Amount) FROM Payments WHERE OrderID = o.OrderID) as Wplacono
FROM Orders o JOIN OrderStatus os ON o.Status = os.OrderStatusID
WHERE o.OrderID = @TestOrderID;

SELECT * FROM ProductReservation
WHERE ProductId = @TestProductID

INSERT INTO Payments (OrderID, Amount, PaymentMethod, TransactionDate)
VALUES (@TestOrderID, 1500.00, 'Karta', GETDATE());

SELECT o.OrderID, os.OrderStatusName, (SELECT SUM(Amount) FROM Payments WHERE OrderID = o.OrderID) as Wplacono
FROM Orders o JOIN OrderStatus os ON o.Status = os.OrderStatusID
WHERE o.OrderID = @TestOrderID;

SELECT * FROM ProductReservation
WHERE ProductId = @TestProductID

SELECT * FROM Orders
WHERE OrderId = @TestOrderID

SELECT * FROM Products
WHERE ProductId = @TestProductID


-- ======================================================
-- CZYSZCZENIE (Kolejność odwrócona ze względu na FK)
-- ======================================================
DELETE FROM Payments WHERE OrderID = @TestOrderID;
DELETE FROM OrderDetails WHERE OrderID = @TestOrderID;
DELETE FROM Orders WHERE OrderID = @TestOrderID;
DELETE FROM Customers WHERE CustomerID = @TestCustomerID;
DELETE FROM ProductionHistory WHERE ProductionHistoryId = @TestHistoryID;
DELETE FROM ProductionOrder WHERE ProductionOrderID = @TestProdOrderID;
DELETE FROM ProductionLine WHERE ProductionLineId = @TestLineID;
DELETE FROM Products WHERE ProductId = @TestProductID;
DELETE FROM ProductCategories WHERE ProductCategoryID = @TestCategoryID;
DELETE FROM ProductReservation WHERE ProductId = @TestCategoryID;

PRINT '--- TEST ZAKOŃCZONY, DANE USUNIĘTE ---';