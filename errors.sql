-- ======================================================
-- KONFIGURACJA TESTU - ZDEFINIOWANE ID
-- ======================================================

DECLARE @TestCategoryID      INT = 50000;
DECLARE @TestProductID       INT = 50000;
DECLARE @TestCustomerID      INT = 50000;
DECLARE @TestOrderID         INT = 50000;
DECLARE @TestPaymentID       INT = 50000;
DECLARE @TestLineID          INT = 50000;
DECLARE @TestProdOrderID     INT = 50000;
DECLARE @ExistingProdOrderID INT = 50001;
DECLARE @TestHistoryID       INT = 50000;
DECLARE @ProductionLineTimeAllocationID INT =40000;

set identity_insert ProductionHistory off;

begin try


BEGIN TRANSACTION

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

-- Stwórz zamówienie klienta

    DECLARE @deadline date =cast(getdate() as date)
    insert into @Items(ProductID,Quantity,Discount)
    values
        (@TestProductID,600,0),
        (@TestProductID+1,5,0)
-- Zwroci blad. Nie możemy wyrpodukować w podanym czasie
--     EXEC createCustomerOrder @CustomerID = @TestCustomerID,@Items = @Items,@Deadline = @deadline


    delete from @Items where 1=1

    insert into @Items(ProductID,Quantity,Discount)
    values
        (@TestProductID,600,0),
        (@TestProductID+2,5,0)
-- Zwroci blad. Jeden z produtow nie istnieje

--     EXEC createCustomerOrder @CustomerID = @TestCustomerID,@Items = @Items,@Deadline = @deadline

-- Zwroci błąd. Klient nie istnieje
    DECLARE @tempCustomer int = @TestCustomerID+2
--     EXEC createCustomerOrder @CustomerID = @tempCustomer,@Items = @Items,@Deadline = @deadline


SET IDENTITY_INSERT Products ON;
INSERT INTO Products (ProductId, ProductCategoryId, ProductName, EstimatedProductionTime, CurrentSellPrice, CurrentProductionCost, Available,MinimalQuantity,Removed)
VALUES (@TestProductID+3, @TestCategoryID, 'Smartfon Testowy', 1.0, 2000.00, 1200.00, 10,20,1)
SET IDENTITY_INSERT Products OFF;

delete from @Items where 1=1

    insert into @Items(ProductID,Quantity,Discount)
    values
        (@TestProductID+3,600,0)

-- Zwroci błąd. Produkt jest wycofany
    EXEC createCustomerOrder @CustomerID = @TestCustomerID,@Items = @Items,@Deadline = @deadline


end try
begin catch
    IF @@TRANCOUNT>0
        ROLLBACK TRANSACTION ;
    THROW
end catch
IF @@TRANCOUNT>0
    ROLLBACK TRANSACTION ;


PRINT N'--- TEST ZAKOŃCZONY ---';
