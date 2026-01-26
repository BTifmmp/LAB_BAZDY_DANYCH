CREATE OR ALTER function CalculateEfficiencyFactor(@Date date,@ProductionLineID int)
returns decimal(16,6)
-- Funkcja oblicza ile mocy przerobowej posiada linia w podanym w dniu w rzeczywistej godzinie pracy lini.
as
    begin
        Declare @EfficiencyFactor decimal(16,6)

        IF EXISTS (
            SELECT 1
            FROM ProductionLineTimeAllocation
            WHERE ProductionLineId = @ProductionLineID
            AND Date = @Date

            )
        begin
            select @EfficiencyFactor=60*(HoursTotal-DowntimeHours)/datediff(minute ,ShiftStart,ShiftEnd)
            from ProductionLineTimeAllocation
            where ProductionLineId=@ProductionLineID
            and Date=@Date
        end
        return @EfficiencyFactor
    end
go


-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

-- Funkcja sprawdza w jakim dniu zostanie wyprodukowana podana ilość produktu dla zadanego zamówienia produkcyjnego
-- Funkcja w pierwszej kolejności sprawdza wpisy z ProductionHistory, jeśli ich nie ma szacuje możliwości produkcyjne
CREATE OR ALTER function CalculateWhenQuantityOfProductWillBeProduced(
    @ProductionOrderID int,
    @Quantity int
    )
returns date
as
    begin
    DECLARE @ProductionStartDate datetime
    DECLARE @ProductionEndDate date
    DECLARE @freeHours int
    DECLARE @EstimatedTime decimal(6,2)
    DECLARE @ProductionLineID int



    select
           @ProductionStartDate=PlannedStartDate,
           @ProductionEndDate=PlannedEndDate,
           @ProductionLineID=ProductionLineId,
           @EstimatedTime=EstimatedProductionTime
    from ProductionOrder pd
    inner join Products p on pd.ProductID=p.ProductID
    where ProductionOrderID=@ProductionOrderID


--     Oblicz ile godzin linia pracowała w pierwszy dzień produkcji
    select @freeHours=(
        datediff(
                minute,
                cast(@ProductionStartDate as time),
                ShiftEnd)-DowntimeHours*60)*dbo.CalculateEfficiencyFactor(@ProductionStartDate,@ProductionLineID )/60
    from ProductionLineTimeAllocation
    where Date=cast(@ProductionStartDate as date) and
          ProductionLineId=@ProductionLineID

    DECLARE @Finishday date
    ;WITH capactiy as (
        select
            pta.Date,
            ph.Quantity as RealQuantity,
            @freeHours/@EstimatedTime  as DailyCapacity
        from ProductionLineTimeAllocation pta
        left join ProductionHistory ph on ph.ProductionOrderID=@ProductionOrderID and ph.ProducedDate=Date
        where Date=cast(@ProductionStartDate as date)
        and pta.ProductionLineId=@ProductionLineID
        UNION ALL
        select
            pta.Date,
            ph.Quantity as RealQuantity,
            (pta.HoursTotal-DowntimeHours)/@EstimatedTime as DailyCapacity
        from ProductionLineTimeAllocation pta
        left join ProductionHistory ph on ph.ProductionOrderID=@ProductionOrderID and ph.ProducedDate=Date
        where Date>cast(@ProductionStartDate as date)
        and pta.Date<=@ProductionEndDate
        and pta.ProductionLineId=@ProductionLineID

    ), cumulativeCapacity as (
        SELECT
                Date,
                coalesce(RealQuantity,DailyCapacity) as DailyCapacity,
                SUM(coalesce(RealQuantity,DailyCapacity)) OVER (ORDER BY Date ASC) AS CumulatedQuantity
            FROM capactiy
    )


     select TOP 1 @Finishday=Date
     from cumulativeCapacity
     where CumulatedQuantity>=@Quantity

    return @Finishday


    end
go




-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

