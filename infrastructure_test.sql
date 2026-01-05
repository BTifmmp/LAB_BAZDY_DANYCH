-- ======================================================
-- KONFIGURACJA TESTU - ZDEFINIOWANE ID
-- ======================================================
DECLARE @TestCategoryID      INT = 20000;
DECLARE @TestProductID       INT = 20000;
DECLARE @TestCustomerID      INT = 20000;
DECLARE @TestOrderID         INT = 20000;
DECLARE @TestPaymentID       INT = 20000;
DECLARE @TestLineID          INT = 20000;
DECLARE @TestProdOrderID     INT = 20000;
DECLARE @ExistingProdOrderID INT = 20001;
DECLARE @TestHistoryID       INT = 20000;
DECLARE @ProductionLineTimeAllocationID INT =20000;

DELETE FROM ProductReservation WHERE ProductId = @TestCategoryID;
DELETE FROM Payments WHERE OrderID = @TestPaymentID;
DELETE FROM Orders where OrderID=@TestOrderID;
DELETE FROM Customers WHERE CustomerID = @TestCustomerID;
DELETE FROM ProductionHistory WHERE ProductionHistoryId = @TestHistoryID;
DELETE FROM ProductionOrder WHERE ProductionOrderID = @TestProdOrderID;
DELETE FROM ProductionOrder WHERE ProductionOrderID = @ExistingProdOrderID;
DELETE FROM ProductionLine WHERE ProductionLineId = @TestLineID;
DELETE FROM ProductionLine WHERE ProductionLineId = @TestLineID+1;
DELETE FROM ProductionLineTimeAllocation WHERE ProductionLineTimeAllocationID = @ProductionLineTimeAllocationID+1;
DELETE FROM ProductionLineTimeAllocation WHERE ProductionLineTimeAllocationID = @ProductionLineTimeAllocationID+2;
DELETE FROM ProductionLineTimeAllocation WHERE ProductionLineTimeAllocationID = @ProductionLineTimeAllocationID+3;
DELETE FROM ProductionLineTimeAllocation WHERE ProductionLineTimeAllocationID = @ProductionLineTimeAllocationID+4;
DELETE FROM Products WHERE ProductId = @TestProductID;
DELETE FROM Products WHERE ProductId = @TestProductID+1;
DELETE FROM ProductCategories WHERE ProductCategoryID = @TestCategoryID;
DELETE FROM ProductCategories WHERE ProductCategoryID = @TestCategoryID+1;

-- 1. Dodanie Kategorii i Produktu
SET IDENTITY_INSERT ProductCategories ON;
INSERT INTO ProductCategories (ProductCategoryID, CategoryName) VALUES (@TestCategoryID, 'Elektronika Testowa'),(@TestCategoryID+1,'Meble testowe');
SET IDENTITY_INSERT ProductCategories OFF;

SET IDENTITY_INSERT Products ON;
INSERT INTO Products (ProductId, ProductCategoryId, ProductName, EstimatedProductionTime, CurrentSellPrice, CurrentProductionCost, Available,MinimalQuantity)
VALUES (@TestProductID, @TestCategoryID, 'Smartfon Testowy', 1.0, 2000.00, 1200.00, 10,20),
       (@TestProductID+1,@TestCategoryID+1,'Kanapa testowa',30.0,5000.0,2500,10,2);
SET IDENTITY_INSERT Products OFF;

-- 2. Dodanie Klienta
SET IDENTITY_INSERT Customers ON;
INSERT INTO Customers (CustomerID, CustomerType, CustomerName, Address,Country,City,Region,PostalCode,Phone)
VALUES (@TestCustomerID, 1, 'Jan Testowy', 'ul. Testowa 1', 'Polska', N'Kraków', N'Małopolska', '31-000','000000000');
SET IDENTITY_INSERT Customers OFF;


