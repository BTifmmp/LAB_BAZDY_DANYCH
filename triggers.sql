-------------------------------------------------------------------------------------------------------------------
-- Zmiana statusu na 'Opłacone' (2), gdy suma wpłat pokryje wartość zamówienia.
-- Po dodaniu/edycji płatności sprawdza sumę kwot w tabeli Payments dla danego zamówienia. 
-- Jeśli Suma >= Wynik funkcji CalculateOrderValue_FN, status w tabeli Orders zmienia się na 2.
CREATE OR ALTER TRIGGER tr_Payments_UpdateOrderStatus
ON Payments
AFTER INSERT, UPDATE
AS
BEGIN
    -- które zostały dotknięte przez nowe/zmienione płatności
    DECLARE @AffectedOrderIds TABLE (OrderID INT PRIMARY KEY);

    -- Zbierz wszystkie ID zamówień powiązane ze wstawionymi/zmienionymi płatnościami
    INSERT INTO @AffectedOrderIds (OrderID)
    SELECT DISTINCT OrderId FROM inserted;

    -- Aktualizacja statusu w tabeli Orders
    UPDATE o
    SET o.Status = 2 -- Ustawienie statusu na np. ID 2 = 'Opłacone'
    FROM Orders o
    INNER JOIN @AffectedOrderIds aoi ON o.OrderID = aoi.OrderID
    WHERE
        -- Zamówienie jest obecnie w statusie 'Nieoplaconeć' (np. ID 1)
        o.Status = 1
        AND
        -- Suma wszystkich płatności dla danego OrderID
        (
            SELECT SUM(p.Amount)
            FROM Payments p
            WHERE p.OrderId = o.OrderId
        ) >= dbo.CalculateOrderValue_FN(o.OrderId); -- Sprawdzenie, czy suma płatności >= Wartość Zamówienia
END
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Zwiększenie ilości dostępnych produktów (Available) po zakończeniu procesu produkcji.
-- Przy dodaniu wpisu do historii produkcji (INSERT), zwiększa kolumnę Available w tabeli Products. 
-- Przy usunięciu (DELETE) lub edycji (UPDATE), koryguje stan o różnicę między starymi a nowymi danymi.
CREATE OR ALTER TRIGGER trg_ProductionHistory_UpdateAvailable
ON ProductionHistory
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Obsługa nowych wpisów i aktualizacji (dodajemy nowe ilości)
    IF EXISTS (SELECT * FROM inserted)
    BEGIN
        UPDATE p
        SET p.Available = p.Available + i.Quantity
        FROM Products p
        INNER JOIN inserted i ON p.ProductId = i.ProductId;
    END

    -- 2. Obsługa usuniętych wpisów i starych wartości przy aktualizacji (odejmujemy poprzednie ilości)
    IF EXISTS (SELECT * FROM deleted)
    BEGIN
        UPDATE p
        SET p.Available = p.Available - d.Quantity
        FROM Products p
        INNER JOIN deleted d ON p.ProductId = d.ProductId;
    END
