# Podstawy baz danych

Środa 13:15\
nr zespołu: 6

**Autorzy:**\
Błażej Turczynowicz\
Kacper Mucha\
Maciej Życki

# 1. Wymagania i funkcje systemu

## Historyjki użytkowników

### 1. Klient

- US-01: Przeglądanie oferty\
  Jako klient chcę przeglądać dostępne meble w ofercie, aby wybrać produkty odpowiednie do mojego biura.
- US-02: Składanie zamówienia z magazynu\
  Jako klient chcę złożyć zamówienie na dostępne produkty, aby szybko otrzymać meble.
- US-03: Zamówienie produktów do produkcji\
  Jako klient chcę zamówić produkty, których nie ma w magazynie, aby wyposażyć nową salę konferencyjną w danym temrinie.

### 2. Sprzedaż

- US-04: Przyznawanie rabatu\
  Jako pracownik sprzedaży chcę przydzielić rabat procentowy do poszczegolnych produktow w zamówieniu klienta, aby zachęcić do większego zakupu.
- US-05: Historia zamówień klienta\
  Jako pracownik sprzedaży chcę zobaczyć historię zamówień klienta wraz z rabatami, aby lepiej go obsłużyć.
- US-06: Stan magazynowy produktów\
  Jako pracownik sprzedaży chcę sprawdzić aktualny stan magazynowy produktów gotowych, aby wiedzieć co jest dostępne do sprzedaży.

### 3. Produkcja

- US-07: Sprawdzenie dostępności części\
  Jako kierownik produkcji chcę sprawdzić dostępność części do produkcji, aby określić czy mogę rozpocząć produkcję.
- US-08: Czesci w danym meblu\
  Jako kierownik produkcji chcę mieć możliwość sprawdzenia z jakich części składa sie dany produkt, aby wiedzieć co jest potrzebne do jego produkcji.
- US-09: Estymacja czasu produkcji\
  Jako kierownik produkcji chcę oszacowany czas potrzebny na wyprodukowanie produktu, aby lepiej zaplanowac rozkład produckji.
- US-10: Zaplanowana produckja\
  Jako kierownik produkcji chcę mieć możliwość sprawdzenia mebli zaplanowanych do produckji, aby lepiej zarządzać linia produkcyjną.
- US-11 Planowanie produkcji\
  Jako kierownik produkcji chce móc planowac czas operacyjny oraz obciązenie lini produkcyjnych, aby odpowiednio rozdzielać zlecenia produckcyjne

### 4. Kadra Zarządcza

- US-12: Raport kosztów produkcji\
   Jako dyrektor finansowy chcę zobaczyć raport kosztów produkcji (jednostkowych i grup produktów) w różnych okresach, aby ustalić odpowiedni budżet.
- US-13: Raport sprzedaży\
  Jako dyrektor handlowy chcę zobaczyć raport sprzedaży oraz kosztów grup produktów w tygodniach/miesiącach, aby analizować trendy oraz ocenić rentowność.
- US-14: Plan produkcji\
  Jako dyrektor operacyjny chcę zobaczyć plan wytworzenia produktów w różnych przedziałach czasowych, aby monitorować obciążenie zakładu.

# 2. Baza danych

## Schemat bazy danych

Diagram v0\
![schemat photo0](schemat_photo0.png)

Diagram v1\
![schemat photo1](schemat_photo1.png)

## Schemat dzialania zamówień

W Tabeli Products przechowywane są informacje o aktualnym stanie magazynowym (Available), zarezerwowanych produktach (Reserved) oraz docelowej minimalnej ilości sztuk na magazynie (MinimalQuantity).Gdy pole Available-Reserved spadnie poniżej wartości MinimalQuantity, sprawdzamy czy nie ma aktualnie Production Order na te produkty. Jeśli nie ma tworzymy nowe Production Order, które uzupełni braki.

Załóżmy sytuacje że, klient zamówił:

- n sztuk produktu o id = 1
- k sztuk produktu o id = 2

Sprawdzamy aktualne stany magazynowe przez obliczenie Available-Reserved.\
Jeśli ta wartość jest większa niż n oraz k możemy wysłać te produkty natychmiastowo.\
Jeśli brakuje nam produktów na jakąkolwiek pozycje zamówienia, zwiększamy wartość Reserved we wszystkich produktach o ilość sztuk zamówionego produktu.\
Załóżmy, że brakuje nam q sztuk produktu. \
Sprawdzamy czy jesteśmy w stanie wyprodukować q sztuk do daty maksymalnego czekania podanej przez klienta.\
Na początku sprawdzamy czy mamy jakieś Production Order, które nie mają QuantityAllocated=Quantity.\
Dla każdego takiego Production Order przekierowujemy produkcje, która miała uzupełnić braki na nowe zamówienie klienta. Robiąc to kontrolujemy czas w którym wyprodukowane są brakujące produkty. Jeśli Production Order nie jest w stanie wypełnić zamówienia klienta cała jego pozostała produkcja (Quantity-QuantityAllocated) zostaje zarezerwowana przez nowe zamówienie. Robimy to do momentu aż skończą się Production Order z QuantityAllocated < Quantity lub gdy w całości zaspokoimy zapotrzebowanie na ten produkt lub przekroczymy date podaną przez klienta.\
 Gdy natrafimy na Production Order, które w całości jest w stanie pokryć zapotrzebowanie na wymaganą liczbę produktów obliczamy przybliżoną date wyprodukowania ich. To zamówienie mogło wczesniej mieć zaalokowane produkty dla innego zamówienia. Więc sprawdzamy kiedy wyprodukujemy q sztuk + QuantityAllocated. Jeśli zamówienie było już w produkcji pobieramy dane z ProductionHistory.\
