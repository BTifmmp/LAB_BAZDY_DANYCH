
-- PRODUCT CATEGORIES
SET IDENTITY_INSERT ProductCategories ON;
INSERT INTO ProductCategories (ProductCategoryId, CategoryName) VALUES
(1, 'Biurka i Stoły'),
(2, 'Krzesła i Fotele'),
(3, 'Meble Dydaktyczne'),
(4, 'Akcesoria IT'),
(5, 'Przechowanie');
SET IDENTITY_INSERT ProductCategories OFF;

-- PRODUCTS
SET IDENTITY_INSERT Products ON;
INSERT INTO Products (ProductId, ProductCategoryId, ProductName, EstimatedProductionTime, CurrentProductionCost, CurrentSellPrice, Available, Reserved, MinimalQuantity) VALUES
-- Biurka i Stoły (ID 1)
(1, 1, 'Biurko Regulowane', 9.0, 450.00, 1199.00, 50, 10, 20),
(2, 1, 'Stół Konferencyjny', 15.0, 780.00, 1999.00, 25, 5, 10),
(3, 1, 'Biurko Gamingowe LED', 8.0, 480.00, 1099.00, 70, 12, 35),
(4, 1, 'Biurko Narożne', 10.0, 550.00, 1399.00, 40, 8, 15),

-- Krzesła i Fotele (ID 2)
(5, 2, 'Fotel Obrotowy', 6.0, 220.00, 549.00, 150, 30, 75),
(6, 2, 'Fotel Gamingowy RGB', 7.5, 350.00, 859.00, 90, 18, 45),
(7, 2, 'Fotel Dyrektorski', 8.5, 400.00, 999.00, 30, 5, 15),
(8, 2, 'Krzesło Konferencyjne', 3.0, 75.00, 179.00, 300, 60, 150),

-- Meble Dydaktyczne (ID 3)
(09, 3, 'Ławka Dydaktyczna Podwójna', 7.0, 280.00, 699.00, 80, 15, 40),
(10, 3, 'Krzesło Do Ławki', 7.0, 280.00, 699.00, 80, 15, 40),
(11, 3, 'Krzesło Audytoryjne', 3.5, 90.00, 199.00, 400, 80, 200),
(12, 3, 'Stół Laboratoryjny', 14.0, 650.00, 1599.00, 20, 3, 5),
(13, 3, 'Krzesło Składane', 2.0, 55.00, 129.00, 500, 100, 250),

-- Akcesoria IT (ID 4)
(14, 4, 'Tablica Interaktywna', 5.0, 180.00, 449.00, 60, 10, 30),
(15, 4, 'Uchwyt Biurkowy 2x Monitor', 2.0, 65.00, 159.00, 150, 30, 75),
(16, 4, 'Organizator Kabli Podbiurkowy', 1.5, 30.00, 69.00, 250, 50, 125),
(17, 4, 'Akcesoryjny Uchwyt na Słuchawki', 1.0, 15.00, 39.00, 600, 120, 300),

-- Przechowanie (ID 5)
(18, 5, 'Szafa Aktowa Wysoka', 12.0, 380.00, 899.00, 40, 5, 20),
(19, 5, 'Kontenerek Podbiurkowy', 6.0, 150.00, 329.00, 80, 10, 40),
(20, 5, 'Regał Modułowy z Półkami', 8.0, 250.00, 549.00, 60, 10, 30),
(21, 5, 'Szafa Serwerowa"', 16.0, 950.00, 2199.00, 15, 2, 5);
SET IDENTITY_INSERT Products OFF;

-- PARTS CATEGORIES
SET IDENTITY_INSERT PartsCategories ON;
INSERT INTO PartsCategories (PartCategoryId, CategoryName) VALUES
(1, 'Surowce Płytowe i Drewno'),    
(2, 'Metale i Profile Konstrukcyjne'),
(3, 'Elementy Łączące i Chemia'),
(4, 'Tapicerka i Wypełnienia'),
(5, 'Akcesoria Ruchome i Regulacje'),
(6, 'Komponenty Elektryczne i LED'); 
SET IDENTITY_INSERT PartsCategories OFF;



-- PARTS
SET IDENTITY_INSERT Parts ON;
INSERT INTO Parts (PartId, PartCategoryId, PartName, PartPrice) VALUES
(1, 1, 'Płyta Laminowana (m2)', 35.00), 
(2, 1, 'Sklejka Liściasta (m2)', 22.00),
(3, 1, 'Okleina PCV (mb)', 1.50),