END
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Koordynacja rezerwacji i wydań towaru na podstawie zmiany statusu zamówienia.
-- 1. Jeśli Status=2 (Opłacone): Tworzy rekordy w tabeli ProductReservation (rezerwuje towar).
-- 2. Jeśli Status=3 (Do wysyłki): Odejmuje towar z Available i usuwa rezerwację.
-- 3. Jeśli Status=5 (Anulowane): Usuwa rezerwację - usuwa z tabeli ProductReservation.
CREATE OR ALTER TRIGGER trg_Orders_HandleStatusChange
ON Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(Status) RETURN;

    -- 1. SCENARIUSZ: Opłacone (2), dodajemy rezerwację
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.OrderID = d.OrderID 
               WHERE i.Status = 2 AND d.Status <> 2)
    BEGIN
        INSERT INTO ProductReservation (ProductID, OrderID, Quantity)
        SELECT 
            od.ProductId, 
            od.OrderID,
            od.Quantity
        FROM OrderDetails od
        JOIN inserted i ON od.OrderID = i.OrderID
        WHERE i.Status = 2;
        
        -- Trigger trg_ProductReservation_UpdateProductsReserved automatycznie 
        -- zwiększy teraz kolumnę Products.Reserved o tę ilość.
    END

    -- 2. Gotowe do wysyłki (3)
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.OrderID = d.OrderID 
               WHERE i.Status = 3 AND d.Status <> 3)
    BEGIN
        -- Zmniejszamy Available
        UPDATE p
        SET p.Available = p.Available - pr.Quantity
        FROM Products p
        INNER JOIN ProductReservation pr ON p.ProductId = pr.ProductID
        INNER JOIN inserted i ON pr.OrderID = i.OrderID
        WHERE i.Status = 3;

        -- Usuwamy rezerwację (Reserved w Products spadnie automatycznie przez trigger rezerwacji)
        DELETE pr FROM ProductReservation pr
        INNER JOIN inserted i ON pr.OrderID = i.OrderID
        WHERE i.Status = 3;
    END

    -- 3. Anulowane (5)
    IF EXISTS (SELECT 1 FROM inserted i WHERE i.Status = 5)
    BEGIN
        DELETE FROM ProductReservation 
        WHERE OrderID IN (SELECT OrderID FROM inserted WHERE Status = 5);
    END
END
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Utrzymuje aktualna liczby zarezerwowanych sztuk w tabeli Products.
-- Reaguje na każdą zmianę w tabeli ProductReservation. Dodaje ilości z 'inserted' (nowe rezerwacje).
-- Sprawdza czy dalej możliwa jest produkcja w terminie podanym przez klienta.
-- Odejmuje ilości z 'deleted' (koniec rezerwacji) od kolumny Products.Reserved.
CREATE   TRIGGER trg_ProductReservation_UpdateProductsReserved
ON ProductReservation
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Obsługa nowych rezerwacji lub zwiększenia ilości (INSERT/UPDATE)
    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        DECLARE @Deadline date
        
        select @Deadline=o.RequiredDate
        from inserted i
        inner join Orders o on o.OrderID=i.OrderID
        
        DECLARE @Items OrderItem

        insert into @Items(ProductID,Quantity,Discount)
        select i.ProductId,i.Quantity,od.Discount
        from inserted i
        inner join OrderDetails od on od.OrderID=i.OrderID and od.ProductId=i.ProductID
        
        begin try
            EXEC RedirectItems @Items = @Items, @Deadline = @Deadline
        end try
        begin catch
            throw
        end catch


        UPDATE p
        SET p.Reserved = ISNULL(p.Reserved, 0) + i.TotalQty
        FROM Products p
        INNER JOIN (
            SELECT ProductID, SUM(Quantity) AS TotalQty
            FROM inserted 
            GROUP BY ProductID
        ) i ON p.ProductId = i.ProductID;


        

    END

    -- 2. Obsługa usuniętych rezerwacji lub starej ilości przy zmianie (DELETE/UPDATE)
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        UPDATE p
        SET p.Reserved = ISNULL(p.Reserved, 0) - d.TotalQty
        FROM Products p
        INNER JOIN (
            SELECT ProductID, SUM(Quantity) AS TotalQty 
            FROM deleted 
            GROUP BY ProductID
        ) d ON p.ProductId = d.ProductID;
    END


END
go