Jeśli nie ma wpisu z dnia, który nas interesuje sprawdzamy szacunkową ilość wyprodukowanego produktu w ten dzień, uwzględniając godziny przestoju lini (DowntimeHours).\
Dzień w którym wyprodukujemy więcej lub tyle samo sztuk produktu co q+QuantityAllocated, jest dniem w którym możemy wysłać ten produkt.\
Załóżmy, że nie byliśmy w stanie znaleźć q sztuk do przekierowania. Po całej operacji zostaje nam x sztuk, których klient oczekuje.\
 Tworzymy nowe zlecenie na x sztuk z QuantityAllocated=x, informuje to system, że ten Production Order jest stworzony na uzupełnienie jakiegoś zamówienia i nie możemy przekierować z niego żadnego produktu. Tworząc ProductionOrder sprawdzamy czy nie zostanie przekroczona data podana przez klienta.\
Gdy spełnimy wszystkie te warunki możemy przyjąć zamówienie.

Każdy wpis w Production History, który zawiera Rejected Quantity przesuwa wszystkie trwające oraz zaplanowane produkcje na lini o RejectedQuantity\*EstimatedProductionTime w przód

### Schemat działania produkcji

W tabeli ProductionLineTimeAllocation przechowujemy informacje o wykorzystaniu danej lini w dany dzień. Gdy tworzymy nowe zamówienie, które będzie produkowane przez wiele dni sprawdzamy ile godzin w konkretnie dni linia może pracować oraz rezerwujemy je w całości. Pozwala to oszacować date zakończenia produkcji.

## Opis poszczególnych tabel

### Tabela: Status

```sql
CREATE TABLE OrderStatus (
   OrderStatusID int  NOT NULL IDENTITY(1, 1),
   OrderStatusName varchar(20)  NOT NULL,
   CONSTRAINT OrderStatus_pk PRIMARY KEY  (OrderStatusID)
);
```

| Nazwa atrybutu | Typ         | Opis/Uwagi                                                                  |
| -------------- | ----------- | --------------------------------------------------------------------------- |
| StatusID       | int         | Auto-inkrementowany klucz główny, unikalny identyfikator statusu zamówienia |
| StatusName     | varchar(20) | Nazwa statusu dla zamówień                                                  |

### Tabela: CustomerType

```sql
CREATE TABLE CustomerType (
   TypeID int  NOT NULL IDENTITY(1, 1),
   TypeName varchar(50)  NOT NULL,
   CONSTRAINT CustomerType_pk PRIMARY KEY  (TypeID)
);
```

| Nazwa atrybutu | Typ         | Opis/Uwagi                                                            |
| -------------- | ----------- | --------------------------------------------------------------------- |
| TypeID         | int         | Auto-inkrementowany klucz główny, unikalny identyfikator typu klienta |
| TypeName       | varchar(50) | Nazwa typu klienta                                                    |

### Tabela: Customers

```sql
CREATE TABLE Customers (
   CustomerID int  NOT NULL IDENTITY(1, 1),
   CustomerType int  NOT NULL,
   CustomerName varchar  NOT NULL,
   Address varchar(50)  NULL,
   Country varchar(50)  NULL,
   City varchar(50)  NULL,
   Region varchar(50)  NULL,
   PostalCode varchar(20)  NULL,
   Phone varchar(20)  NULL,
   CONSTRAINT customerID PRIMARY KEY  (CustomerID),

   CONSTRAINT CustomerType_Customers FOREIGN KEY (CustomerType)
      REFERENCES CustomerType (TypeID)
);
```

| Nazwa atrybutu | Typ         | Opis/Uwagi                                                      |
| -------------- | ----------- | --------------------------------------------------------------- |
| CustomerID     | int         | Auto-inkrementowany klucz główny unikalny identyfikator klienta |
| CustomerType   | int         | Klucz obcy,identyfikator typu klienta                           |
| Adress         | varchar(50) | Adres klienta                                                   |
| Country        | varchar(50) | Kraj klienta                                                    |
| City           | varchar(50) | Miasto klienta                                                  |
| Region         | varchar(50) | Region klienta                                                  |
| PostalCode     | varchar(20) | Kod pocztowy klienta                                            |
| Phone          | varchar(20) | Numer telefonu klienta                                          |

### Tabela: Orders

