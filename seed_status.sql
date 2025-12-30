SET IDENTITY_INSERT OrderStatus ON;
INSERT INTO OrderStatus (OrderStatusID, OrderStatusName) VALUES
(1, 'Nieopłacone'),
(2, 'Opłacone'),
(3, 'Gotowe do wysyłki'),
(4, 'Zrealizowane'),
(5, 'Anulowane');

SET IDENTITY_INSERT OrderStatus OFF;


SET IDENTITY_INSERT ProductionOrderStatus ON;

INSERT INTO ProductionOrderStatus (ProductionOrderStatus, Status) VALUES
(1, 'Planowane'),
(2, 'W toku'),
(3, 'Wyprodukowane'),
(4, 'Anulowane');

SET IDENTITY_INSERT ProductionOrderStatus OFF;

SET IDENTITY_INSERT CustomerType ON;
INSERT INTO CustomerType (TypeId, TypeName) VALUES
(1, 'Indywidualny'),
(2, 'Bizens');

SET IDENTITY_INSERT CustomerType OFF;