-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Sprawdza czy nowa dostawa towaru pozwala na realizację oczekujących zamówień, 
-- zostanie wywolany rowniez przy tworzeniu nowego zamowienia poprzez zmiane w Products.Reserved.
-- Uzupelnia zamowienia stosujac zasade FIFO.
-- Uruchamia się przy zmianie stanu magazynowego. Przeszukuje opłacone zamówienia (Status 2) 
-- od najstarszego. Korzysta z "wirtualnego magazynu", by sprawdzić czy starczy towaru na cały koszyk. 
-- Jeśli tak, zmienia status zamówienia na 3 (co uruchamia wydanie towaru), jesli nie starczy redukuje 
-- dostepne produkty aby mniejsze nowsze zamowienia nie byly realizowane wczesniej.
CREATE OR ALTER TRIGGER trg_Products_FulfillOrders
ON Products
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(Available) OR UPDATE(Reserved)) 
        RETURN;

    -- Tabela tymczasowa do symulacji stanu "wolnego" towaru podczas pętli
    -- Chcemy wiedzieć, ile zostanie na półce po uwzględnieniu starszych zamówień
    DECLARE @VirtualStock TABLE (ProdID int PRIMARY KEY, TempAvailable int);
    
    INSERT INTO @VirtualStock (ProdID, TempAvailable)
    SELECT ProductId, Available FROM Products;

    -- Pobieramy listę wszystkich opłaconych zamówień (Status 2) w kolejce FIFO
    DECLARE @OrderID int;
    DECLARE order_cursor CURSOR LOCAL FOR
        SELECT OrderID FROM Orders 
        WHERE Status = 2 
        ORDER BY OrderDate ASC, OrderID ASC;

    OPEN order_cursor;
    FETCH NEXT FROM order_cursor INTO @OrderID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @CanFulfill bit = 1;
        -- 1. Sprawdzamy, czy dla każdej pozycji w zamówieniu starczy towaru w "Wirtualnym magazynie"
        IF EXISTS (
            SELECT 1 
            FROM OrderDetails od
            JOIN @VirtualStock vs ON od.ProductId = vs.ProdID
            WHERE od.OrderID = @OrderID AND od.Quantity > vs.TempAvailable
        )
        BEGIN
            SET @CanFulfill = 0;
        END

        

        -- 2. Aktualizujemy wirtualny magazyn (nawet jeśli nie wysyłamy, starsze zamówienie "rezerwuje" towar dla siebie)
        UPDATE vs
        SET vs.TempAvailable = vs.TempAvailable - od.Quantity
        FROM @VirtualStock vs
        JOIN OrderDetails od ON vs.ProdID = od.ProductId
        WHERE od.OrderID = @OrderID;

        -- 3. Jeśli zamówienie jest kompletne i nic go nie zablokowało -> Wysyłamy!
        IF @CanFulfill = 1
        BEGIN
            -- Zmiana na 3 odpali trigger odejmujący available
            UPDATE Orders SET Status = 3 WHERE OrderID = @OrderID;
        END

        FETCH NEXT FROM order_cursor INTO @OrderID;
    END

    CLOSE order_cursor;
    DEALLOCATE order_cursor;
END
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE TRIGGER tr_ProductionHistory_UpdateProductionOrderDates
ON ProductionHistory
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sourceOrderID INT;
    DECLARE @timeToPushMinutes INT;
    DECLARE @productionLineID INT;
    DECLARE @newEndDateOfFirstOrder DATETIME;

    SELECT TOP 1
        @sourceOrderID = i.ProductionOrderID,
        @productionLineID = po.ProductionLineId,
        -- Obliczamy ile minut dodatkowo musi pracować linia
        @timeToPushMinutes = CAST(i.RejectedQuantity * p.EstimatedProductionTime * 60 AS INT)
    FROM inserted AS i
    INNER JOIN ProductionOrder AS po ON i.ProductionOrderID = po.ProductionOrderID
    INNER JOIN Products AS p ON po.ProductId = p.ProductId
    WHERE i.RejectedQuantity > 0
    ORDER BY i.ProductionHistoryID; 

    IF @sourceOrderID IS NULL RETURN;



    DECLARE @currentEnd DATETIME = (SELECT PlannedEndDate FROM ProductionOrder WHERE ProductionOrderID = @sourceOrderID);

    SET @newEndDateOfFirstOrder = dbo.AddProductionTime(@currentEnd, @timeToPushMinutes, @productionLineID);

    UPDATE ProductionOrder
    SET PlannedEndDate = @newEndDateOfFirstOrder
    WHERE ProductionOrderID = @sourceOrderID;

    -- 3. KURSOR: Przesuwamy wszystkie kolejne zamówienia
    EXEC dbo.usp_RescheduleProductionLine @ProductionLineId = @productionLineID, @AnchorDate = @newEndDateOfFirstOrder, @ExcludedOrderId=@sourceOrderID 