```sql
CREATE TABLE Orders (
   OrderID int  NOT NULL IDENTITY(1, 1),
   CustomerID int  NOT NULL,
   EmployeeID int  NULL,
   Status int  NOT NULL,
   ShipAddress varchar(50)  NOT NULL,
   ShipCountry varchar(50)  NOT NULL,
   ShipCity varchar(50)  NOT NULL,
   ShipRegion varchar(50)  NOT NULL,
   ShipPostalCode varchar(20)  NOT NULL,
   OrderDate date  NOT NULL,
   CompletionDate date  NULL,
   ShipDate date  NULL,
   CONSTRAINT Orders_pk PRIMARY KEY  (OrderID),

   CONSTRAINT CHK_DATE CHECK ((CompletionDate is NULL OR OrderDate<=CompletionDate )  AND ( ShipDate is NULL OR CompletionDate<=ShipDate )),

   CONSTRAINT Orders_Status FOREIGN KEY (Status)
      REFERENCES Status (StatusID),

   CONSTRAINT Orders_Employees FOREIGN KEY (EmployeeID)
      REFERENCES Employees (EmployeeID)
         ON DELETE  SET NULL,

   CONSTRAINT Orders_Customers FOREIGN KEY (CustomerID)
      REFERENCES Customers (CustomerID)
         ON DELETE  CASCADE
);
```

| Nazwa atrybutu | Typ         | Opis/Uwagi                                                          |
| -------------- | ----------- | ------------------------------------------------------------------- |
| OrderID        | int         | Auto-inkrementowany klucz główny, unikalny identyfikator zamówienia |
| CustomerID     | int         | Klucz obcy,identyfikator klienta                                    |
| EmployeeID     | int         | Klucz obcy,identyfikator pracownika                                 |
| Status         | int         | Klucz obcy,identyfikator statusu                                    |
| ShipAddress    | varchar(50) | Adres wysyłki                                                       |
| ShipCountry    | varchar(50) | Kraj adresu wysyłki                                                 |
| ShipCity       | varchar(50) | Miasto adresu wysyłki                                               |
| ShipRegion     | varchar(20) | Region adresu wysyłki                                               |
| ShipPostalCode | varchar(20) | Kod pocztowy adresu wysyłki                                         |
| OrderDate      | date        | Data zamówienia                                                     |
| CompletionDate | date        | Data skompletowania zamówienia                                      |
| ShipDate       | date        | Data wysłania zamówienia                                            |

### Tabela: Payments

```sql
CREATE TABLE Payments (
   PaymentID int  NOT NULL IDENTITY(1, 1),
   OrderID int  NOT NULL,
   Amount money  NOT NULL CHECK (Amount>=0),
   PaymentMethod varchar(20)  NOT NULL,
   TransactionDate date  NOT NULL,

   CONSTRAINT Payments_pk PRIMARY KEY  (PaymentID),

   CONSTRAINT Payments_Orders FOREIGN KEY (OrderID)
      REFERENCES Orders (OrderID)
         ON DELETE  CASCADE
);
```

| Nazwa atrybutu  | Typ         | Opis/Uwagi                                                         |
| --------------- | ----------- | ------------------------------------------------------------------ |
| PaymentID       | int         | Auto-inkrementowany klucz główny, unikalny identyfikator płatności |
| OrderID         | int         | Klucz obcy,identyfikator zamówienia                                |
| Amount          | money       | Kwota płatności za zamówienie                                      |
| PaymentMethod   | varchar(20) | Metoda płatności za zamówienie                                     |
| TransactionDate | date        | Data transakcji                                                    |

### Tabela: OrderDetails

```sql
CREATE TABLE OrderDetails (
   OrderID int  NOT NULL,
   ProductId int  NOT NULL,
   Quantity int  NOT NULL CHECK (Quantity>0),
   UnitPrice int  NOT NULL CHECK (UnitPrice>0),
   Discount real  NOT NULL DEFAULT 0 CHECK (Discount>=0 AND Discount<=1),

   CONSTRAINT OrderDetails_pk PRIMARY KEY  (OrderID,ProductId),

   CONSTRAINT OrderDetails_Orders FOREIGN KEY (OrderID)
      REFERENCES Orders (OrderID)
        ON DELETE  CASCADE,

  CONSTRAINT OrderDetails_Products  FOREIGN KEY (ProductId)
      REFERENCES Products (ProductId)

);
```

| Nazwa atrybutu | Typ         | Opis/Uwagi                                       |
| -------------- | ----------- | ------------------------------------------------ |
| OrderID        | int         | Klucz obcy oraz główny ,identyfikator zamówienia |
| ProductID      | int         | Klucz obcy oraz główny ,identyfikator produktu   |
| Quantity       | money       | Ilość produktów w pozycji zamówienia             |
| UnitPrice      | varchar(20) | Cena jednostkowa za produkt                      |
| Discount       | real        | Rabat na pozycje zamówienia w przedziale [0,1]   |

### Tabela: Parts

```sql
CREATE TABLE Parts (
    PartId int  NOT NULL IDENTITY(1, 1),
    ProductCategoryId int  NOT NULL,
    PartName varchar(50) NOT NULL,
    Available int  NOT NULL,
    Reserved int  NOT NULL DEFAULT 0 CHECK (Reserved>=0),
    MinimalQuantity int  NOT NULL DEFAULT 0 CHECK (MinimalQuantity>=0),
    CONSTRAINT Parts_pk PRIMARY KEY  (PartId)

    CONSTRAINT Parts_PartsCategories  FOREIGN KEY (ProductCategoryId)
    REFERENCES PartsCategories (PartCategoryId);
);
```

