import random
from datetime import datetime, timedelta

ORDER_COUNT = 400
CUSTOMER_IDS = [1, 2, 3, 4, 5]

STATUS_IDS = [1, 2, 3, 4, 5]
STATUS_70_PERCENT_ID = 4     
STATUSES_WITH_NULL_DATES = [1, 5]
STATUS_READY_TO_SHIP = 3 

PAYMENT_METHODS = ['BLIK', 'karta', 'gotowka', 'przelew']
PAYMENT_ID_COUNTER = 1

ADDRESS_POOL = [
    {'ShipAddress': 'ul. Długa 12/A', 'ShipCity': 'Kraków', 'ShipRegion': 'Małopolskie', 'ShipPostalCode': '31-001', 'ShipCountry': 'Polska'},
    {'ShipAddress': 'Al. Jerozolimskie 50', 'ShipCity': 'Warszawa', 'ShipRegion': 'Mazowieckie', 'ShipPostalCode': '00-024', 'ShipCountry': 'Polska'},
    {'ShipAddress': 'ul. Gdańska 5', 'ShipCity': 'Łódź', 'ShipRegion': 'Łódzkie', 'ShipPostalCode': '90-722', 'ShipCountry': 'Polska'},
    {'ShipAddress': 'ul. Leśna 3', 'ShipCity': 'Wrocław', 'ShipRegion': 'Dolnośląskie', 'ShipPostalCode': '50-107', 'ShipCountry': 'Polska'},
    {'ShipAddress': 'ul. Kaszubska 17', 'ShipCity': 'Gdańsk', 'ShipRegion': 'Pomorskie', 'ShipPostalCode': '80-218', 'ShipCountry': 'Polska'},
    {'ShipAddress': 'ul. Słowackiego 20', 'ShipCity': 'Poznań', 'ShipRegion': 'Wielkopolskie', 'ShipPostalCode': '60-823', 'ShipCountry': 'Polska'},
    {'ShipAddress': 'ul. Mickiewicza 1', 'ShipCity': 'Bydgoszcz', 'ShipRegion': 'Kujawsko-Pomorskie', 'ShipPostalCode': '85-001', 'ShipCountry': 'Polska'},
    {'ShipAddress': 'ul. Lipowa 44', 'ShipCity': 'Lublin', 'ShipRegion': 'Lubelskie', 'ShipPostalCode': '20-004', 'ShipCountry': 'Polska'},
    {'ShipAddress': 'ul. Rynek Główny 1', 'ShipCity': 'Rzeszów', 'ShipRegion': 'Podkarpackie', 'ShipPostalCode': '35-064', 'ShipCountry': 'Polska'},
    {'ShipAddress': 'ul. Hutnicza 10', 'ShipCity': 'Katowice', 'ShipRegion': 'Śląskie', 'ShipPostalCode': '40-600', 'ShipCountry': 'Polska'}
]

def get_random_date_dt(start_year, end_year):
    start_date = datetime(start_year, 1, 1)
    end_date = datetime(end_year, 12, 31)
    
    time_between_dates = end_date - start_date
    random_number_of_days = random.randrange(time_between_dates.days)
    return (start_date + timedelta(days=random_number_of_days))

def get_status_id():
    if random.random() < 0.70:
        return STATUS_70_PERCENT_ID
    else:
        return random.choice(STATUS_IDS) 

orders_records = []
payments_records = []
payment_id_counter = 1

for i in range(1, ORDER_COUNT + 1):
    order_id = i
    customer_id = random.choice(CUSTOMER_IDS)
    address = random.choice(ADDRESS_POOL) 
    
    status_id = get_status_id()
    
    order_date_dt = get_random_date_dt(2005, 2006)
    order_date_str = f"'{order_date_dt.date()}'"
    
    ship_date = "NULL"
    completion_date = "NULL"
    completion_date_dt = None 
    
    
    if status_id in STATUSES_WITH_NULL_DATES:
        pass
    
    elif status_id == STATUS_READY_TO_SHIP:
        completion_delta = random.randint(1, 3)
        completion_date_dt = order_date_dt + timedelta(days=completion_delta)
        completion_date = f"'{completion_date_dt.date()}'"
        ship_date = "NULL"
        
    else:
        completion_delta = random.randint(1, 3)
        completion_date_dt = order_date_dt + timedelta(days=completion_delta)
        completion_date = f"'{completion_date_dt.date()}'"
        
        ship_delta = random.randint(4, 7)
        ship_date_dt = order_date_dt + timedelta(days=ship_delta)
        ship_date = f"'{ship_date_dt.date()}'"

    order_record = (
        f"({order_id}, {customer_id}, "
        f"{status_id}, "
        f"'{address['ShipAddress']}', '{address['ShipCity']}', '{address['ShipCountry']}', "
        f"'{address['ShipRegion']}', '{address['ShipPostalCode']}', "
        f"{order_date_str}, {ship_date}, {completion_date})"
    )
    orders_records.append(order_record)
    
    if status_id != 5:
        
        transaction_date_dt = None
        
        if completion_date_dt:
            time_diff_days = (completion_date_dt - order_date_dt).days
            
            if time_diff_days >= 1:
                random_days = random.randrange(time_diff_days)
                transaction_date_dt = order_date_dt + timedelta(days=random_days)
            else:
                transaction_date_dt = order_date_dt
        else:
            transaction_date_dt = order_date_dt + timedelta(days=random.randint(0, 5))
            
        amount = random.randint(100, 5000)
        
        payment_record = (
            f"({payment_id_counter}, {order_id}, "
            f"{amount}, "
            f"'{random.choice(PAYMENT_METHODS)}', "
            f"'{transaction_date_dt.date()}')"
        )
        payments_records.append(payment_record)
        payment_id_counter += 1



sql_script = "INSERT INTO Orders (OrderID, CustomerID, Status, ShipAddress, ShipCity, ShipCountry, ShipRegion, ShipPostalCode, OrderDate, ShipDate, CompletionDate) VALUES\n"
sql_script += ",\n".join(orders_records) + ";\n\n"

sql_script += "INSERT INTO Payments (PaymentID, OrderID, Amount, PaymentMethod, TransactionDate) VALUES\n"
sql_script += ",\n".join(payments_records) + ";\n"

with open("insert_orders_payments_final.sql", "w", encoding="utf-8") as f_out:
    f_out.write(sql_script)