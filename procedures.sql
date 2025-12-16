CREATE procedure RedirectAndCreateNewOrder
@ProductID int ,
@EndDate date,
@Quantity int,
@CalculatedDate date output
as
    set nocount on
    DECLARE @UnitProductionTime decimal(3,1)
    DECLARE @ProductionLineID int

    select
           @UnitProductionTime=EstimatedProductionTime,
           @ProductionLineID=ProductionLineId
    from Products p
    inner join ProductCategories cat on p.ProductCategoryId = cat.ProductCategoryID
    inner join ProductionLine pt on cat.ProductCategoryID = pt.ProductCategoryId
    Where ProductId=@ProductID

--     ----------------------------------------------
--      Try to redirect existing Production Orders
--     ----------------------------------------------
    Declare @CandidateOrders table(
        RowID int identity(1,1),
        ProductionOrderID int,
        AvailableQuantity int,
        PlannedEndDate date,
        QuantityToUse int
    );

    INSERT INTO @CandidateOrders(ProductionOrderID, AvailableQuantity, PlannedEndDate)
    select ProductionOrderID,Quantity-QuantityAllocated,PlannedEndDate
    from ProductionOrder po
    inner join ProductionOrderStatus ps on po.ProductionOrderStatus = ps.ProductionOrderStatus
    where
        Quantity>QuantityAllocated and
        Status<>'Gotowe' and
        ProductId=@ProductID and
        PlannedStartDate<=@EndDate
    order by PlannedStartDate ASC

    DECLARE @RemaingingQuantity int = @Quantity

    DECLARE @CurrentPO_ID INT;
    DECLARE @CurrentPO_Available INT;
    DECLARE @CurrentPO_FinishDate DATE;
    DECLARE @CurrentPO_RowID INT = 1;

    while @RemaingingQuantity>0 and EXISTS (select 1 from @CandidateOrders where RowID=@CurrentPO_RowID)
    begin
        select
            @CurrentPO_Available=AvailableQuantity,
            @CurrentPO_FinishDate=PlannedEndDate,
            @CurrentPO_ID=ProductionOrderID
        from @CandidateOrders
        where RowID=@CurrentPO_RowID

        IF @CurrentPO_Available>=@RemaingingQuantity
        begin
--             this production order will satisfy all remainging quantity
                Update @CandidateOrders
                set QuantityToUse=@RemaingingQuantity where RowID=@CurrentPO_RowID


                EXEC CalculateWhenQuantityOfProductWillBeProduced @UnitProductionTime = @UnitProductionTime,@ProductionOrderID = @CurrentPO_ID, @EndDate = @CurrentPO_FinishDate, @Quantity = @RemaingingQuantity, @ProductionLineID = @ProductionLineID, @CalculatedDate = @CalculatedDate output
                set @RemaingingQuantity=0

        end
        ELSE
            begin
                Update @CandidateOrders
                set QuantityToUse=@CurrentPO_Available where RowID=@CurrentPO_RowID
                set @RemaingingQuantity-=@CurrentPO_Available
            end
        set @CurrentPO_RowID+=1

    end
    update pd
    set QuantityAllocated = QuantityAllocated+QuantityToUse
    from ProductionOrder pd
    inner join @CandidateOrders cd on pd.ProductionOrderID=cd.ProductionOrderID

    IF @RemaingingQuantity>0
-- ------------------------------------------------------------------------------------------------
--        Cant redirect all quantity to existing productionOrders, so create new ProductionOrder
--  ------------------------------------------------------------------------------------------------
    BEGIN
        EXEC CreateNewOrder @Deadline = @EndDate,@Quantity = @RemaingingQuantity,@QuantityAllocated = @RemaingingQuantity,@ProductID = @ProductID,@ProductionLineID = @ProductionLineID,@ReturnDate = @CalculatedDate OUTPUT
    end
go

CREATE   procedure CalculateWhenQuantityOfProductWillBeProduced
@UnitProductionTime int,
@ProductionOrderID int,
@EndDate date,
@Quantity int,
@ProductionLineID int,
@CalculatedDate date OUTPUT
as
    set nocount on

--      when does production start
    DECLARE @ProductionStartDate datetime
--      Total amount to be produced
    DECLARE @TotalToBeProduced int
    DECLARE @freeHours int