**Opis:** Tabela przechowuje informacje o częściach/komponentach wykorzystywanych w produkcji.

| Nazwa atrybutu                    | Typ | Opis/Uwagi                                                          |
| --------------------------------- | --- | ------------------------------------------------------------------- |
| PartId                            | int | Klucz główny, unikalny identyfikator części                         |
| PartsCategories_ProductCategoryId | int | Klucz obcy do tabeli PartsCategories, identyfikuje kategorię części |
| Available                         | int | Liczba dostępnych sztuk części na magazynie                         |
| Reserved                          | int | Liczba zarezerwowanych sztuk części                                 |
| MinimalQuantity                   | int | Minimalna ilość części, która powinna być utrzymywana na magazynie  |

---

### Tabela: PartsCategories

```sql
CREATE TABLE PartsCategories (
    PartCategoryId int  NOT NULL IDENTITY(1, 1),
    CategoryName varchar(50)  NOT NULL,
    CONSTRAINT PartsCategories_pk PRIMARY KEY  (PartCategoryId)
);
```

| Nazwa atrybutu | Typ         | Opis/Uwagi                                            |
| -------------- | ----------- | ----------------------------------------------------- |
| PartCategoryId | int         | Klucz główny, unikalny identyfikator kategorii części |
| CategoryName   | varchar(50) | Nazwa kategorii części                                |

---

### Tabela: ProductCategories

```sql
CREATE TABLE ProductCategories (
    ProductCategoryID int  NOT NULL IDENTITY(1, 1),
    CategoryName varchar(50)  NOT NULL,
    CONSTRAINT ProductCategories_pk PRIMARY KEY  (ProductCategoryID)
);
```

| Nazwa atrybutu    | Typ         | Opis/Uwagi                                              |
| ----------------- | ----------- | ------------------------------------------------------- |
| ProductCategoryID | int         | Klucz główny, unikalny identyfikator kategorii produktu |
| CategoryName      | varchar(50) | Nazwa kategorii produktu                                |

---

### Tabela: Products

```sql
CREATE TABLE Products (
    ProductId int  NOT NULL IDENTITY(1,1),
    ProductCategoryId int  NOT NULL,
    ProductName varchar(50) NOT NULL,
    EstimatedProductionTime int  NOT NULL CHECK (EstimatedProductionTime>0),
    CurrentSellPrice money  NOT NULL CHECK (CurrentSellPrice>0),
    CurrentProductionCost money  NOT NULL CHECK (CurrentProductionCost>0),
    Available int  NOT NULL,
    Reserved int  NOT NULL DEFAULT 0 CHECK (Reserved>=0),
    MinimalQuantity int  NOT NULL CHECK (MinimalQuantity>=0),
    CONSTRAINT ProductID PRIMARY KEY  (ProductId)

    CONSTRAINT Products_ProductCategories FOREIGN KEY (ProductCategoryId)
    REFERENCES ProductCategories (ProductCategoryID);
);
```

| Nazwa atrybutu                   | Typ   | Opis/Uwagi                                                              |
| -------------------------------- | ----- | ----------------------------------------------------------------------- |
| ProductId                        | int   | Klucz główny, unikalny identyfikator produktu                           |
| ProductCategories_PartCategoryId | int   | Klucz obcy do tabeli ProductCategories, identyfikuje kategorię produktu |
| EstimatedProductionTime          | int   | Szacowany czas produkcji produktu w godzinach                           |
| CurrentSellPrice                 | money | Aktualna cena sprzedaży produktu                                        |
| CurrentProductionCost            | money | Aktualny koszt produkcji produktu                                       |
| Available                        | int   | Liczba dostępnych sztuk produktu na magazynie                           |
| Reserved                         | int   | Liczba zarezerwowanych sztuk produktu                                   |
| MinimalQuantity                  | int   | Minimalna ilość produktu, która powinna być utrzymywana na magazynie    |

---

### Tabela: ProductsDetails

```sql
CREATE TABLE ProductsDetails (
    ProductId int  NOT NULL,
    PartId int  NOT NULL,
    Quantity int  NOT NULL CHECK (Quantity>0),
    CONSTRAINT ProductsDetails_pk PRIMARY KEY  (ProductId, PartId)

    CONSTRAINT ProductsDetails_Products FOREIGN KEY (ProductId)
    REFERENCES Products (ProductId)
    ON DELETE  CASCADE;

    CONSTRAINT ProductsDetails_Parts FOREIGN KEY (PartId)
    REFERENCES Parts (PartId);
);
```

| Nazwa atrybutu     | Typ | Opis/Uwagi                                                             |
| ------------------ | --- | ---------------------------------------------------------------------- |
| Products_ProductId | int | Część klucza głównego, klucz obcy do tabeli Products                   |
| Parts_PartId       | int | Część klucza głównego, klucz obcy do tabeli Parts                      |
| Quantity           | int | Ilość danej części potrzebnej do wyprodukowania jednej sztuki produktu |

---

### Tabela: ProductionOrder

