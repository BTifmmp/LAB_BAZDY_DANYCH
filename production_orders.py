import random
from datetime import datetime, timedelta

# --- STAŁE KONFIGURACYJNE ---
ORDER_COUNT = 200
START_DATE_RANGE = datetime(2024, 1, 1)
END_DATE_RANGE = datetime(2025, 12, 15)
PRODUCTION_LINES_IDS = list(range(1, 6)) # Linie 1-5
FINAL_STATUS = 3 # Gotowe (Zrealizowane)
REJECTED_QUANTITY = 0 # Wymagane 0 dla historii

# Mapowanie produktów na kategorie (dla celów losowania produktów)
PRODUCTS_CATEGORIES = {
    1: 1, 2: 1, 3: 1, 4: 1, 
    5: 2, 6: 2, 7: 2, 8: 2, 
    9: 3, 10: 3, 11: 3, 12: 3, 13: 3, 
    14: 4, 15: 4, 16: 4, 17: 4, 
    18: 5, 19: 5, 20: 5, 21: 5
}
PRODUCT_IDS = list(PRODUCTS_CATEGORIES.keys())

# Liczniki ID
PRODUCTION_ORDER_ID_COUNTER = 1
PRODUCTION_HISTORY_ID_COUNTER = 1

# --- LISTY WYNIKOWE ---
production_orders_records = []
production_history_records = []

# --- FUNKCJE POMOCNICZE ---

def get_random_date_dt(start, end):
    time_between_dates = end - start
    random_number_of_seconds = random.randrange(int(time_between_dates.total_seconds()))
    return start + timedelta(seconds=random_number_of_seconds)

def get_random_duration():
    return timedelta(days=random.randint(1, 5), hours=random.randint(0, 23))


for _ in range(ORDER_COUNT):
    order_id = PRODUCTION_ORDER_ID_COUNTER
    product_id = random.choice(PRODUCT_IDS)
    line_id = PRODUCTS_CATEGORIES[product_id]
    
    # Ilości
    quantity = random.randint(5, 10)
    quantity_produced = quantity # W pełni zrealizowane
    
    # Data dodania (przyjęcie zlecenia): Losowa data w całym zakresie
    added_date_dt = get_random_date_dt(START_DATE_RANGE, END_DATE_RANGE - timedelta(days=6))
    
    # Data rozpoczęcia: 1-2 dni po AddedDate
    start_date_dt = added_date_dt + timedelta(days=random.randint(1, 2)) + timedelta(hours=random.randint(1, 8))
    
    # Czas trwania produkcji (1-5 dni)
    duration = get_random_duration()
    
    # Data zakończenia (Rzeczywista): StartDate + Czas trwania
    end_date_dt = start_date_dt + duration
    
    # Data planowana (może być taka sama lub dłuższa)
    planned_end_date_dt = end_date_dt + timedelta(days=random.randint(0, 1))

    # --- REKORD PRODUCTION ORDER ---
    
    production_orders_records.append(
        f"({order_id}, {line_id}, {FINAL_STATUS}, {product_id}, {quantity}, {quantity_produced}, "
        f"{0}, '{added_date_dt.date()}', '{start_date_dt}', "
        f"'{planned_end_date_dt}', '{start_date_dt}', '{end_date_dt}')"
    )

    # --- REKORD PRODUCTION HISTORY ---
    
    # ProductionHistory ma datę zrealizowania (równą EndDate) i koszty
    production_cost = round(quantity * random.uniform(200.0, 500.0), 2) # Losowy koszt produkcji
    
    production_history_records.append(
        f"({PRODUCTION_HISTORY_ID_COUNTER}, {order_id}, {product_id}, '{end_date_dt.date()}', "
        f"{production_cost}, {quantity_produced}, {REJECTED_QUANTITY})"
    )
    
    PRODUCTION_ORDER_ID_COUNTER += 1
    PRODUCTION_HISTORY_ID_COUNTER += 1


# --- ZAPIS DO PLIKU SQL ---
sql_script = "SET IDENTITY_INSERT ProductionOrder ON;\n"
sql_script += "INSERT INTO ProductionOrder (ProductionOrderID, ProductionLineId, ProductionOrderStatus, ProductId, Quantity, QuantityProduced, QuantityAllocated, AddedDate, PlannedStartDate, PlannedEndDate, StartDate, EndDate) VALUES\n"
sql_script += ",\n".join(production_orders_records) + ";\n\n"
sql_script += "SET IDENTITY_INSERT ProductionOrder OFF;\n"


sql_script += "SET IDENTITY_INSERT ProductionHistory ON;\n"
sql_script += "INSERT INTO ProductionHistory (ProductionHistoryId, ProductionOrderID, ProductId, ProducedDate, ProductionCost, Quantity, RejectedQuantity) VALUES\n"
sql_script += ",\n".join(production_history_records) + ";\n"
sql_script += "SET IDENTITY_INSERT ProductionHistory OFF;\n"

# Zapis do pliku
with open("seed_production_4.sql", "w", encoding="utf-8") as f_out:
    f_out.write(sql_script)