--      Get when production started
    select @ProductionStartDate=PlannedStartDate,
           @TotalToBeProduced=@Quantity+QuantityAllocated
    from ProductionOrder
    where ProductionOrderID=@ProductionOrderIDs


--         Get how many hours line was working on first day
    select @freeHours=datediff(hour,cast(@ProductionStartDate as time),ShiftEnd)-DowntimeHours
    from ProductionLineTimeAllocation
    where Date=cast(@ProductionStartDate as date) and
          ProductionLineId=@ProductionLineID
  
    ;WITH capactiy as (
        select
            pta.Date,
            ph.Quantity as RealQuantity,
            IIF(Date=cast(@ProductionStartDate as date),CAST(@freeHours/@UnitProductionTime as decimal(10,2)),cast((pta.HoursTotal-DowntimeHours)/@UnitProductionTime as decimal(10,2))) as DailyCapacity
        from ProductionLineTimeAllocation pta
        left join ProductionHistory ph on ph.ProductionOrderID=@ProductionOrderID and ph.ProducedDate=Date
        where Date>=cast(@ProductionStartDate as date)
        and pta.Date<=@EndDate
        and pta.ProductionLineId=@ProductionLineID

    ), cumulativeCapacity as (
        SELECT
                Date,
                coalesce(RealQuantity,DailyCapacity) as DailyCapacity,
                SUM(coalesce(RealQuantity,DailyCapacity)) OVER (ORDER BY Date ASC) AS CumulatedQuantity
            FROM capactiy
    )

     select TOP 1 @CalculatedDate=Date
     from cumulativeCapacity
     where CumulatedQuantity>=@TotalToBeProduced
go

CREATE procedure CreateNewOrder
--     Maximum date when ProductionOrder will end
@Deadline date,
--     Quantity to produce
@Quantity int,
--     It declares if we crate order to restock shortages or we create order to satify customer demand

@ProductID int,
@ProductionLineID int,
@QuantityAllocated int=0,
--     Date when Production Order will end
@ReturnDate date output
as
--     When production will start
    DECLARE @ProductionStartDate datetime
--     When production will end
    DECLARE @ProductionEndDate datetime
--     Hours available to produce in first day
    DECLARE @HoursAvailableAtFirstDay decimal(10,2)
--     Hours needed to produce at the last day
    DECLARE @HoursAtTheLastDay decimal(10,2)
--     Status of Production Order. If there are no Production Orders planned on this line we can start producing immediately
    DECLARE @ProductionOrderStatus int
--     Today's date
    DECLARE @CurrentDate date
--      Estimated time to produce @Quantity of Product
    DECLARE @EstimatedTime decimal(10,2)

--         Get date of last Production Order
    select @ProductionStartDate=max(PlannedEndDate)
    from ProductionOrder pd
    inner join ProductionOrderStatus ps on pd.ProductionOrderStatus = ps.ProductionOrderStatus
    where
        ProductionLineId=@ProductionLineID
        and ps.Status<>'Wyprodukowane'
        and ps.Status<>'Anulowane'
    set @CurrentDate = cast(getdate() as date)
    
    select @ProductionOrderStatus=ProductionOrderStatus from ProductionOrderStatus where Status='Planowane'
-- If it's null production line is currently not producing anything
    IF @ProductionStartDate IS NULL
        begin
--      We start production from next full hour
        set @ProductionStartDate=dateadd(hour,datediff(hour,0,getdate())+1,0)
--      If line is not currently operating we can immediately start new production
        select @ProductionOrderStatus=ProductionOrderStatus from ProductionOrderStatus where Status='W toku'

        end


--     Estimate time needed to produce @Quantity of Product
    select @EstimatedTime=@Quantity*EstimatedProductionTime from Products where ProductId=@ProductID

--     Check if ProductionLine can produce at that day


    select TOP 1
        @ProductionStartDate=IIF(Date<>cast(@ProductionStartDate as date) or cast(@ProductionStartDate as time) >= ShiftEnd or  cast(@ProductionStartDate as time)<ShiftStart,dateadd(hour,datepart(hour,ShiftStart),cast(Date as datetime2(0))),@ProductionStartDate),
        @HoursAvailableAtFirstDay=datediff(hour,cast(@ProductionStartDate as time),ShiftEnd)-DowntimeHours
    from ProductionLineTimeAllocation where Date>=cast(@ProductionStartDate as date) and ProductionLineId=@ProductionLineID and HoursTotal-HoursAllocated>0