```sql

CREATE TABLE ProductionOrder (
   ProductionOrderID int  NOT NULL IDENTITY(1, 1),
   ProductionLineId int  NOT NULL,
   ProductionOrderStatus int  NOT NULL,
   ProductId int  NOT NULL,
   Quantity int  NOT NULL CHECK (Quantity>0),
   QuantityProduced int  NOT NULL DEFAULT 0 CHECK (QuantityProduced>=0),
   QuantityAllocated int  NOT NULL DEFAULT 0 CHECK (QuantityAllocated>=0),
   AddedDate date  NOT NULL,
   PlannedStartDate datetime  NOT NULL,
   PlannedEndDate datetime  NOT NULL,
   StartDate datetime  NULL,
   EndDate datetime  NULL,
   CONSTRAINT CHK_AddDate CHECK (AddedDate<=PlannedStartDate),
   CONSTRAINT CHK_PlannedDates CHECK (PlannedStartDate<=PlannedEndDate),
   CONSTRAINT CHK_RealDates CHECK (EndDate is Null OR StartDate<=EndDate ),
   CONSTRAINT CHK_QuantityAllocated_Quantity CHECK (Quantity>=QuantityAllocated),
   CONSTRAINT ProductionOrder_pk PRIMARY KEY  (ProductionOrderID)
);


```

| Nazwa atrybutu        | Typ  | Opis/Uwagi                                                   |
| --------------------- | ---- | ------------------------------------------------------------ |
| ProductionOrderID     | int  | Klucz główny, unikalny numer zlecenia produkcyjnego          |
| ProductionLineId      | int  | Klucz obcy, wskazuje linię produkcyjną realizującą zlecenie  |
| ProductionOrderStatus | int  | Klucz obcy, określa aktualny status zlecenia                 |
| ProductId             | int  | Klucz obcy, identyfikuje produkowany produkt                 |
| Quantity              | int  | Planowana ilość produktu do wyprodukowania                   |
| QuantityProduced      | int  | Ilość produktu faktycznie wyprodukowana do tej pory          |
| QuantityAllocated     | int  | Ilość produktu który został przekierowany na inne zamówienia |
| AddedDate             | date | Data dodania zlecenia do systemu                             |
| PlannedStartDate      | date | Planowana data rozpoczęcia produkcji                         |
| PlannedEndDate        | date | Planowana data zakończenia produkcji                         |
| StartDate             | date | Rzeczywista data rozpoczęcia (pole może być puste)           |
| EndDate               | date | Rzeczywista data zakończenia (pole może być puste)           |

---

### Tabela: ProductionLine

```sql
CREATE TABLE ProductionLine (
   ProductionLineId int  NOT NULL IDENTITY(1, 1),
   ProductCategoryId int  NOT NULL,
   CONSTRAINT ProductionLine_pk PRIMARY KEY  (ProductionLineId)
);
```

| Nazwa atrybutu    | Typ | Opis/Uwagi                                                            |
| :---------------- | :-- | :-------------------------------------------------------------------- |
| ProductionLineId  | int | Klucz główny, unikalny identyfikator linii produkcyjnej               |
| ProductCategoryId | int | Klucz obcy, identyfikuje kategorię produktu przypisaną do danej linii |

---

### Tabela: ProductionHistory

```sql
CREATE TABLE ProductionHistory (
   ProductionHistoryId int  NOT NULL IDENTITY(1, 1),
   ProductionOrderID int  NOT NULL,
   ProductId int  NOT NULL,
   ProducedDate date  NOT NULL,
   ProductionCost money  NOT NULL CHECK (ProductionCost>0),
   Quantity int NOT NULL CHECK (Quantity > 0),
   RejectedQuantity int NOT NULL CHECK (RejectedQuantity > 0),
   CONSTRAINT ProductionHistory_pk PRIMARY KEY  (ProductionHistoryId)
);
```

| Nazwa atrybutu      | Typ   | Opis/Uwagi                                                          |
| :------------------ | :---- | :------------------------------------------------------------------ |
| ProductionHistoryId | int   | Klucz główny, unikalny identyfikator wpisu historii                 |
| ProductionOrderID   | int   | Klucz obcy, wiąże wpis historii z konkretnym zleceniem produkcyjnym |
| ProductId           | int   | Klucz obcy, identyfikuje wyprodukowany produkt                      |
| ProducedDate        | date  | Data wyprodukowania produktu                                        |
| ProductionCost      | money | Koszt produkcji produktu                                            |
| Quantity            | int   | Liczba wyprodukowanych produktów                                    |
| RejectedQuantity    | int   | Liczba wyprodukowanych produktów, które zostały odrzucone           |

---

### Tabela: ProductionLineTimeAllocation

```sql

CREATE TABLE ProductionLineTimeAllocation (
   ProductionLineTimeAllocationID int  NOT NULL IDENTITY(1, 1),
   ProductionLineId int  NOT NULL,
   HoursTotal decimal(6,2)  NOT NULL CHECK (HoursTotal>=0),
   HoursAllocated decimal(6,2)  NOT NULL DEFAULT 0 CHECK (HoursAllocated>=0),
   Date date  NOT NULL,
   DowntimeHours int  NOT NULL DEFAULT 0 CHECK (DowntimeHours>=0),
   ShiftStart time(0)  NOT NULL,
   ShiftEnd time(0)  NOT NULL,
   CONSTRAINT ProductionLine_Date UNIQUE (ProductionLineId, Date),
   CONSTRAINT CK_hours CHECK (HoursTotal>=HoursAllocated),
   CONSTRAINT CK_Shift CHECK (ShiftStart<=ShiftEnd),
   CONSTRAINT ProductionLineTimeAllocation_pk PRIMARY KEY  (ProductionLineTimeAllocationID)
);

```

