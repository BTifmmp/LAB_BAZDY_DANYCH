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
-- Aktualizuje ProductionOrder zwiekszajac iloc wyprodukowanych, zmieniajac status oraz ustawiajac date zakonczenia
CREATE OR ALTER TRIGGER trg_ProductionHistory_UpdateOrder
ON ProductionHistory
AFTER INSERT
AS
BEGIN
    -- 1. Aktualizacja wyprodukowanej ilości w ProductionOrder
    UPDATE po
    SET po.QuantityProduced = (SELECT SUM(Quantity) FROM ProductionHistory WHERE ProductionOrderID = po.ProductionOrderID),
        -- 2. Jeśli wyprodukowano tyle co zamówiono, ustaw status na 'Wyprodukowane' (3) i dodaj EndDate
        po.ProductionOrderStatus = CASE 
            WHEN (SELECT SUM(Quantity) FROM ProductionHistory WHERE ProductionOrderID = po.ProductionOrderID) >= po.Quantity 
            THEN 3 ELSE po.ProductionOrderStatus END,
        po.EndDate = CASE 
            WHEN (SELECT SUM(Quantity) FROM ProductionHistory WHERE ProductionOrderID = po.ProductionOrderID) >= po.Quantity 
            THEN GETDATE() ELSE po.EndDate END
    FROM ProductionOrder po
    JOIN inserted i ON po.ProductionOrderID = i.ProductionOrderID;
END;
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
CREATE OR ALTER TRIGGER trg_ProductReservation_UpdateProductsReserved
ON ProductReservation
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. OBSŁUGA ZWIĘKSZENIA REZERWACJI / NOWYCH POZYCJI
    IF EXISTS (SELECT 1 FROM inserted i 
              LEFT JOIN deleted d ON i.OrderID = d.OrderID AND i.ProductID = d.ProductID
              WHERE d.Quantity IS NULL OR i.Quantity > d.Quantity)
    BEGIN
        DECLARE @CurrentOrderID INT;
        DECLARE @CurrentDeadline DATE;
        DECLARE @Items OrderItem; 

        DECLARE order_cur CURSOR FOR 
        SELECT DISTINCT i.OrderID, o.RequiredDate
        FROM inserted i
        JOIN Orders o ON i.OrderID = o.OrderID
        -- Ważne: filtrujemy kursor, by brał tylko zamówienia ze wzrostem ilości
        WHERE EXISTS (
            SELECT 1 FROM inserted i2 
            LEFT JOIN deleted d2 ON i2.OrderID = d2.OrderID AND i2.ProductID = d2.ProductID
            WHERE i2.OrderID = i.OrderID AND (d2.Quantity IS NULL OR i2.Quantity > d2.Quantity)
        );

        OPEN order_cur;
        FETCH NEXT FROM order_cur INTO @CurrentOrderID, @CurrentDeadline;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- CZYŚCIMY zawartość zmiennej przed kolejnym zamówieniem
            DELETE FROM @Items;

            INSERT INTO @Items(ProductID, Quantity, Discount)
            SELECT 
                i.ProductId,
                (i.Quantity - ISNULL(d.Quantity, 0)),
                od.Discount
            FROM inserted i
            INNER JOIN OrderDetails od ON od.OrderID = i.OrderID AND od.ProductId = i.ProductID
            LEFT JOIN deleted d ON i.OrderID = d.OrderID AND i.ProductID = d.ProductID
            WHERE i.OrderID = @CurrentOrderID 
              AND (i.Quantity > d.Quantity OR d.Quantity IS NULL);

            IF EXISTS (SELECT 1 FROM @Items)
            BEGIN
                EXEC RedirectItems @Items = @Items, @Deadline = @CurrentDeadline;
            END

            FETCH NEXT FROM order_cur INTO @CurrentOrderID, @CurrentDeadline;
        END 

        CLOSE order_cur;
        DEALLOCATE order_cur;
    END

    -- 2. OBSŁUGA ZMNIEJSZENIA REZERWACJI / ANULOWANIA (Redukcja produkcji)
    IF EXISTS (SELECT 1 FROM deleted d 
               LEFT JOIN inserted i ON i.OrderID = d.OrderID AND i.ProductID = d.ProductID
               WHERE i.Quantity IS NULL OR d.Quantity > i.Quantity)
    BEGIN
        -- Kursor lub pętla do obsłużenia redukcji dla każdego produktu
        DECLARE @RedProductId INT, @DiffQuantity INT;

        DECLARE cur CURSOR FOR
        SELECT 
            d.ProductId,
            (d.Quantity - ISNULL(i.Quantity, 0))
        FROM deleted d
        LEFT JOIN inserted i ON i.OrderID = d.OrderID AND i.ProductID = d.ProductID
        WHERE (d.Quantity > i.Quantity OR i.Quantity IS NULL);

        OPEN cur;
        FETCH NEXT FROM cur INTO @RedProductId, @DiffQuantity;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- W TYM MIEJSCU POWINO ZOSTAC WYWOWALE ZMNIEJSNIE ZAMOWIENIA PRODUKCJI
            -- EXEC ReduceProductProduction @ProductID = @RedProductId, @Quantity = @DiffQuantity;
            FETCH NEXT FROM cur INTO @RedProductId, @DiffQuantity;
        END
        CLOSE cur;
        DEALLOCATE cur;
    END

    -- 3. AKTUALIZACJA POLA RESERVED W TABELI PRODUCTS
    -- Zwiększanie o to co wstawiono/zmieniono na plus
    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        UPDATE p
        SET p.Reserved = ISNULL(p.Reserved, 0) + i.TotalQty
        FROM Products p
        INNER JOIN (SELECT ProductID, SUM(Quantity) AS TotalQty FROM inserted GROUP BY ProductID) i 
        ON p.ProductId = i.ProductID;
    END

    -- Zmniejszanie o to co usunięto/zmieniono na minus
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        UPDATE p
        SET p.Reserved = ISNULL(p.Reserved, 0) - d.TotalQty
        FROM Products p
        INNER JOIN (SELECT ProductID, SUM(Quantity) AS TotalQty FROM deleted GROUP BY ProductID) d 
        ON p.ProductId = d.ProductID;
    END
END
GO

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

CREATE OR ALTER TRIGGER trg_CheckStockAndProduce
ON Products
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
END;

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------