-- 3. Dodanie Infrastruktury Produkcyjnej (Pod historię)
SET IDENTITY_INSERT ProductionLine ON;
INSERT INTO ProductionLine (ProductionLineId, ProductCategoryId) VALUES (@TestLineID, @TestCategoryID),(@TestLineID+1,@TestCategoryID+1);
SET IDENTITY_INSERT ProductionLine OFF;

SET IDENTITY_INSERT ProductionLineTimeAllocation ON;
INSERT INTO ProductionLineTimeAllocation (ProductionLineTimeAllocationID,ProductionLineId, HoursTotal, Date, ShiftStart, ShiftEnd)
VALUES
    (@ProductionLineTimeAllocationID,@TestLineID, 200,getdate(),'8:00','20:00'),
    (@ProductionLineTimeAllocationID+1,@TestLineID, 200,dateadd(day,1,getdate()),'8:00','20:00'),
    (@ProductionLineTimeAllocationID+2,@TestLineID+1, 200,getdate(),'8:00','20:00'),
    (@ProductionLineTimeAllocationID+3,@TestLineID+1, 200,dateadd(day,1,getdate()),'8:00','20:00')
SET IDENTITY_INSERT ProductionLineTimeAllocation OFF;


-- 4. Dodanie typu tablicowego do dodawania zamówień klienta
IF NOT EXISTS (SELECT * FROM sys.types WHERE name = 'OrderItem' AND is_table_type = 1)
BEGIN
    CREATE TYPE OrderItem AS TABLE (
        ProductID INT PRIMARY KEY,
        Quantity INT,
        Discount DECIMAL(5, 2)
    );
END

-- 5. Testy procedur i Trigerrów

    DECLARE @Items OrderItem
    DECLARE @Deadline date = dateadd(day,20,cast(getdate() as date))
    
-- Dodaj nowe zamówienie produkcyjne, które uzupełni braki w magazynie
    EXEC CreateNewProductionOrder @Deadline=@Deadline,@Quantity = 10,@ProductID = @TestProductID
    SET @ExistingProdOrderID=@@IDENTITY


-- Stwórz zamówienie klienta

    insert into @Items(ProductID,Quantity,Discount)
    values
        (@TestProductID,25,0),
        (@TestProductID+1,5,0)

    EXEC createCustomerOrder @CustomerID = @TestCustomerID,@Items = @Items,@Deadline = @Deadline

    SET @TestOrderID=(select TOP 1 OrderID from Orders where OrderDate>=cast(getdate() as date) order by OrderID DESC)


-- Stworzone zostało zamówienie o Statusie 1 (nieoplacone)
-- Procedura createCustomerOrder sprawdziła tylko możliwość produkcji w podanym terminie oraz dodała wpis do Orders oraz OrderDetails
--  1 Zapytanie
    select * from Orders
    where OrderID=@TestOrderID

-- 2 Zapytanie
    select * from OrderDetails
    where OrderID=@TestOrderID

-- Nie zostanie stworzone żadne nowe production mimo tego, że brakuje produktów
-- 3 Zapytanie
    select * from ProductionOrder
    where AddedDate>=cast(getdate() as date)

-- 4 Zapytanie
    SELECT * FROM Products
    WHERE ProductId >= @TestProductID

-- Sprawdź koszt zamówienia
-- 5 Zapytanie
    select dbo.CalculateOrderValue_FN(@TestOrderID)

-- Oplac zamówienie
    SET IDENTITY_INSERT Payments ON;
    INSERT into Payments(PaymentID,ORDERID, AMOUNT, PAYMENTMETHOD, TRANSACTIONDATE)
    VALUES (@TestPaymentID,@TestOrderID,dbo.CalculateOrderValue_FN (@TestOrderID),'Karta',getdate())
    SET IDENTITY_INSERT Payments OFF;

    SET @TestProdOrderID=@@IDENTITY
-- Opłacenie zamówienia zmieniło jego status na 2 (opłacone)
-- Wywołał się też trigger odpowiedzialny za rezerwację produktów. Ponieważ Available było mniejsze od potrzebnej ilości stworzyło się też zamówienie produkcyjne
-- 6 Zapytanie

    SELECT * FROM Products
    WHERE ProductId >= @TestProductID

