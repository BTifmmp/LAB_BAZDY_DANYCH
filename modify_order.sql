-- ======================================================
-- KONFIGURACJA TESTU - ZDEFINIOWANE ID
-- ======================================================

BEGIN TRANSACTION
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

set identity_insert ProductionHistory off;

-- 1. Dodanie Kategorii i Produktu
SET IDENTITY_INSERT ProductCategories ON;
INSERT INTO ProductCategories (ProductCategoryID, CategoryName) VALUES (@TestCategoryID, 'Elektronika Testowa'),(@TestCategoryID+1,'Meble testowe');
SET IDENTITY_INSERT ProductCategories OFF;



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

SET IDENTITY_INSERT Products ON;
INSERT INTO Products (ProductId, ProductCategoryId, ProductName, EstimatedProductionTime, CurrentSellPrice, CurrentProductionCost, Available,MinimalQuantity)
VALUES (@TestProductID, @TestCategoryID, 'Smartfon Testowy', 1.0, 2000.00, 1200.00, 10,20),
       (@TestProductID+1,@TestCategoryID+1,'Kanapa testowa',30.0,5000.0,2500,10,2);
SET IDENTITY_INSERT Products OFF;

set @ExistingProdOrderID = @@identity


-- Ponieważ dodajemy produkt, którego Available < MinimalQuantity stworzy się zamówienie produkcyjne
-- Zapytanie 1
select * from ProductionOrder
where ProductionOrderID=@ExistingProdOrderID




-- 5. Testy procedur i Trigerrów

    DECLARE @Items OrderItem
    DECLARE @Deadline date = dateadd(day,20,cast(getdate() as date))




-- Stwórz zamówienie klienta

    insert into @Items(ProductID,Quantity,Discount)
    values
        (@TestProductID,25,0),
        (@TestProductID+1,5,0)

    EXEC createCustomerOrder @CustomerID = @TestCustomerID,@Items = @Items,@Deadline = @Deadline

    SET @TestOrderID=(select TOP 1 OrderID from Orders where OrderDate>=cast(getdate() as date) order by OrderID DESC)


-- Stworzone zostało zamówienie o Statusie 1 (nieoplacone)
-- Procedura createCustomerOrder sprawdziła tylko możliwość produkcji w podanym terminie oraz dodała wpis do Orders oraz OrderDetails


-- Oplac zamówienie
    SET IDENTITY_INSERT Payments ON;
    INSERT into Payments(PaymentID,ORDERID, AMOUNT, PAYMENTMETHOD, TRANSACTIONDATE)
    VALUES (@TestPaymentID,@TestOrderID,dbo.CalculateOrderValue_FN (@TestOrderID),'Karta',getdate())
    SET IDENTITY_INSERT Payments OFF;

    select TOP 1 @TestProdOrderID=ProductionOrderID from ProductionOrder order by ProductionOrderID DESC
-- Opłacenie zamówienia zmieniło jego status na 2 (opłacone)
-- Wywołał się też trigger odpowiedzialny za rezerwację produktów. Ponieważ Available było mniejsze od potrzebnej ilości stworzyło się też zamówienie produkcyjne



-- Sytuacja, że klient zmienił zamówienie z 25 sztuk na 15
EXEC UpdateOrderProductQuantity @OrderID = @TestOrderID, @ProductID = @TestProductID, @NewQuantity = 15


-- Poniewaz jest to jedyne zamowienie ilosc sztuk potrzebnych do wyprodukowania zostanie zmniejszona
-- Skorygowany zostanie też czas potrzebny na wyprodukowanie
-- 1 zapytanie

select * from ProductionOrder
where ProductionOrderID in (@ExistingProdOrderID,@TestProdOrderID)

-- Ilość produkowanych produktow zostanie zmniejszona
-- 2 zapytanie
select * from ProductReservation
where OrderID=@TestOrderID

-- Ilośc zarezerwowanych sztuk zostanie zmniejszona
-- 3 zapytanie

select * from Products
where ProductId in (@TestProductID,@TestProductID+1)

-- Zmniejszona liczba produktow w OrderDetails
-- 4 zapytanie
select * from OrderDetails
where OrderID=@TestOrderID


-- Sytuacja, że klient zmienił zamówienie z 15 sztuk na 40
EXEC UpdateOrderProductQuantity @OrderID = @TestOrderID, @ProductID = @TestProductID, @NewQuantity = 40

-- Poniewaz jest to jedyne zamowienie ilosc sztuk potrzebnych do wyprodukowania zostanie zwiekoszna
-- Skorygowany zostanie też czas potrzebny na wyprodukowanie
-- 5 zapytanie

select * from ProductionOrder
where ProductionOrderID>=@ExistingProdOrderID
-- Ilość produkowanych produktow zostanie zwiekoszna
-- 6 zapytanie
select * from ProductReservation
where OrderID=@TestOrderID

-- Ilośc zarezerwowanych sztuk zostanie zwiekszona
-- 7 zapytanie

select * from Products
where ProductId in (@TestProductID,@TestProductID+1)

-- Zwiekszona liczba w OrderDetails
-- 8 zapytanie
select * from OrderDetails
where OrderID=@TestOrderID

-- Klient całkowici anulował zamówienie
DECLARE @TEMP int = @TestProductID+1
exec CancelFullOrder @TestOrderID

-- usuniete zostana wszystkie zamowienia produkcyjne
-- 9 zapytanie
select * from ProductionOrder
where ProductionOrderID>=@ExistingProdOrderID

-- usuniete zostana zarezerwowane produkty z product reservation
-- 10 zapytanie
select * from ProductReservation
where OrderID=@TestOrderID

-- Ilosc zarezerwowanych sztuk zostanie zmniejszona
-- 1 zapytanie

select * from Products
where ProductId in (@TestProductID,@TestProductID+1)


-- 21 zapytanie
select * from Orders
where OrderID=@TestOrderID


ROLLBACK TRANSACTION

PRINT N'--- TEST ZAKOŃCZONY ---';
