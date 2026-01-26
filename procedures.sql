CREATE function CalculateEfficiencyFactor(@Date date,@ProductionLineID int)
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
CREATE   function CalculateWhenQuantityOfProductWillBeProduced(
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
CREATE procedure CreateNewProductionOrder
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

CREATE procedure RedirectAndCreateNewOrder
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
CREATE PROCEDURE    createCustomerOrder
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
CREATE procedure RedirectItems
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

-- Generuje zestawienie miesięcznych przychodów ze sprzedaży z możliwością filtrowania po wybranym okresie. 
CREATE PROCEDURE sp_MonthlySales
    @StartYear INT = NULL,
    @EndYear INT = NULL,
    @StartMonth INT = NULL,
    @EndMonth INT = NULL
AS
BEGIN
    IF @StartYear IS NULL
        SET @StartYear = 1900;

    IF @EndYear IS NULL
        SET @EndYear = 9999;

    IF @StartMonth IS NULL
        SET @StartMonth = 1;

    IF @EndMonth IS NULL
        SET @EndMonth = 12;

    SELECT
        YEAR(o.OrderDate) AS SalesYear,
        MONTH(o.OrderDate) AS SalesMonth,
        COUNT(DISTINCT o.OrderID) AS OrdersCount,
        SUM(dbo.CalculateOrderValue_FN(o.OrderID)) AS MonthlyRevenue
    FROM Orders o
    JOIN OrderDetails od ON o.OrderID = od.OrderID
    JOIN OrderStatus os ON o.Status = os.OrderStatusID
    WHERE os.OrderStatusName IN ('Opłacone', 'Gotowe do wysyłki', 'Zrealizowane')
        AND (
            (YEAR(o.OrderDate) > @StartYear OR
             (YEAR(o.OrderDate) = @StartYear AND MONTH(o.OrderDate) >= @StartMonth))
            AND
            (YEAR(o.OrderDate) < @EndYear OR
             (YEAR(o.OrderDate) = @EndYear AND MONTH(o.OrderDate) <= @EndMonth))
        )
    GROUP BY YEAR(o.OrderDate), MONTH(o.OrderDate)
    ORDER BY SalesYear DESC, SalesMonth DESC;
END
go

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

-- Tworzy ranking bestsellerów na podstawie przychodów ze sprzedaży produktów w określonym przedziale czasowym. 
CREATE PROCEDURE sp_TopSellingProducts
    @StartYear INT = NULL,
    @EndYear INT = NULL,
    @StartMonth INT = NULL,
    @EndMonth INT = NULL,
    @TopN INT = NULL
AS
BEGIN
    IF @StartYear IS NULL
        SET @StartYear = 1900;

    IF @EndYear IS NULL
        SET @EndYear = 9999;

    IF @StartMonth IS NULL
        SET @StartMonth = 1;

    IF @EndMonth IS NULL
        SET @EndMonth = 12;

    IF @TopN IS NULL
        SET @TopN = 999999;

    SELECT TOP (@TopN)
        p.ProductName,
        pc.CategoryName,
        SUM(od.Quantity) AS TotalUnitsSold,
        SUM(od.Quantity * od.UnitPrice * (1.0 - od.Discount)) AS TotalRevenue,
        p.CurrentSellPrice,
        AVG(od.UnitPrice * (1.0 - od.Discount)) AS AvgSellingPrice
    FROM Products p
    JOIN ProductCategories pc ON p.ProductCategoryId = pc.ProductCategoryID
    JOIN OrderDetails od ON p.ProductId = od.ProductId
    JOIN Orders o ON od.OrderID = o.OrderID
    JOIN OrderStatus os ON o.Status = os.OrderStatusID
    WHERE os.OrderStatusName IN ('Opłacone', 'Gotowe do wysyłki', 'Zrealizowane')
        AND (
            (YEAR(o.OrderDate) > @StartYear OR
             (YEAR(o.OrderDate) = @StartYear AND MONTH(o.OrderDate) >= @StartMonth))
            AND
            (YEAR(o.OrderDate) < @EndYear OR
             (YEAR(o.OrderDate) = @EndYear AND MONTH(o.OrderDate) <= @EndMonth))
        )
    GROUP BY
        p.ProductId, p.ProductName, pc.CategoryName, p.CurrentSellPrice
    ORDER BY TotalRevenue DESC;
END
go

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

-- Procedura umożliwia identyfikację najcenniejszych klientów według łącznej wartości wydatków na zamówienia w określonym przedziale czasowym.
CREATE PROCEDURE sp_CustomerRanking
    @StartYear INT = NULL,
    @EndYear INT = NULL,
    @StartMonth INT = NULL,
    @EndMonth INT = NULL,
    @TopN INT = NULL,
    @OrderBy VARCHAR(20) = 'TotalSpent'
AS
BEGIN
    IF @StartYear IS NULL
        SET @StartYear = 1900;

    IF @EndYear IS NULL
        SET @EndYear = 9999;

    IF @StartMonth IS NULL
        SET @StartMonth = 1;

    IF @EndMonth IS NULL
        SET @EndMonth = 12;

    IF @TopN IS NULL
        SET @TopN = 999999;

    IF @OrderBy NOT IN ('TotalSpent', 'OrdersCount')
        SET @OrderBy = 'TotalSpent';

    ;WITH CustomerStats AS (
        SELECT
            c.CustomerID,
            c.CustomerName,
            ct.TypeName AS CustomerType,
            COUNT(o.OrderID) AS OrdersCount,
            SUM(dbo.CalculateOrderValue_FN(o.OrderID)) AS TotalSpent,
            MAX(o.OrderDate) AS LastOrderDate,
            AVG(dbo.CalculateOrderValue_FN(o.OrderID)) AS AvgOrderValue,
            MIN(o.OrderDate) AS FirstOrderDate
        FROM Customers c
        JOIN Orders o ON c.CustomerID = o.CustomerID
        JOIN OrderDetails od ON o.OrderID = od.OrderID
        JOIN CustomerType ct ON c.CustomerType = ct.TypeID
        JOIN OrderStatus os ON o.Status = os.OrderStatusID
        WHERE os.OrderStatusName IN ('Opłacone', 'Gotowe do wysyłki', 'Zrealizowane')
            AND (
                (YEAR(o.OrderDate) > @StartYear OR
                 (YEAR(o.OrderDate) = @StartYear AND MONTH(o.OrderDate) >= @StartMonth))
                AND
                (YEAR(o.OrderDate) < @EndYear OR
                 (YEAR(o.OrderDate) = @EndYear AND MONTH(o.OrderDate) <= @EndMonth))
            )
        GROUP BY c.CustomerID, c.CustomerName, ct.TypeName
    )
    SELECT TOP (@TopN)
        CustomerName,
        CustomerType,
        OrdersCount,
        TotalSpent,
        AvgOrderValue,
        LastOrderDate,
        FirstOrderDate,
        DATEDIFF(DAY, FirstOrderDate, LastOrderDate) AS CustomerLifetimeDays
    FROM CustomerStats
    ORDER BY
        CASE WHEN @OrderBy = 'TotalSpent' THEN TotalSpent END DESC,
        CASE WHEN @OrderBy = 'OrdersCount' THEN OrdersCount END DESC;
END
go

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

-- Ocenia skuteczność procesu produkcyjnego analizując wskaźnik wadliwości dla poszczególnych produktów i linii produkcyjnych w określonym przedziale czasowym.
CREATE PROCEDURE sp_ProductionEfficiency
    @StartYear INT = NULL,
    @EndYear INT = NULL,
    @StartMonth INT = NULL,
    @EndMonth INT = NULL,
    @ProductionLineId INT = NULL,
    @MinDefectRate DECIMAL(5,2) = NULL,
    @MaxDefectRate DECIMAL(5,2) = NULL
AS
BEGIN
    IF @StartYear IS NULL
        SET @StartYear = 1900;

    IF @EndYear IS NULL
        SET @EndYear = 9999;

    IF @StartMonth IS NULL
        SET @StartMonth = 1;

    IF @EndMonth IS NULL
        SET @EndMonth = 12;

    SELECT
        p.ProductName,
        pl.ProductionLineId,
        SUM(ph.Quantity) AS TotalProducedGood,
        SUM(ph.RejectedQuantity) AS TotalRejected,
        SUM(ph.Quantity) + SUM(ph.RejectedQuantity) AS TotalProduced,
        CAST(
            CASE
                WHEN (SUM(ph.Quantity) + SUM(ph.RejectedQuantity)) = 0 THEN 0
                ELSE (SUM(ph.RejectedQuantity) * 100.0) / (SUM(ph.Quantity) + SUM(ph.RejectedQuantity))
            END
        AS DECIMAL(5,2)) AS DefectRatePercent,
        COUNT(DISTINCT po.ProductionOrderID) AS ProductionOrdersCount
    FROM ProductionHistory ph
    JOIN Products p ON ph.ProductId = p.ProductId
    JOIN ProductionOrder po ON ph.ProductionOrderID = po.ProductionOrderID
    JOIN ProductionLine pl ON po.ProductionLineId = pl.ProductionLineId
    WHERE (
            (YEAR(ph.ProducedDate) > @StartYear OR
             (YEAR(ph.ProducedDate) = @StartYear AND MONTH(ph.ProducedDate) >= @StartMonth))
            AND
            (YEAR(ph.ProducedDate) < @EndYear OR
             (YEAR(ph.ProducedDate) = @EndYear AND MONTH(ph.ProducedDate) <= @EndMonth))
        )
        AND (@ProductionLineId IS NULL OR pl.ProductionLineId = @ProductionLineId)
    GROUP BY p.ProductId, p.ProductName, pl.ProductionLineId
    HAVING
        (@MinDefectRate IS NULL OR
         CAST(
            CASE
                WHEN (SUM(ph.Quantity) + SUM(ph.RejectedQuantity)) = 0 THEN 0
                ELSE (SUM(ph.RejectedQuantity) * 100.0) / (SUM(ph.Quantity) + SUM(ph.RejectedQuantity))
            END AS DECIMAL(5,2)) >= @MinDefectRate)
        AND
        (@MaxDefectRate IS NULL OR
         CAST(
            CASE
                WHEN (SUM(ph.Quantity) + SUM(ph.RejectedQuantity)) = 0 THEN 0
                ELSE (SUM(ph.RejectedQuantity) * 100.0) / (SUM(ph.Quantity) + SUM(ph.RejectedQuantity))
            END AS DECIMAL(5,2)) <= @MaxDefectRate)
    ORDER BY DefectRatePercent DESC;
END
go
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
CREATE   PROCEDURE dbo.usp_ReduceAllocatedHoursFromEnd
    @ProductionLineId INT,
    @HoursToReduce DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @RemainingHours DECIMAL(18,2) = @HoursToReduce;
    DECLARE @TargetDate DATE;
    DECLARE @CurrentAllocated DECIMAL(18,2);

    -- Pętla działa dopóki mamy godziny do odjęcia
    WHILE @RemainingHours > 0.01 -- Tolerancja dla zaokrągleń
    BEGIN
        -- Znajdź ostatni dzień, który ma jeszcze jakieś godziny
        SELECT TOP 1
            @TargetDate = [Date],
            @CurrentAllocated = HoursAllocated
        FROM ProductionLineTimeAllocation
        WHERE ProductionLineId = @ProductionLineId
          AND HoursAllocated > 0
        ORDER BY [Date] DESC;

        -- Jeśli nie ma już zaalokowanych godzin w żadnym dniu, kończymy
        IF @TargetDate IS NULL BREAK;

        IF @CurrentAllocated >= @RemainingHours
        BEGIN
            -- Dzisiejsza alokacja wystarczy, by pokryć redukcję
            UPDATE ProductionLineTimeAllocation
            SET HoursAllocated = @CurrentAllocated - @RemainingHours
            WHERE ProductionLineId = @ProductionLineId AND [Date] = @TargetDate;

            SET @RemainingHours = 0;
        END
        ELSE
        BEGIN
            -- Czyścimy ten dzień do zera i przechodzimy do poprzedniego
            UPDATE ProductionLineTimeAllocation
            SET HoursAllocated = 0
            WHERE ProductionLineId = @ProductionLineId AND [Date] = @TargetDate;

            SET @RemainingHours = @RemainingHours - @CurrentAllocated;
        END
    END
END
go
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
CREATE   PROCEDURE dbo.usp_RescheduleProductionLine
    @ProductionLineId INT,
    @AnchorDate DATETIME,  -- Data, od której zaczynamy układać kolejne zlecenia
    @ExcludedOrderId INT = NULL -- ID zlecenia, które wywołało zmianę (żeby go nie przesuwać)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @nextID INT;
    DECLARE @nextMinutes INT;
    DECLARE @currentAnchor DATETIME = @AnchorDate;

    -- Kursor pobierający wszystkie aktywne zlecenia po dacie zakotwiczenia
    DECLARE curNext CURSOR LOCAL FOR
    SELECT
        po.ProductionOrderId,
        CAST(po.Quantity * p.EstimatedProductionTime * 60 AS INT)
    FROM ProductionOrder po
    INNER JOIN Products p ON po.ProductId = p.ProductId
    WHERE po.ProductionLineId = @ProductionLineId
      AND po.PlannedStartDate >= @AnchorDate -- Bierzemy wszystko od punktu startu
      AND (@ExcludedOrderId IS NULL OR po.ProductionOrderId <> @ExcludedOrderId)
      AND po.ProductionOrderStatus NOT IN (3, 4) -- Pomijamy zakończone i anulowane
    ORDER BY po.PlannedStartDate ASC;

    OPEN curNext;
    FETCH NEXT FROM curNext INTO @nextID, @nextMinutes;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @calcEnd DATETIME;

        -- Wyliczamy nowy koniec przy użyciu funkcji kalendarzowej
        SET @calcEnd = dbo.AddProductionTime(@currentAnchor, @nextMinutes, @ProductionLineId);

        UPDATE ProductionOrder
        SET
            PlannedStartDate = @currentAnchor,
            PlannedEndDate = @calcEnd
        WHERE ProductionOrderId = @nextID;

        -- Następne zamówienie zaczyna się tam, gdzie skończyło się obecne
        SET @currentAnchor = @calcEnd;

        FETCH NEXT FROM curNext INTO @nextID, @nextMinutes;
    END

    CLOSE curNext;
    DEALLOCATE curNext;
END
go
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
CREATE   PROCEDURE dbo.usp_RemoveProductQuantityFromOrders
    @ProductId INT,
    @QuantityToRemove INT,
    @ProductionLineId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AvailableToRelease INT;
    DECLARE @RemainingToDelete INT = @QuantityToRemove;
    DECLARE @CurrentOrderID INT;
    DECLARE @OrderQty INT;
    Declare @ProductionSum int
    Declare @TotalSum int
    -- 1. Walidacja rezerwacji
    select TOP 1 @ProductionSum=sum(Quantity-QuantityProduced)
    from ProductionOrder
    inner join Products
    on ProductionOrder.ProductId = Products.ProductId
    where ProductionLineId=@ProductionLineId
    and ProductionOrder.ProductId=@ProductId
    
    select @TotalSum=Available+@ProductionSum-Reserved
    from Products
    where ProductId=@ProductId
    
    select @QuantityToRemove,@TotalSum,@ProductionSum
    IF @QuantityToRemove > @TotalSum or @QuantityToRemove>@ProductionSum
    BEGIN
        RAISERROR('BŁĄD: Brak wystarczającej ilości produktów.', 16, 1);

    END

    -- 2. Kursor pobierający zamówienia
    DECLARE cur CURSOR LOCAL FOR
    SELECT ProductionOrderId, Quantity
    FROM ProductionOrder
    WHERE ProductId = @ProductId
      AND (@ProductionLineId IS NULL OR ProductionLineId = @ProductionLineId)
      AND ProductionOrderStatus IN (1, 2)
    ORDER BY PlannedStartDate DESC;

    OPEN cur;
    FETCH NEXT FROM cur INTO @CurrentOrderID, @OrderQty;

    BEGIN TRY
        BEGIN TRANSACTION;

        WHILE @@FETCH_STATUS = 0 AND @RemainingToDelete > 0
        BEGIN
            IF @OrderQty <= @RemainingToDelete
            BEGIN
                -- USUWANIE CAŁKOWITE
                DELETE FROM ProductionOrder WHERE ProductionOrderId = @CurrentOrderID;
                SET @RemainingToDelete = @RemainingToDelete - @OrderQty;

                
            END
            ELSE
            BEGIN
                -- USUWANIE CZĘŚCIOWE (UPDATE)
                -- Zmieniamy ilość w zamówieniu o brakującą różnicę
                UPDATE ProductionOrder
                SET Quantity = Quantity - @RemainingToDelete
                WHERE ProductionOrderId = @CurrentOrderID;


                SET @RemainingToDelete = 0;
            END

            FETCH NEXT FROM cur INTO @CurrentOrderID, @OrderQty;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    CLOSE cur;
    DEALLOCATE cur;
END
go
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
CREATE FUNCTION dbo.AddProductionTime (
    @startDate DATETIME, 
    @minutesToAdd INT, 
    @productionLineId INT
)
RETURNS DATETIME
AS
BEGIN
    DECLARE @currentAnchor DATETIME = @startDate;
    DECLARE @remainingMinutes DECIMAL(18,2) = @minutesToAdd;
    DECLARE @resultDateTime DATETIME;

    WHILE @remainingMinutes > 0
    BEGIN
        DECLARE @actualShiftEnd DATETIME;
        DECLARE @factor DECIMAL(10,4);

        -- 1. Pobieramy dane zmiany i wydajność
        SELECT TOP 1 
            @actualShiftEnd = CAST(CAST([date] AS DATETIME) + CAST(ShiftEnd AS DATETIME) AS DATETIME),
            @factor = dbo.CalculateEfficiencyFactor([date], @productionLineId)
        FROM ProductionLineTimeAllocation
        WHERE ProductionLineId = @productionLineId 
          AND [date] = CAST(@currentAnchor AS DATE);

        -- Zabezpieczenie przed dzieleniem przez zero
        IF @factor IS NULL OR @factor = 0 SET @factor = 1;

        -- 2. Ile minut ZEGAROWYCH zostało do końca zmiany
        DECLARE @clockMinutesToShiftEnd INT = DATEDIFF(MINUTE, @currentAnchor, @actualShiftEnd);

        -- 3. Ile minut PRODUKCYJNYCH (efektywnych) zmieścimy do końca zmiany?
        DECLARE @effectiveMinutesAvailableToday DECIMAL(18,2) = @clockMinutesToShiftEnd * @factor;

        IF @effectiveMinutesAvailableToday >= @remainingMinutes
        BEGIN
            -- DZIEŃ OSTATNI:
            -- Musimy przeliczyć pozostałe minuty produkcyjne na ZEGAROWE
            -- Przykład: zostało 480 min prod / 16.6 factor = ~29 min zegarowych
            DECLARE @clockMinutesToUse INT = CEILING(@remainingMinutes / @factor);
            
            SET @resultDateTime = DATEADD(MINUTE, @clockMinutesToUse, @currentAnchor);
            SET @remainingMinutes = 0;
        END
        ELSE
        BEGIN
            -- SKOK DO JUTRA:
            -- Zużywamy cały dostępny czas produkcyjny dzisiaj
            SET @remainingMinutes = @remainingMinutes - @effectiveMinutesAvailableToday;

            -- Szukamy początku kolejnej zmiany
            SELECT TOP 1 
                @currentAnchor = CAST(CAST([date] AS DATETIME) + CAST(ShiftStart AS DATETIME) AS DATETIME)
            FROM ProductionLineTimeAllocation
            WHERE ProductionLineId = @productionLineId 
              AND [date] > CAST(@currentAnchor AS DATE)
            ORDER BY [date] ASC;

            IF @@ROWCOUNT = 0 
            BEGIN 
                SET @resultDateTime = @actualShiftEnd; 
                SET @remainingMinutes = 0; 
            END
        END
    END
    RETURN @resultDateTime;
END
go