-- Procedura tworzy nowe zamówienie produkcyjne.
-- Zamówienie zaczyna się od końca ostatniego zamówienia lub od następnej pełnej godziny lub od początku zmiany następnego dnia gdzie możliwa jest produkcja
CREATE OR ALTER procedure CreateNewProductionOrder
@Deadline date,
@Quantity int,
@ProductID int,
@OnlyCheck bit=0
as
    DECLARE @ProductionStartDate datetime
    DECLARE @ProductionEndDate datetime
    DECLARE @HoursAvailableAtFirstDay decimal(10,2)
    DECLARE @HoursAtTheLastDay decimal(10,2)
    DECLARE @ProductionOrderStatus int
    DECLARE @EstimatedTime decimal(10,2)
    DECLARE @ProductionLineID int
    DECLARE @ShiftStartOnFirstDay time(0)
    DECLARE @ShiftEndOnFirstDay time(0)

    IF NOT EXISTS(select 1 from Products where ProductId=@ProductID)
        begin
            Throw 50001 ,N'Nie ma takiego produktu' ,1;
        end

    IF  EXISTS(select 1 from Products where ProductId=@ProductID and Removed=1)
        begin
            Throw 50004, N'Podany produkt został wycofany',1;
        end
    IF @Deadline<cast(getdate() as date)
        BEGIN
           THROW 50005, N'Data nie może być w przeszłości', 1;
        END

    select
        @ProductionLineID=ProductionLineId,
        @EstimatedTime=@Quantity*EstimatedProductionTime
    from Products p
    inner join ProductCategories cat on p.ProductCategoryId = cat.ProductCategoryID
    inner join ProductionLine pl on cat.ProductCategoryID = pl.ProductCategoryId
    where ProductId=@ProductID

--   Pobierz date, gdy skończy się ostatnia produkcja i dalej w tym dniu możemy coś produkować. Jeśli nie ma takiej daty, produkcję zaczynamy od następnej pełnej godziny
    select @ProductionStartDate=coalesce(
                                         max(PlannedEndDate),
                                         dateadd(hour,datediff(hour,0,getdate())+1,0)
                                        )
    from ProductionOrder pd
    inner join ProductionOrderStatus ps on pd.ProductionOrderStatus = ps.ProductionOrderStatus
    inner join ProductionLineTimeAllocation plt on plt.ProductionLineId=pd.ProductionLineId
    where
        pd.ProductionLineId=@ProductionLineID
        and ps.Status not in('Wyprodukowane','Anulowane')
        and HoursTotal>HoursAllocated
        and Date>=cast(getdate() as date)

    
    select @ShiftStartOnFirstDay=ShiftStart,
           @ShiftEndOnFirstDay=ShiftEnd
    from ProductionLineTimeAllocation
    where ProductionLineId=@ProductionLineID
    and Date=cast(@ProductionStartDate as date)
--     W przypadku gdy zaczynamy produkcję od następnej pełnej godziny, sprawdź czy godzina zawiera się pomiędzy ShiftStart a ShiftEnd.
--     Jeśli godzina rozpoczęcia jest większa od ShiftEnd zaczynamy produkcję od ShiftStart z następnego dnia gdzie jest możliwa produkcja
--     Jeśli godzina rozpoczęcia jest mniejsza od ShiftStart zaczynamy produkcję od ShiftStart z tego samego dnia
    
    select @ProductionStartDate=
        CASE
            WHEN cast(@ProductionStartDate as time(0)) >= @ShiftEndOnFirstDay
                THEN DATEADD(
                             minute,
                             60*DATEPART(hour,ShiftStart)+DATEPART(minute,ShiftStart),
                             cast(Date as datetime))
            WHEN cast(@ProductionStartDate as time(0))<@ShiftStartOnFirstDay
                THEN dateadd(
                            minute,
                            60*DATEPART(hour,@ShiftStartOnFirstDay)+DATEPART(minute,@ShiftStartOnFirstDay),
                            cast(CAST(@ProductionStartDate as date) as datetime)
                     )
            Else @ProductionStartDate
        END
    FROM ProductionLineTimeAllocation
    where ProductionLineId=@ProductionLineID
    and DATE>cast(@ProductionStartDate as date)
    and HoursTotal-HoursAllocated-DowntimeHours>0