END
go

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE trigger moveProductionOrders
on ProductionOrder
instead of delete
AS
    begin

        DECLARE @anchor datetime
        DECLARE @ProductioOrderID int
        

        DECLARE @time decimal(6,2)
        DECLARE @productionLineID int

        select TOP 1 
               @anchor=PlannedStartDate,
               @productionLineID=ProductionLineId,
               @time=Quantity*EstimatedProductionTime,
               @ProductioOrderID=ProductionOrderID
        FROM deleted
        INNER JOIN Products
        ON deleted.ProductId=Products.ProductId
        ORDER BY PlannedStartDate;


       EXEC dbo.usp_RescheduleProductionLine @ProductionLineId = @productionLineID, @AnchorDate = @anchor, @ExcludedOrderId = @ProductioOrderID


        EXEC dbo.usp_ReduceAllocatedHoursFromEnd @ProductionLineId = @productionLineID, @HoursToReduce = @time

        UPDATE ProductionOrder
        SET ProductionOrderStatus=4
        WHERE ProductionOrderID IN (SELECT ProductionOrderID FROM deleted )
END
go

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE   TRIGGER tr_MoveOrdersOnQuantityChange
ON ProductionOrder
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Reagujemy tylko jeśli zmieniła się ilość
    IF NOT UPDATE(Quantity) RETURN;

    DECLARE @changedOrderID INT;
    DECLARE @productionLineID INT;
    DECLARE @newQuantity INT;
    DECLARE @newStart DATETIME;
    DECLARE @newEnd DATETIME;

    -- Pobieramy dane zamówienia, którego ilość się zmieniła
    SELECT TOP 1
        @changedOrderID = i.ProductionOrderId,
        @productionLineID = i.ProductionLineId,
        @newQuantity = i.Quantity,
        @newStart = i.PlannedStartDate
    FROM inserted i;

    -- 1. Przeliczamy nowy koniec dla tego zamówienia
    DECLARE @minutesNeeded INT;
    SELECT @minutesNeeded = CAST(@newQuantity * p.EstimatedProductionTime * 60 AS INT)
    FROM Products p WHERE p.ProductId = (SELECT ProductId FROM inserted WHERE ProductionOrderId = @changedOrderID);

    SET @newEnd = dbo.AddProductionTime(@newStart, @minutesNeeded, @productionLineID);

    -- Aktualizujemy koniec tego zamówienia 
    UPDATE ProductionOrder SET PlannedEndDate = @newEnd WHERE ProductionOrderId = @changedOrderID;

    -- 2. LOGIKA PRZESUWANIA RESZTY

    DECLARE @anchor DATETIME = @newEnd;
--     Przesunięcie wszystkich zamówień o czas aktualnego 
    EXEC dbo.usp_RescheduleProductionLine @ProductionLineId = @productionLineID, @AnchorDate = @anchor, @ExcludedOrderId = @changedOrderID

    declare @EstimatedTimePerUnit decimal(6,2);
    declare @TimeDiffHours decimal(6,2);
    declare @OldQuantity int


    select
        @OldQuantity=deleted.Quantity,
        @EstimatedTimePerUnit=EstimatedProductionTime
    from deleted
    inner join Products
    on Products.ProductId=deleted.ProductId

    -- Obliczamy ile godzin ubyło (różnica sztuk * czas jednostkowy)
    SET @TimeDiffHours = (@OldQuantity - @NewQuantity) * @EstimatedTimePerUnit;

    --  Wywołujemy procedurę czyszczącą alokację od końca
    EXEC dbo.usp_ReduceAllocatedHoursFromEnd @productionLineID, @TimeDiffHours;
END
go