-- Metale i Profile Konstrukcyjne (ID 2)
(4, 2, 'Profil Stalowy kwadratowy (mb)', 8.00),
(5, 2, 'Blacha Stalowa (m2)', 15.00),

-- Elementy Łączące i Chemia (ID 3)
(6, 3, 'Śruba M6x50 (szt.)', 0.25),
(7, 3, 'Nakrętka M6 (szt.)', 0.10),
(8, 3, 'Klej Montażowy (tuba)', 12.00),

-- Tapicerka i Wypełnienia (ID 4)
(9, 4, 'Pianka T30 (m2)', 10.00), 
(10, 4, 'Siatka Tapicerska (m2)', 18.00),
(11, 4, 'Tkanina Obiciowa Premium (mb)', 28.00),

-- Akcesoria Ruchome i Regulacje (ID 5)
(12, 5, 'Kółko jezdne (szt.)', 2.50),
(13, 5, 'Prowadnica Szuflady L-400 (para)', 10.00),
(14, 5, 'Podnośnik Gazowy (szt.)', 35.00),

-- Komponenty Elektryczne i LED (ID 6)
(15, 6, 'Taśma LED RGB (mb)', 4.00),
(16, 6, 'Zasilacz 12V 5A (szt.)', 15.00);
SET IDENTITY_INSERT Parts OFF;


-- PRODUCT DETAILS

INSERT INTO ProductsDetails (ProductId, PartId, Quantity) VALUES
-- Biurka i Stoły (ID 1-4)
(1, 1, 2), 
(1, 4, 3),

(2, 1, 3),
(2, 4, 5),

(3, 1, 2),
(3, 15, 3),

(4, 1, 2),
(4, 4, 4),

-- Krzesła i Fotele (ID 5-8)
(5, 9, 1),
(5, 14, 1),

(6, 10, 1),
(6, 15, 2),

(7, 11, 3),
(7, 14, 1),

(8, 11, 1),
(8, 4, 1),

-- Meble Dydaktyczne (ID 9-13)
(9, 1, 2),
(9, 4, 4),

(10, 9, 1),
(10, 4, 1),

(11, 10, 1),
(11, 4, 1),

(12, 1, 2),
(12, 4, 3),

(13, 1, 1),
(13, 4, 1),

-- Akcesoria IT (ID 14-17)
(14, 5, 2),
(14, 16, 1),

(15, 5, 1),
(15, 6, 8),

(16, 5, 1),
(16, 6, 4),

(17, 5, 1),
(17, 8, 1),

-- Przechowanie (ID 18-21)
(18, 5, 5),
(18, 1, 1),

(19, 1, 1),
(19, 13, 2),

(20, 1, 3),
(20, 6, 20),

(21, 5, 7),
(21, 13, 4);



-- CUSTOMERS
SET IDENTITY_INSERT Customers ON;

INSERT INTO Customers (CustomerID, CustomerType, CustomerName, [Address], Country, City, Region, PostalCode, Phone) VALUES
(1, 2, 'Politechnika Wrocławska', 'Wybrzeże Wyspiańskiego 27', 'Polska', 'Wrocław', 'Dolnośląskie', '50-370', '71 320 20 00'),
(2, 2, 'Biuro Projektowe "Architekci"', 'ul. Wawelska 15', 'Polska', 'Kraków', 'Małopolskie', '31-001', '12 422 10 10'),
(3, 2, 'Esport Team "GamerHub"', 'Al. Jerozolimskie 200', 'Polska', 'Warszawa', 'Mazowieckie', '02-222', '22 654 98 76'),
(4, 1, 'Jan Nowak', 'ul. Długa 5/2', 'Polska', 'Gdańsk', 'Pomorskie', '80-800', '601 111 222'),
(5, 2, 'Szkoła Podstawowa nr 5', 'ul. Szkolna 1', 'Polska', 'Poznań', 'Wielkopolskie', '60-005', '61 878 90 00');

SET IDENTITY_INSERT Customers OFF;

-- PRODUCTION LINES
SET IDENTITY_INSERT ProductionLine ON;
INSERT INTO ProductionLine (ProductionLineId, ProductCategoryId) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4),
(5, 5);

SET IDENTITY_INSERT ProductionLine OFF;