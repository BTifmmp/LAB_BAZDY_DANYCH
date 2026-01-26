-- ======================================================
-- KONFIGURACJA TESTU - ZDEFINIOWANE ID
-- ======================================================

DECLARE @TestCategoryID      INT = 40000;
DECLARE @TestProductID       INT = 40000;
DECLARE @TestCustomerID      INT = 40000;
DECLARE @TestOrderID         INT = 40000;
DECLARE @TestPaymentID       INT = 40000;
DECLARE @TestLineID          INT = 40000;
DECLARE @TestProdOrderID     INT = 40000;
DECLARE @ExistingProdOrderID INT = 40001;
DECLARE @TestHistoryID       INT = 40000;
DECLARE @ProductionLineTimeAllocationID INT =40000;

BEGIN TRANSACTION
BEGIN TRY

SET IDENTITY_INSERT ProductionLineTimeAllocation OFF

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
    (@ProductionLineTimeAllocationID+3,@TestLineID+1, 200,dateadd(day,1,getdate()),'8:00','20:00'),
(@ProductionLineTimeAllocationID+4,@TestLineID, 200,dateadd(day,2,getdate()),'8:00','20:00'),
(@ProductionLineTimeAllocationID+5,@TestLineID+1, 200,dateadd(day,2,getdate()),'8:00','20:00'),
(@ProductionLineTimeAllocationID+6,@TestLineID, 200,dateadd(day,3,getdate()),'8:00','20:00'),
(@ProductionLineTimeAllocationID+7,@TestLineID+1, 200,dateadd(day,3,getdate()),'8:00','20:00'),
(@ProductionLineTimeAllocationID+8,@TestLineID, 200,dateadd(day,4,getdate()),'8:00','20:00'),
(@ProductionLineTimeAllocationID+9,@TestLineID+1, 200,dateadd(day,4,getdate()),'8:00','20:00')
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

declare @dateFarAhead date='2026-12-12'
declare @secondProduct int = @TestProductID+1
declare @toDelete int

EXEC CreateNewProductionOrder @Deadline = @dateFarAhead, @Quantity = 10, @ProductID = @TestProductID
EXEC CreateNewProductionOrder @Deadline = @dateFarAhead, @Quantity = 20, @ProductID = @TestProductID

select TOP 1 @toDelete=ProductionOrderID
from ProductionOrder
order by ProductionOrderID desc

EXEC CreateNewProductionOrder @Deadline = @dateFarAhead, @Quantity = 30, @ProductID = @TestProductID
EXEC CreateNewProductionOrder @Deadline = @dateFarAhead, @Quantity = 5, @ProductID = @secondProduct
EXEC CreateNewProductionOrder @Deadline = @dateFarAhead, @Quantity = 10, @ProductID = @secondProduct


-- Poczatkowy stan
-- Zapytanie 1
select * from ProductionOrder
where AddedDate>=cast(getdate() as date)

-- usuwanie zamowienia produkcyjnego powoduje zmienienie statusu na 4 i przesuwa inne zamowineia na jego miejsce
delete from ProductionOrder
    where ProductionOrderID=@toDelete

--  Stan po usunieciu
-- Zapytanie 2
select * from ProductionOrder
where AddedDate>=cast(getdate() as date)
    order by ProductionLineId,PlannedStartDate


-- Usuwanie pewnej ilości produktów z zamówień produkcyjnych.
-- Usuwa całe zamówienia produkcyjne, chyba że ilośc do usunięcia jest mniejsza od ilości do wyprodukowania w tym zamówieniu
-- Usunięcie -> zmiana statusu na 4 (anulowane)
EXEC usp_RemoveProductQuantityFromOrders @ProductId = @TestProductID, @QuantityToRemove = 40, @ProductionLineId = @TestLineID


-- Zapytanie 3
select * from ProductionOrder
where AddedDate>=cast(getdate() as date)
    order by ProductionLineId,PlannedStartDate

end try
begin catch
    ROLLBACK TRANSACTION;
    THROW
end catch
IF @@TRANCOUNT>0
    ROLLBACK TRANSACTION;



PRINT N'--- TEST ZAKOŃCZONY ---';