--     Generate cumulative sum of available hours from @ProductionStartDay to @EndDate
    ;with TimeSlots as(
        select
            @ProductionStartDate as Date,
            @HoursAvailableAtFirstDay as Available
        from ProductionLineTimeAllocation
        where Date=cast(@ProductionStartDate as date)
        and ProductionLineId=@ProductionLineID

        union ALL
        select
            Date,
            (HoursTotal-HoursAllocated-DowntimeHours) as Available
        from ProductionLineTimeAllocation
        where ProductionLineId=@ProductionLineID
        and Date<=@Deadline
        and Date>@ProductionStartDate
    ), cumulativeTime as (
        select
            Date,
            sum(Available) over (ORDER BY Date ASC) as CumulativeAvailable
        from TimeSlots
    )
--      Select first date when production will be satisfied
    select TOP 1 @ProductionEndDate=Date from cumulativeTime where CumulativeAvailable>=@EstimatedTime
    set @ReturnDate=@ProductionEndDate

   -- If we can't produce @Quantity of product before @EndDate return
     IF @ProductionEndDate is null
        begin
            return
        end

-- Calculate how many hours is needed to finish production at the last day
    select @HoursAtTheLastDay=@EstimatedTime-coalesce(SUM(HoursTotal-DowntimeHours),0)-@HoursAvailableAtFirstDay
    from ProductionLineTimeAllocation
    where Date>@ProductionStartDate
    and Date<@ProductionEndDate
    and ProductionLineId=@ProductionLineID
    print @HoursAtTheLastDay



--         If @ProductionStartDate=@ProductionEndDate add @EstimatedHours to @ProductionStartDate to keep integrity of Dates
    IF cast(@ProductionStartDate as date) = cast(@ProductionEndDate as date)
        begin
            set @ProductionEndDate=dateadd(hour,@EstimatedTime,@ProductionStartDate)
        end
    ELSE
        Begin
--             If dates are different add @HoursAtTheLastDay to when shift start at the last day of production
            DECLARE @ShiftStartLastDayOfProduction time(0)
            DECLARE @Hours int
            DECLARE @Minutes int
            select
                @ShiftStartLastDayOfProduction=ShiftStart 
            from ProductionLineTimeAllocation
            where
                Date=cast(@ProductionEndDate as date)
                and ProductionLineId=@ProductionLineID
            set @Hours=FLOOR(@HoursAtTheLastDay)
            set @Minutes=60*(@HoursAtTheLastDay-@Hours)

            set @ProductionEndDate = dateadd(minute,@Minutes,dateadd(hour,datepart(hour,@ShiftStartLastDayOfProduction)+@Hours,@ProductionEndDate))
        end



-- Update time in ProductionLineTimeAllocation
    UPDATE ProductionLineTimeAllocation
    set HoursAllocated =
        CASE
--             if production starts and ends at the same date, just add @EstimatedTime to already allocated Hours at that day
            WHEN Date=cast(@ProductionStartDate as date) then IIF(HoursTotal - HoursAllocated - DowntimeHours > @EstimatedTime,
                                                    HoursAllocated + @EstimatedTime
                                                    , HoursTotal)
            WHEN Date=cast(@ProductionEndDate as date) then @HoursAtTheLastDay
--             Date between @ProductionStartDate and @ProductionEndDate we use all working hours
            WHEN Date>@ProductionStartDate and Date<@ProductionEndDate then HoursTotal
--          Do nothing
            ELSE HoursAllocated
        END
    where ProductionLineId=@ProductionLineID
    and date >= cast(@ProductionStartDate as date)
    and date<= cast(@ProductionEndDate as date)
-- Add new ProductionOrder with calculatedvalues
    insert into ProductionOrder(ProductionLineId, ProductionOrderStatus, ProductId, Quantity, QuantityProduced, QuantityAllocated, AddedDate, PlannedStartDate, PlannedEndDate)
    values
        (@ProductionLineID,@ProductionOrderStatus,@ProductID,@Quantity,0,@QuantityAllocated,@CurrentDate,@ProductionStartDate,@ProductionEndDate)
go


-- TOTAL ORDER VALUE
CREATE FUNCTION CalculateOrderValue_FN
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