-- Pobierz liczbę godzin dostępną w pierwszy dzień produkcji teggo zamówienia, jest to różnica czasu między początkiem zamówienia a końcem zmiany przeskalowana w odpowiedni spsoób.

    select @HoursAvailableAtFirstDay=datediff(minute,
                                              cast(@ProductionStartDate as time(0)),
                                              ShiftEnd
                                                )*1.0/60*dbo.CalculateEfficiencyFactor(@ProductionStartDate,@ProductionLineID)
    from ProductionLineTimeAllocation
    where ProductionLineId=@ProductionLineID
    and Date=cast(@ProductionStartDate as date)



-- Ustaw status zamówienia
    select @ProductionOrderStatus=ProductionOrderStatus
    from ProductionOrderStatus
    where Status='Planowane'

--     Suma dostępnych godzin od dnia początkowego do daty końcowej @Deadline
    ;with TimeSlots as(
        select Date,
               @HoursAvailableAtFirstDay as Available
        from ProductionLineTimeAllocation
        where
            ProductionLineId=@ProductionLineID
            and Date=cast(@ProductionStartDate as date)
        union all
        select
            Date,
            (HoursTotal-HoursAllocated-DowntimeHours) as Available
        from ProductionLineTimeAllocation
        where
            ProductionLineId=@ProductionLineID
            and Date<=@Deadline
            and Date>cast(@ProductionStartDate as date)
    ), cumulativeTime as (
        select
            Date,
            Available,
            sum(Available) over (ORDER BY Date ASC) as CumulativeAvailable
        from TimeSlots
    )

--      Wbierz date gdy godziny wystarczą, aby wyprodukować zamówienie.
--      Oblicz liczbę godzin ostatniego wymaganaego dnia pracy
    select TOP 1
        @ProductionEndDate=Date,
        @HoursAtTheLastDay=-(CumulativeAvailable-Available-@EstimatedTime)
    from cumulativeTime
    where CumulativeAvailable>=@EstimatedTime

    
--     Jeśli nie możemy wyprodukować produktu w podanym czasie zwraca błąd
     IF @ProductionEndDate is null
        begin
            THROW 50000,N'Nie mozna wyprodukowac podanych produktow w podanym czasie',1;
        end
--  Jeśli nie zwrócono błędu to możemy wyprodukować produkty w podanym terminie, więc jeśli tylko sprawdzamy możliwość przerwij działanie procedury
    IF @OnlyCheck = 1
        BEGIN
           RETURN
        END

    DECLARE @EfiiciencyFactor  decimal(10,6)=dbo.CalculateEfficiencyFactor (@ProductionEndDate,@ProductionLineID )
    

--     Oblicz godzine, ostatniego dnia produkcji
    select @ProductionEndDate=
           CASE
                WHEN cast(@ProductionStartDate as date)=cast(@ProductionEndDate as date)
                    THEN dateadd(minute,
                                ROUND(60*@HoursAtTheLastDay/@EfiiciencyFactor,3),
                                @ProductionStartDate
                         )
                ELSE
                    dateadd(minute,
                            ROUND(60*@HoursAtTheLastDay/@EfiiciencyFactor,3),
                            cast(@ProductionEndDate as datetime)+cast(ShiftStart as datetime))
           END

    from ProductionLineTimeAllocation
    where ProductionLineId=@ProductionLineID
    and Date = @ProductionEndDate
    

-- Zaalokuj wymagane godziny
    UPDATE ProductionLineTimeAllocation
    set HoursAllocated =
        CASE
            WHEN Date=cast(@ProductionStartDate as date) then iif(@HoursAvailableAtFirstDay>@EstimatedTime,HoursAllocated+@EstimatedTime,HoursAllocated+@HoursAvailableAtFirstDay)
            WHEN Date=cast(@ProductionEndDate as date) then @HoursAtTheLastDay
--             Używamy całej mocy lini, gdy nie jest to dzień początkowy ani końcowy
            WHEN Date>@ProductionStartDate and Date<@ProductionEndDate then HoursTotal
            ELSE HoursAllocated
        END
    where ProductionLineId=@ProductionLineID
    and date >= cast(@ProductionStartDate as date)
    and date<= cast(@ProductionEndDate as date)