| Nazwa atrybutu                 | Typ          | Opis/Uwagi                                                      |
| :----------------------------- | :----------- | :-------------------------------------------------------------- |
| ProductionLineTimeAllocationID | int          | Klucz główny, unikalny identyfikator alokacji czasu             |
| ProductionLineId               | int          | Klucz obcy, identyfikuje linię, której dotyczy alokacja         |
| HoursTotal                     | decimal(6,2) | Całkowita liczba godzin dostępnych na tej linii w danym dniu    |
| HoursAllocated                 | decimal(6,2) | Liczba godzin, które zostały już zaalokowane na tej linii       |
| Date                           | date         | Data, której dotyczy alokacja czasu                             |
| DowntimeHours                  | int          | Liczba godzin straconych przez wadliwe produkty i problemy lini |
| ShiftStart                     | time(0)      | Godzina w której linia rozpoczyna prace                         |
| ShiftEnd                       | time(0)      | Godzina w której linia kończy pracę                             |

---

### Tabela: ProductionOrderStatus

```sql
CREATE TABLE ProductionOrderStatus (
   ProductionOrderStatus int  NOT NULL IDENTITY(1,1),
   Status varchar(20)  NOT NULL,
   CONSTRAINT ProductionOrderStatus_pk PRIMARY KEY  (ProductionOrderStatus)
);
```

| Nazwa atrybutu        | Typ         | Opis/Uwagi                                                  |
| :-------------------- | :---------- | :---------------------------------------------------------- |
| ProductionOrderStatus | int         | Klucz główny, identyfikator statusu zlecenia                |
| Status                | varchar(20) | Tekstowa nazwa statusu (np. Oczekujące, W toku, Zakończone) |

### Tabela: ProductReservation

```sql
CREATE TABLE ProductReservation (
   ProductID int  NOT NULL,
   OrderID int  NOT NULL,
   Quantity int  NOT NULL CHECK (Quantity>0),
   CONSTRAINT ProductReservation_pk PRIMARY KEY  (ProductID,OrderID),
   CONSTRAINT OrdersReservation_Products FOREIGN KEY (ProductID)
      REFERENCES Products (ProductId);
   CONSTRAINT OrdersReservation_Orders FOREIGN KEY (OrderID)
      REFERENCES Orders (OrderID);
);
```

| Nazwa atrybutu | Typ         | Opis/Uwagi                                                  |
| :------------- | :---------- | :---------------------------------------------------------- |
| Product        | int         | Klucz główny, identyfikator statusu zlecenia                |
| Status         | varchar(20) | Tekstowa nazwa statusu (np. Oczekujące, W toku, Zakończone) |

# 3. Widoki, procedury/funkcje, triggery

## Widoki

---

### Widok: Podsumowanie zamówień

Pokazuje ostateczną wartość każdego zamówienia po odjęciu rabatów. Łączy w jednym miejscu dane o tym kto kupił, za ile i skąd.

```sql
CREATE VIEW v_OrderSummary AS
SELECT
    o.OrderID,
    o.OrderDate,
    c.CustomerName,
    ct.TypeName AS CustomerType,
    os.OrderStatusName,
    SUM(od.Quantity * od.UnitPrice * (1.0 - od.Discount)) AS TotalOrderValue,
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
```

---

### Widok: Ranking Produktów

Zestawienie bestsellerów. Pokazuje, które produkty przynoszą firmie największy przychód i sprzedają się w największych ilościach.

```sql
CREATE VIEW v_TopSellingProducts AS
SELECT
    p.ProductName,
    pc.CategoryName,
    SUM(od.Quantity) AS TotalUnitsSold,
    SUM(od.Quantity * od.UnitPrice * (1.0 - od.Discount)) AS TotalRevenue,
    p.CurrentSellPrice
FROM Products p
JOIN ProductCategories pc ON p.ProductCategoryId = pc.ProductCategoryID
JOIN OrderDetails od ON p.ProductId = od.ProductId
JOIN Orders o ON od.OrderID = o.OrderID
JOIN OrderStatus os ON o.Status = os.OrderStatusID
WHERE os.OrderStatusName <> 'Anulowane'
GROUP BY
    p.ProductName, pc.CategoryName, p.CurrentSellPrice;
```

---

### Widok: Analiza Kosztów Produkcji

Wylicza marżę (zysk na sztuce) oraz pokazuje, ile wynoszą koszty niematerialne, czyli robocizna i pozostałe koszta po odjęciu ceny części.

```sql
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
    p.ProductName, pc.CategoryName, p.CurrentSellPrice, p.CurrentProductionCost;
```

---

### Widok: Kolejka i Status Produkcji

