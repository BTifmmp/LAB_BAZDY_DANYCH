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
           @EstimatedTime=EstimatedProductionTime*(@Quantity)
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
            @freeHours  as DailyCapacity
        from ProductionLineTimeAllocation pta
        left join ProductionHistory ph on ph.ProductionOrderID=@ProductionOrderID and ph.ProducedDate=Date
        where Date=cast(@ProductionStartDate as date)
        and pta.ProductionLineId=@ProductionLineID
        UNION ALL
        select
            pta.Date,
            ph.Quantity as RealQuantity,
            pta.HoursTotal-DowntimeHours as DailyCapacity
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
     where CumulatedQuantity>=@EstimatedTime

    return @Finishday


    end
go
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE procedure CreateNewOrder
@Deadline date,
@Quantity int,
@ProductID int
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
        and ps.Status not in('Gotowe','Anulowane')
        and HoursTotal>HoursAllocated
    

    select TOP 1 @ProductionStartDate=
           case
                when cast(@ProductionStartDate as date)<>Date
                    Then Date
                else @ProductionStartDate
            end
    from ProductionLineTimeAllocation
    where Date>=cast(@ProductionStartDate as date)
    and HoursTotal>HoursAllocated
    order by Date ASC


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
            WHEN Date=cast(@ProductionStartDate as date) then iif(@HoursAvailableAtFirstDay>@EstimatedTime,HoursAllocated+@EstimatedTime,HoursTotal)
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


CREATE procedure RedirectAndCreateNewOrder
--     Przed wywołaniem tej procedury wartość Reserved musi być zwiększona, dla tego produkutu o @Quantity
@ProductID int ,
@EndDate date
as
    set nocount on
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
           @QuantityToProduce=Reserved-Available
    from Products p
    inner join ProductCategories cat on p.ProductCategoryId = cat.ProductCategoryID
    inner join ProductionLine pt on cat.ProductCategoryID = pt.ProductCategoryId
    Where ProductId=@ProductID



--     ----------------------------------------------
--      Sprawdź czy akutalne produkcje są w stanie wypełnic wszystkie zamówwienia
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


    set @RemainingQuantity=coalesce(@RemainingQuantity,@QuantityToProduce)
    

    IF @RemainingQuantity>0 
        EXEC CreateNewOrder @Deadline = @EndDate, @Quantity = @RemainingQuantity, @ProductID = @ProductID
    ELSE
        IF  dbo.CalculateWhenQuantityOfProductWillBeProduced(@ProductionOrderID,@LastUsedQuantity)>@EndDate
            begin
                THROW 50000,N'Nie mozna wyprodukowac podanych produktow w podanym czasie',1;
            end
go
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE createCustomerOrder
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
    IF not exists(select 1 from Customers where CustomerID=@CustomerID)
        begin
            Throw 50001 ,N'Nie ma takiego Klienta', 1;
        end

    IF exists(select ProductID from @Items except select ProductId from Products)
        BEGIN
            THROW 50002 ,N'Jeden lub więcej produktów nie istnieje' ,1;
        end

    IF EXISTS(select 1 from @Items i
                inner join Products p on p.ProductId=i.ProductID
                where Removed=1)
        begin
            THROW 50004,N'Jeden lub więcej produktów zostało wycofanych',1;
        end
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
    select @OrderStatus=OrderStatusID from OrderStatus where OrderStatusName='Przyjete'
    BEGIN TRANSACTION


    Declare @OrderID int
--     Stwórz nowe zamówienie
    insert into Orders(CustomerID, Status, ShipAddress, ShipCountry, ShipCity, ShipRegion, ShipPostalCode, OrderDate)
    values
        (@CustomerID,@OrderStatus,@ShipAddress,@ShipCountry,@ShipCity,@ShipRegion,@ShipPostalCode,cast(getdate() as date))


    set @OrderID=SCOPE_IDENTITY();

--     Dodaj pozycje zamówienia
    insert into OrderDetails(OrderID, ProductId, Quantity, UnitPrice, Discount)
    select @OrderID,I.ProductId,i.Quantity,p.CurrentSellPrice,i.Discount
    from @Items i
    inner join Products p on i.ProductID=p.ProductId

--     Zarezewuj wszystkie produkty
    update Products
    set Reserved=Reserved+Quantity
    from @Items i
    where Products.ProductId=i.ProductID

    insert into ProductReservation(ProductID, OrderID, Quantity)
    select ProductID,@OrderID,Quantity
    from @Items

--     Dodaj wszystkie produkty do cursora, których dostępna ilość nie wystarcza na to zamówienie

    DECLARE productCursor cursor keyset FOR 
    select i.ProductId,i.Quantity from @Items i inner join Products p on i.ProductID=p.ProductId where Available-Reserved<0

    open productCursor

    if @@CURSOR_ROWS=0
        begin
--         Wszystkie produkty są dostępne w magazyanie
            close productCursor
            deallocate productCursor
            update Orders
            set Status=(select OrderStatusID from OrderStatus where OrderStatusName='Gotowe do wysylki')
            where OrderID=@OrderID
            commit transaction 
            return
        end


    DECLARE @CurrentProductID int
    DECLARE @CurrentQuantity int



    begin try

        FETCH NEXT from productCursor into @CurrentProductID,@CurrentQuantity
        while @@FETCH_STATUS = 0
        begin
            exec RedirectAndCreateNewOrder @ProductID = @CurrentProductID, @EndDate = @Deadline
            
            FETCH NEXT FROM productCursor into @CurrentProductID,@CurrentQuantity
        end
        
    end try
    begin catch
        
        close productCursor
        deallocate productCursor
        rollback transaction;
        
        THROW 50000,N'Nie mozna wyprodukowac podanych produktow w podanym czasie',1;

    end catch
    close productCursor
    deallocate productCursor
--   Jeśli nie wyłapano żadnego błędu można przyjąć zamówienie
    commit transaction
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