--     Dodaj nowe zamówienie produkcyjne

    insert into ProductionOrder(ProductionLineId, ProductionOrderStatus, ProductId, Quantity, QuantityProduced, AddedDate, PlannedStartDate, PlannedEndDate)
    values
        (@ProductionLineID,@ProductionOrderStatus,@ProductID,@Quantity,0,cast(getdate() as date),@ProductionStartDate,@ProductionEndDate)
go




-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

-- Procedura sprawdza czy akutalne zamówienia produkcyjne są w stanie wyprodukować @Quantity produktów.
-- Jeśli nie tworzy nowe zamówienie produkcyjne
-- Jeśli nie można wyrpodukować potrzebnej ilości produktów zwraca błąd
-- Flaga @OnlyCheck informuje o tym czy system ma tylko sprawdzić możliwośći produkcyjne.

CREATE OR ALTER procedure RedirectAndCreateNewOrder
@ProductID int ,
@EndDate date,
@Quantity int,
@OnlyCheck bit =0
as
    SET NOCOUNT ON
    SET XACT_ABORT ON
    DECLARE @UnitProductionTime decimal(3,1)
    DECLARE @ProductionLineID int
    DECLARE @QuantityToProduce int

    IF not exists(select 1 from Products where ProductId=@ProductID)
        begin
            Throw 50000 ,N'Nie ma takiego produktu' ,1;
        end
    IF  EXISTS(select 1 from Products where ProductId=@ProductID and Removed=1)
        begin
            Throw 50004, N'Podany produkt został wycofany',1;
        end
    select
           @UnitProductionTime=EstimatedProductionTime,
           @ProductionLineID=ProductionLineId,
           @QuantityToProduce=Reserved-Available+@Quantity
    from Products p
    inner join ProductCategories cat on p.ProductCategoryId = cat.ProductCategoryID
    inner join ProductionLine pt on cat.ProductCategoryID = pt.ProductCategoryId
    Where ProductId=@ProductID


--     ----------------------------------------------
--      Sprawdź czy akutalne produkcje są w stanie wypełnić wszystkie zamówwienia
--     ----------------------------------------------
     select
         ProductionOrderID,
         CASE
             when cumulativeQuantity-availableQuantity>=@QuantityToProduce then 0
             when cumulativeQuantity<=@QuantityToProduce then availableQuantity
             else @QuantityToProduce-(cumulativeQuantity-availableQuantity)
         END as quantityToUse,
         cumulativeQuantity,
         PlannedEndDate
    into
        #cumulativeOrderStats
    from (
            select
                ProductionOrderID,
                Quantity-QuantityProduced as availableQuantity,
                sum(Quantity-QuantityProduced) over ( order by PlannedEndDate ASC) as cumulativeQuantity,
                PlannedEndDate
            from ProductionOrder pd
            inner join ProductionOrderStatus pos on pd.ProductionOrderStatus = pos.ProductionOrderStatus
            where
                ProductId=@ProductID
                and cast(PlannedStartDate as date)<=@EndDate
                and Status not in ('Gotowe','Anulowane')
                and Quantity>QuantityProduced

         ) as orderStats

    Declare @RemainingQuantity int
    Declare @EndDateForLastProductionOrder date
    Declare @LastUsedQuantity int
    Declare @ProductionOrderID int


    select top 1
        @RemainingQuantity=@QuantityToProduce-cumulativeQuantity,
        @EndDateForLastProductionOrder=cast(PlannedEndDate as date),
        @LastUsedQuantity=quantityToUse,
        @ProductionOrderID=ProductionOrderID
    from #cumulativeOrderStats
    where quantityToUse>0
    order by cumulativeQuantity DESC

   

    SET @RemainingQuantity=COALESCE(@RemainingQuantity,@QuantityToProduce)
    BEGIN TRY
        IF @RemainingQuantity>0
            EXEC CreateNewProductionOrder @Deadline = @EndDate, @Quantity = @RemainingQuantity, @ProductID = @ProductID,@OnlyCheck = @OnlyCheck
        ELSE
            IF  dbo.CalculateWhenQuantityOfProductWillBeProduced(@ProductionOrderID,@LastUsedQuantity)>@EndDate
                begin
                    THROW 50000,N'Nie można wyprodukować podanych produktów w podanym czasie',1;
                end
    end try
    begin catch
        THROW 
    end catch
