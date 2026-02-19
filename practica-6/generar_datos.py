import csv
import random

FILENAME = "nifi_data/clientes.csv"
NUM_RECORDS = 50

nombres = ["Juan", "Maria", "Pedro", "Lucia", "Antonio", "Carmen", ""] # Incluye vacío para error
apellidos = ["Garcia", "Lopez", "Martinez", "Sanchez", "Rodriguez", ""] # Incluye vacío para error
ciudades = ["Almeria", "Granada", "Sevilla", "Madrid", "Barcelona", "Valencia"]

def get_random_date():
    # Formato americano MM/dd/yyyy    
    month = random.randint(1, 12)
    day = random.randint(1, 28)
    year = random.randint(2020, 2023)
    return f"{month:02d}/{day:02d}/{year}"

data = []

for _ in range(NUM_RECORDS):
    row = [
        random.choice(nombres),
        random.choice(apellidos),
        get_random_date(),
        random.randint(0, 20), # Pedidos
        random.choice(ciudades)
    ]
    data.append(row)

data.extend(data[:3])

data.append(["Error", "User", "99/99/2022", 5, "Madrid"]) 

with open(FILENAME, mode='w', newline='', encoding='utf-8') as file:
    writer = csv.writer(file)
    writer.writerows(data)

print(f"Generado {FILENAME} con {len(data)} registros (incluyendo duplicados y errores).")