
DECLARE @StartDate DATE = '2024-01-01';
DECLARE @EndDate DATE = '2027-12-15';
DECLARE @MidDate DATE = '2025-12-15'; 
DECLARE @LINES_COUNT INT = 7;
DECLARE @FIXED_HOURS INT = 200;

WITH DateSeries (AllocationDate) AS
(
    SELECT @StartDate
    UNION ALL
    SELECT DATEADD(day, 1, AllocationDate)
    FROM DateSeries
    WHERE AllocationDate < @EndDate
)
INSERT INTO ProductionLineTimeAllocation (ProductionLineId, HoursTotal, HoursAllocated, DowntimeHours, Date, ShiftStart, ShiftEnd)
SELECT
    p.ProductionLineId,
    
    @FIXED_HOURS AS HoursTotal,
    
    CASE 
        WHEN d.AllocationDate <= @MidDate THEN @FIXED_HOURS
        ELSE 0
    END AS HoursAllocated,
    
    0 AS DowntimeHours,
    d.AllocationDate AS Date,
    '08:30:00' AS ShiftStart,
    '20:30:00' AS ShiftEnd
FROM 
    ProductionLine p
CROSS JOIN 
    DateSeries d
ORDER BY 
    d.AllocationDate, p.ProductionLineId
OPTION (MAXRECURSION 0);