go



-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

-- Funkcja Tworzy nowe zamówienie klienta
CREATE OR ALTER PROCEDURE    createCustomerOrder
@CustomerID int,
@Items OrderItem READONLY ,
@Deadline date,
@ShipAddress varchar(50) = null,
@ShipCountry varchar(50) = null,
@ShipCity varchar(50) = null,
@ShipRegion varchar(50) = null,
@ShipPostalCode varchar(10) = null
--     Procedura wymaga utworzenia typu tabelarycznego OrderItem. Kod tworzący typ jest w pliku init.sql
as
    IF NOT EXISTS(select 1 from Customers where CustomerID=@CustomerID)
        BEGIN
            Throw 50001 ,N'Nie ma takiego Klienta', 1;
        END

    IF EXISTS(select ProductID from @Items except select ProductId from Products)
        BEGIN
            THROW 50002 ,N'Jeden lub więcej produktów nie istnieje' ,1;
        END

    IF EXISTS(select 1 from @Items i
                inner join Products p on p.ProductId=i.ProductID
                where Removed=1)
        BEGIN
            THROW 50004,N'Jeden lub więcej produktów zostało wycofanych',1;
        END

      
   -- Sprawdź czy można wyprodukować podane produkty do @Deadline
    BEGIN TRY
        EXEC RedirectItems @Items=@Items,@Deadline = @Deadline,@OnlyCheck = 1
    end try
    begin catch
        THROW
    end catch
--         Jesli nie podano adresu, pobierz adres klienta
    select @ShipAddress=coalesce(@ShipAddress,Address),
           @ShipCountry=coalesce(@ShipCountry,Country),
           @ShipCity=coalesce(@ShipCity,City),
           @ShipRegion=coalesce(@ShipRegion,Region),
           @ShipPostalCode=coalesce(@ShipPostalCode,PostalCode)
    from Customers
    where CustomerID=@CustomerID

    IF @ShipAddress is null or @ShipCountry is null or @ShipCity is null or @ShipRegion is null or @ShipPostalCode is null
        begin
            THROW 50003,N'Adres nie jest kompletny' ,1;
        end

    DECLARE @OrderStatus int
    select @OrderStatus=OrderStatusID from OrderStatus where OrderStatusName='Nieoplacone'

    Declare @OrderID int
--     Stwórz nowe zamówienie
    insert into Orders(CustomerID, Status, ShipAddress, ShipCountry, ShipCity, ShipRegion, ShipPostalCode, OrderDate,RequiredDate)
    values
        (@CustomerID,@OrderStatus,@ShipAddress,@ShipCountry,@ShipCity,@ShipRegion,@ShipPostalCode,cast(getdate() as date),@Deadline)


    set @OrderID=SCOPE_IDENTITY();

     --     Dodaj pozycje zamówienia
    insert into OrderDetails(OrderID, ProductId, Quantity, UnitPrice, Discount)
    select @OrderID,I.ProductId,i.Quantity,p.CurrentSellPrice,i.Discount
    from @Items i
    inner join Products p on i.ProductID=p.ProductId
go


-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

-- Procedura dla każdego produktu z @Items wykonuje procedure RedirectAndCreateNewOrder
-- @OnlyCheck = 1, sprawi że system sprawdzi tylko możliwości produkcyjne. Nie zostaną dodane żadne nowe wiersze
CREATE OR ALTER procedure RedirectItems
@Items OrderItem READONLY,
@Deadline date,
@OnlyCheck bit = 0
as
    DECLARE productCursor cursor keyset FOR
    select i.ProductId,i.Quantity
    from @Items i
        inner join Products p on i.ProductID=p.ProductId
    where Available-Reserved<i.Quantity

    open productCursor

    if @@CURSOR_ROWS=0
        begin