Monitoruje postęp i terminowość wszystkich zleceń produkcyjnych. Automatycznie flaguje zlecenia jako "Opóźnione", jeśli minął planowany termin zakończenia.

```sql
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
```

---

### Widok: Ranking klientów

Identyfikuje kluczowych klientów. Mówi, kto zostawia w firmie najwięcej pieniędzy, a kto zamawia najczęściej.

```sql
CREATE VIEW v_CustomerStats AS
SELECT
    c.CustomerName,
    ct.TypeName AS CustomerType,
    COUNT(o.OrderID) AS OrdersCount,
    SUM(od.Quantity * od.UnitPrice * (1.0 - od.Discount)) AS TotalSpent,
    MAX(o.OrderDate) AS LastOrderDate,
    AVG(od.Quantity * od.UnitPrice * (1.0 - od.Discount)) AS AvgOrderValue
FROM Customers c
JOIN Orders o ON c.CustomerID = o.CustomerID
JOIN OrderDetails od ON o.OrderID = od.OrderID
JOIN CustomerType ct ON c.CustomerType = ct.TypeID
JOIN OrderStatus os ON o.Status = os.OrderStatusID
WHERE os.OrderStatusName <> 'Anulowane'
GROUP BY c.CustomerName, ct.TypeName;
```

---

### Widok: Miesięczne zestawienie przychodów

Podsumowuje, ile firma zarobiła w każdym miesiącu.

```sql
CREATE VIEW v_MonthlySales AS
SELECT
    FORMAT(o.OrderDate, 'yyyy-MM') AS SalesMonth,
    COUNT(DISTINCT o.OrderID) AS OrdersCount,
    SUM(od.Quantity * od.UnitPrice * (1.0 - od.Discount)) AS MonthlyRevenue
FROM Orders o
JOIN OrderDetails od ON o.OrderID = od.OrderID
JOIN OrderStatus os ON o.Status = os.OrderStatusID
WHERE os.OrderStatusName <> 'Anulowane'
GROUP BY FORMAT(o.OrderDate, 'yyyy-MM');
```

---

### Widok: Zapotrzebowanie Materiałowe

Zlicza łączne zapotrzebowanie na części dla wszystkich otwartych zleceń produkcyjnych. Stanowi gotową listę zakupową wraz z estymacją kosztów.

```sql
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
    pt.PartName, pc.CategoryName, pt.PartPrice;
```

---

### Widok: Braki magazynowe

Wyświetla listę produktów, których zapas spadł poniżej bezpiecznego poziomu lub których brakuje do realizacji zamówień.

```sql
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
```

---

### Widok: Niezapłacone Zamówienia

Lista dłużników. Wyświetla tylko te zamówienia, za które klienci jeszcze nie zapłacili w całości, wraz z kwotą, która pozostała do uregulowania.

```sql
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
```

---

### Widok: Skuteczność produkcji

Wylicza, jaki procent wyprodukowanych towarów stanowiły braki (uszkodzone produkty). Pozwala to ocenić sprawność linii produkcyjnych oraz zidentyfikować produkty sprawiające największą trudność w produkcji.

```sql
CREATE VIEW v_ProductionEfficiency AS
SELECT
    p.ProductName,
    pl.ProductionLineId,
    SUM(ph.Quantity) AS TotalProducedGood,
    SUM(ph.RejectedQuantity) AS TotalRejected,
    CAST(
        CASE
            WHEN (SUM(ph.Quantity) + SUM(ph.RejectedQuantity)) = 0 THEN 0
            ELSE (SUM(ph.RejectedQuantity) * 100.0) / (SUM(ph.Quantity) + SUM(ph.RejectedQuantity))
        END
    AS DECIMAL(5,2)) AS DefectRatePercent

FROM ProductionHistory ph
JOIN Products p ON ph.ProductId = p.ProductId
JOIN ProductionOrder po ON ph.ProductionOrderID = po.ProductionOrderID
JOIN ProductionLine pl ON po.ProductionLineId = pl.ProductionLineId
GROUP BY p.ProductName, pl.ProductionLineId;
```

---

(dla każdego widoku należy wkleić kod polecenia definiującego widok wraz z komentarzem)

```sql
crete or alter view vw_abc
as
select a from tab1
```

## Procedury/funkcje

(dla każdej procedury/funkcji należy wkleić kod polecenia definiującego procedurę wraz z komentarzem)

### Procedura: RedirectAndCreateNewOrder

```sql
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


```

Główna procedura do nowych zamówień. Na początku przekierowuje produkcje towarów które nie są skończone oraz posiadają nie zaalokowane produkty, na zamówienie klienta.Jak znajdzie produkcje, która całkowicie uzupełni zamówienie klienta oblicza czas w jakim produkcja ta może wytworzyć potrzebne produkty. Jeśli istniejące produkcje nie wypełnia całkowicie zamówienia tworzy nowe. Procedura zwraca szacowaną date, dla której zamówienia klienta może być spenione.

### Procedura: CalculateWhenQuantityOfProductWillBeProduced

```sql
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
    where ProductionOrderID=@ProductionOrderID


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


```

