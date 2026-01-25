CREATE OR ALTER VIEW v_OrderSummary AS
SELECT
    o.OrderID,
    o.OrderDate,
    c.CustomerName,
    ct.TypeName AS CustomerType,
    os.OrderStatusName,
    dbo.CalculateOrderValue_FN(o.OrderId) AS TotalOrderValue,
    COUNT(od.ProductId) AS UniqueProductsCount,
    SUM(od.Quantity) AS TotalProductsCount,
    o.ShipCity,
    o.ShipCountry
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN CustomerType ct ON c.CustomerType = ct.TypeID
JOIN OrderStatus os ON o.Status = os.OrderStatusID
JOIN OrderDetails od ON o.OrderID = od.OrderID
GROUP BY
    o.OrderID, o.OrderDate, c.CustomerName, ct.TypeName,
    os.OrderStatusName, o.ShipCity, o.ShipCountry;
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE VIEW v_ProductCostAnalysis AS
SELECT
    p.ProductName,
    pc.CategoryName,
    p.CurrentSellPrice,
    p.CurrentProductionCost AS DefinedCost,
    SUM(pd.Quantity * pt.PartPrice) AS CalculatedMaterialCost,
    (p.CurrentSellPrice - p.CurrentProductionCost) AS EstimatedMargin,
    (p.CurrentProductionCost - SUM(pd.Quantity * pt.PartPrice)) AS NonMaterialCost
FROM Products p
JOIN ProductCategories pc ON p.ProductCategoryId = pc.ProductCategoryID
JOIN ProductsDetails pd ON p.ProductId = pd.ProductId
JOIN Parts pt ON pd.PartId = pt.PartId
GROUP BY
    p.ProductId, p.ProductName, pc.CategoryName, p.CurrentSellPrice, p.CurrentProductionCost;
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE VIEW v_ProductionQueue AS
SELECT
    po.ProductionOrderID,
    po.ProductionOrderStatus,
    pos.Status,
    p.ProductName,
    po.Quantity,
    po.QuantityProduced,
    pl.ProductionLineId,
    po.PlannedStartDate,
    po.PlannedEndDate,
    CASE
        WHEN pos.Status = 'Zakonczone' THEN 'Zakończone'
        WHEN pos.Status = 'Odrzucone' THEN 'Odrzucone'
        WHEN GETDATE() > po.PlannedEndDate THEN 'OPÓŹNIONE'
        WHEN pos.Status = 'Wstrzymane' THEN 'Wstrzymane'
        ELSE 'W terminie'
    END AS ScheduleStatus
FROM ProductionOrder po
JOIN Products p ON po.ProductId = p.ProductId
JOIN ProductionOrderStatus pos ON po.ProductionOrderStatus = pos.ProductionOrderStatus
JOIN ProductionLine pl ON po.ProductionLineId = pl.ProductionLineId;
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE VIEW v_MaterialRequirements AS
SELECT
    pt.PartName,
    pc.CategoryName,
    SUM(po.Quantity * pd.Quantity) AS TotalQuantityRequired,
    pt.PartPrice AS UnitPrice,
    SUM(po.Quantity * pd.Quantity * pt.PartPrice) AS TotalEstimatedMaterialCost
FROM ProductionOrder po
JOIN ProductsDetails pd ON po.ProductId = pd.ProductId
JOIN Parts pt ON pd.PartId = pt.PartId
JOIN PartsCategories pc ON pt.PartCategoryId = pc.PartCategoryId
WHERE
    po.ProductionOrderStatus IN (1, 2, 4)
GROUP BY
    pt.PartId, pt.PartName, pc.CategoryName, pt.PartPrice;
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE VIEW v_StockShortages AS
SELECT
    p.ProductName,
    p.Available AS InStock,
    p.Reserved,
    p.MinimalQuantity,
    (p.Available - p.Reserved) AS RealAvailable,

    CASE
        WHEN (p.Available - p.Reserved) < 0
        THEN 'Brak na stanie'
        WHEN (p.Available - p.Reserved) < p.MinimalQuantity
        THEN 'Niski stan'
    END AS StockStatus,
    (p.MinimalQuantity - (p.Available - p.Reserved)) AS MissingQuantity
FROM Products p
WHERE (p.Available - p.Reserved) < p.MinimalQuantity;
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE VIEW v_UnpaidOrders AS
SELECT
    v.OrderID,
    v.CustomerName,
    v.OrderDate,
    v.TotalOrderValue,
    ISNULL(SUM(pay.Amount), 0) AS TotalPaid,
    (v.TotalOrderValue - ISNULL(SUM(pay.Amount), 0)) AS RemainingBalance,
    CASE
        WHEN ISNULL(SUM(pay.Amount), 0) = 0 THEN 'Brak wpłaty'
        WHEN ISNULL(SUM(pay.Amount), 0) < v.TotalOrderValue THEN 'Częściowo opłacone'
    END AS PaymentStatus
FROM v_OrderSummary v
LEFT JOIN Payments pay ON v.OrderID = pay.OrderID
GROUP BY
    v.OrderID, v.CustomerName, v.OrderDate, v.TotalOrderValue
HAVING (v.TotalOrderValue - ISNULL(SUM(pay.Amount), 0)) > 0;
GO