--         Wszystkie produkty są dostępne w magazyanie

            close productCursor
            deallocate productCursor
            return
        end
-- Dla każdej pozycji zamówienia sprawdź czy można ją wyprodukować do terminu @Deadline. Jeśli @OnlyCheck=0 zostaną też w miare potrzeb stworzone nowe zlecenia produkcyjne. 
    DECLARE @CurrentProductID int
    DECLARE @CurrentQuantity int
    BEGIN TRANSACTION ;
    begin try

        FETCH NEXT from productCursor into @CurrentProductID,@CurrentQuantity
        while @@FETCH_STATUS = 0
        begin
            exec RedirectAndCreateNewOrder @ProductID = @CurrentProductID, @EndDate = @Deadline,@Quantity = @CurrentQuantity,@OnlyCheck = @OnlyCheck

            FETCH NEXT FROM productCursor into @CurrentProductID,@CurrentQuantity
        end

        close productCursor
        deallocate productCursor
        COMMIT TRANSACTION ;
        
    end try
    begin catch

        close productCursor
        deallocate productCursor
        ROLLBACK TRANSACTION ;

        THROW

    end catch
go

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--Procedura pozwala na anulowanie zamowienia

CREATE OR ALTER PROCEDURE CancelFullOrder
    @OrderID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Blokada dla zamówień wysłanych/zrealizowanych
    IF EXISTS (SELECT 1 FROM Orders WHERE OrderID = @OrderID AND Status IN (3, 4, 5))
    BEGIN
        RETURN;
    END

    -- 2. Aktualizacja statusu
    UPDATE Orders
    SET Status = 5 -- 'Anulowane'
    WHERE OrderID = @OrderID;
END;
GO


-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Procedura pozwala na zmiane ilosci produktu w zamowieniu
CREATE OR ALTER PROCEDURE UpdateOrderProductQuantity
    @OrderID INT,
    @ProductID INT,
    @NewQuantity INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Blokada edycji dla zamówień gotowe do wys(3), zrealizowane (4) lub anulowane (5)
    IF EXISTS (SELECT 1 FROM Orders WHERE OrderID = @OrderID AND Status IN (3, 4, 5))
    BEGIN
        RETURN;
    END

    -- 3. Scenariusz: Usuwanie produktu (ilość <= 0)
    IF @NewQuantity <= 0
    BEGIN
        -- Usuwamy z detali zamówienia
        DELETE FROM OrderDetails 
        WHERE OrderID = @OrderID AND ProductID = @ProductID;

        -- Usuwamy odpowiadającą rezerwację 
        DELETE FROM ProductReservation 
        WHERE OrderID = @OrderID AND ProductID = @ProductID;
    END
    -- 4. Scenariusz: Aktualizacja ilości
    ELSE
    BEGIN
        -- Aktualizujemy ilość w zamówieniu
        UPDATE OrderDetails 
        SET Quantity = @NewQuantity 
        WHERE OrderID = @OrderID AND ProductID = @ProductID;

        -- Aktualizujemy ilość w rezerwacji 
        UPDATE ProductReservation
        SET Quantity = @NewQuantity
        WHERE OrderID = @OrderID AND ProductID = @ProductID;
    END

    -- Po zmianiae reserved uruchomia sie trigger na ProducTresevation ktory robi update producktu
END;
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER FUNCTION CalculateOrderValue_FN
(
    @OrderID INT
)
RETURNS DECIMAL(10, 2)
AS
BEGIN
    DECLARE @TotalAmount DECIMAL(10, 2);

    -- Obliczenie sumy wartości wszystkich pozycji w zamówieniu
    SELECT
        @TotalAmount = SUM(
            od.Quantity * od.UnitPrice * (1.0 - od.Discount)
        )
    FROM
        OrderDetails od
    WHERE
        od.OrderId = @OrderID;
        
    IF @TotalAmount IS NULL
    BEGIN
        SET @TotalAmount = 0.00;
    END

    RETURN @TotalAmount;
END
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------