Procedura oblicza datę w której produkcja wyprodukuje produkty już zaalokowane z nowymi. Dzięki temu nie musimy czekać na koniec zamówienia aby móc przyjąc zamówenie klienta. Obliczając ile w danym dni zostało wytworzone produktów próbuje operować na danych historycznych z ProductionHistory. Jeśli nie ma takich danych, szacuje czas przez EstimatedProductionTime z tabeli Products. \
Procedura jest przydatna w szczególności jak mamy jedno duże zamówienie produkcyjne.

### Procedura: CreateNewOrder

```sql
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




```

Procedura alokuje czas na nowe zamówienie oraz je tworzy

### Funkcja: Total order value

Funckja oblicza wartosci calego zamówienia na podstawie `OrderDetails`

```sql
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
```

## Triggery

### Trigger: Update order status after payment

Zmiana statusu na 'Opłacone' (2), gdy suma wpłat pokryje wartość zamówienia.
Po dodaniu/edycji płatności sprawdza sumę kwot w tabeli Payments dla danego zamówienia.
Jeśli Suma >= Wynik funkcji CalculateOrderValue_FN, status w tabeli Orders zmienia się na 2.

```sql
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
```

### Trigger: Update avaible after produced

Zwiększenie ilości dostępnych produktów (Available) po zakończeniu procesu produkcji.
Przy dodaniu wpisu do historii produkcji (INSERT), zwiększa kolumnę Available w tabeli Products.
Przy usunięciu (DELETE) lub edycji (UPDATE), koryguje stan o różnicę między starymi a nowymi danymi.

```sql
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
```

### Trigger: Order status changed

Koordynacja rezerwacji i wydań towaru na podstawie zmiany statusu zamówienia.

1. Jeśli Status=2 (Opłacone): Tworzy rekordy w tabeli ProductReservation (rezerwuje towar).
2. Jeśli Status=3 (Do wysyłki): Odejmuje towar z Available i usuwa rezerwację.
3. Jeśli Status=5 (Anulowane): Usuwa rezerwację - usuwa z tabeli ProductReservation.

```sql
CREATE OR ALTER TRIGGER trg_Orders_HandleStatusChange
ON Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(Status) RETURN;

    -- 1. Opłacone (2) -> Dodajemy rezerwację
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

        -- Usuwamy rezerwację
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
```

### Trigger: Update reserved in products

Utrzymuje aktualna liczby zarezerwowanych sztuk w tabeli Products.
Reaguje na każdą zmianę w tabeli ProductReservation. Dodaje ilości z 'inserted' (nowe rezerwacje)
i odejmuje ilości z 'deleted' (koniec rezerwacji) od kolumny Products.Reserved.

```sql
CREATE OR ALTER TRIGGER trg_ProductReservation_UpdateProductsReserved
ON ProductReservation
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Obsługa nowych rezerwacji lub zwiększenia ilości (INSERT/UPDATE)
    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        UPDATE p
        SET p.Reserved = ISNULL(p.Reserved, 0) + i.TotalQty
        FROM Products p
        INNER JOIN (
            SELECT ProductID, SUM(Quantity) AS TotalQty
            FROM inserted
            GROUP BY ProductID
        ) i ON p.ProductId = i.ProductID;
    END

    -- 2. Obsługa usuniętych rezerwacji lub starej ilości przy zmianie (DELETE/UPDATE)
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        UPDATE p
        SET p.Reserved = ISNULL(p.Reserved, 0) - d.TotalQty
        FROM Products p
        INNER JOIN (
            SELECT ProductID, SUM(Quantity) AS TotalQty
            FROM deleted
            GROUP BY ProductID
        ) d ON p.ProductId = d.ProductID;
    END
END
GO
```

### Trigger: Fulfill order

Sprawdza czy nowa dostawa towaru pozwala na realizację oczekujących zamówień,
zostanie wywolany rowniez przy tworzeniu nowego zamowienia poprzez zmiane w Products.Reserved.
Uzupelnia zamowienia stosujac zasade FIFO.
Uruchamia się przy zmianie stanu magazynowego. Przeszukuje opłacone zamówienia (Status 2)
od najstarszego. Korzysta z "wirtualnego magazynu", by sprawdzić czy starczy towaru na cały koszyk.
Jeśli tak, zmienia status zamówienia na 3 (co uruchamia wydanie towaru), jesli nie starczy redukuje
dostepne produkty aby mniejsze nowsze zamowienia nie byly realizowane wczesniej.

```sql
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
        -- 2. Aktualizujemy wirtualny magazyn
        UPDATE vs
        SET vs.TempAvailable = vs.TempAvailable - od.Quantity
        FROM @VirtualStock vs
        JOIN OrderDetails od ON vs.ProdID = od.ProductId
        WHERE od.OrderID = @OrderID;

        -- 3. Mozna wypelnic zamowienie
        IF @CanFulfill = 1
        BEGIN
            -- Zmiana na 3 odpali trigger na order status
            UPDATE Orders SET Status = 3 WHERE OrderID = @OrderID;
        END

        FETCH NEXT FROM order_cursor INTO @OrderID;
    END

    CLOSE order_cursor;
    DEALLOCATE order_cursor;

END
GO
```

# 4. Inne

(informacja o sposobie wygenerowania danych, uprawnienia …)
