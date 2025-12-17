SET IDENTITY_INSERT OrderStatus ON;
INSERT INTO OrderStatus (OrderStatusID, OrderStatusName) VALUES
(1, 'Nieopłacone'),
(2, 'Opłacone'),
(3, 'W realizacji'),
(4, 'Gotowe do wysyłki'),
(5, 'Zrealizowane'),
(6, 'Anulowane');

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
(2, 'Biznes');

SET IDENTITY_INSERT CustomerType OFF;