-- 7 Zapytanie
    select * from Orders
    where OrderID=@TestOrderID
-- 8 Zapytanie

    select * from ProductionOrder
    where AddedDate>=cast(getdate() as date)

-- Dodano rekordy do ProductReservation, które określają produkty zarezerwowane przez to zamówienie
-- 9 Zapytanie
    select * from ProductReservation
    where OrderID=@TestOrderID

-- Zakończ zamówienie produkcyjne
-- Dodajac rekord do ProductionHistory wywoła się trigger który zwiększy ilość Available w produktach.
-- Sprawdzone też zostanie możliwość wysłania zamówienia
SET IDENTITY_INSERT ProductionHistory ON;
INSERT INTO ProductionHistory (ProductionHistoryId, ProductionOrderID, ProductId, ProducedDate, ProductionCost, Quantity, RejectedQuantity)
VALUES (@TestHistoryID, @ExistingProdOrderID, @TestProductID, GETDATE(), 1000.00, 10, 0)
INSERT INTO ProductionHistory(ProductionHistoryId,ProductionOrderID, ProductId, ProducedDate, ProductionCost, Quantity, RejectedQuantity)
VALUES (@TestHistoryID+1, @TestProdOrderID, @TestProductID, GETDATE(), 1000.00, 5, 0);
SET IDENTITY_INSERT ProductionHistory OFF;

-- Status zamówienia został zmieniony na 3 (Gotowe do wysyłki)
-- 10 Zapytanie
    select * from Orders
    where OrderID=@TestOrderID

-- Odjęto zarezerwowaną ilość sztuk przez wywołanie triggera który zaregaował na zmiane statusu na 3 w zamówieniu
-- 11 Zapytanie
    SELECT * FROM Products
    WHERE ProductId >= @TestProductID

-- Ponieważ zamówienie jest gotowe do wysyłki usunięto rezerwacje produktów z ProductReservation
-- 12 Zapytanie
    select * from ProductReservation
    where OrderID=@TestOrderID

UPDATE Products
set Available=15
where ProductId=@TestProductID
DELETE FROM Orders where OrderID = @TestOrderID
DELETE FROM Payments WHERE OrderID = @TestOrderID;
DELETE FROM Customers WHERE CustomerID = @TestCustomerID;
DELETE FROM ProductionHistory WHERE ProductionHistoryId = @TestHistoryID;
DELETE FROM ProductionHistory WHERE ProductionHistoryId = @TestHistoryID+1;
DELETE FROM ProductionOrder WHERE ProductionOrderID = @TestProdOrderID;
DELETE FROM ProductionOrder WHERE ProductionOrderID = @ExistingProdOrderID;
DELETE FROM ProductionLine WHERE ProductionLineId = @TestLineID;
DELETE FROM ProductionLine WHERE ProductionLineId = @TestLineID+1;
DELETE FROM Products WHERE ProductId = @TestProductID;
DELETE FROM Products WHERE ProductId = @TestProductID+1;
DELETE FROM ProductCategories WHERE ProductCategoryID = @TestCategoryID;
DELETE FROM ProductCategories WHERE ProductCategoryID = @TestCategoryID+1;
DELETE FROM ProductionLineTimeAllocation WHERE ProductionLineTimeAllocationID = @ProductionLineTimeAllocationID+1;
DELETE FROM ProductionLineTimeAllocation WHERE ProductionLineTimeAllocationID = @ProductionLineTimeAllocationID+2;
DELETE FROM ProductionLineTimeAllocation WHERE ProductionLineTimeAllocationID = @ProductionLineTimeAllocationID+3;
DELETE FROM ProductionLineTimeAllocation WHERE ProductionLineTimeAllocationID = @ProductionLineTimeAllocationID+4;


PRINT N'--- TEST ZAKOŃCZONY, DANE USUNIĘTE ---';

