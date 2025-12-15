import random
import math

ORDER_COUNT = 400 
PRODUCT_IDS = list(range(1, 22))

MIN_UNIT_PRICE = 600
MAX_UNIT_PRICE = 1200

DISCOUNT_CHANCE = 0.30
MIN_DISCOUNT = 0.10
MAX_DISCOUNT = 0.30

sql_script = "--- 1. INSERT ORDER DETAILS (200-400 records) ---\n"
sql_script += "INSERT INTO OrderDetails (OrderID, ProductId, Quantity, UnitPrice, Discount) VALUES\n"

records = []
for order_id in range(1, ORDER_COUNT + 1):
    
    details_count = random.choice([1, 2])
    has_discount = random.random() < DISCOUNT_CHANCE
    
    if has_discount:
        discount_value = round(random.uniform(MIN_DISCOUNT, MAX_DISCOUNT), 2)
    else:
        discount_value = 0.00

    used_product_ids = set() 
    
    for _ in range(details_count):
        product_id = random.choice([p for p in PRODUCT_IDS if p not in used_product_ids])
        used_product_ids.add(product_id)
        
        quantity = random.randint(1, 5)

        unit_price = random.randint(MIN_UNIT_PRICE, MAX_UNIT_PRICE)
        record = (
            f"({order_id}, {product_id}, {quantity}, {unit_price}, {discount_value})"
        )
        records.append(record)

sql_script += ",\n".join(records) + ";\n"


with open("insert_order_details.sql", "w", encoding="utf-8") as f_out:
    f_out.write(sql_script)