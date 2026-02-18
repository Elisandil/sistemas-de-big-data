import json
import time
import random
import sys

try:
    from kafka import KafkaProducer
except ImportError:
    print("Error: Necesitas instalar la librería 'kafka-python'.")
    print("Ejecuta: pip install kafka-python")
    sys.exit(1)

def generate_sensor_data():
    """Genera un evento simulado de un sensor IoT"""
    sensors = ["S-001", "S-002", "S-003", "S-004", "S-005"]
    locations = ["Warehouse-A", "Warehouse-B", "Factory-Main", "Cold-Storage"]
    statuses = ["OK", "WARNING", "CRITICAL", "MAINTENANCE"]

    return {
        "sensor_id": random.choice(sensors),
        "location": random.choice(locations),
        "temperature": round(random.uniform(15.0, 45.0), 2),
        "humidity": round(random.uniform(30.0, 90.0), 2),
        "status": random.choices(statuses, weights=[0.8, 0.1, 0.05, 0.05])[0],
        "timestamp": int(time.time() * 1000) # Epoch en milisegundos
    }

def main():
    topic_name = "sensor-data"
    bootstrap_servers = 'localhost:9092'

    print(f"Iniciando productor Kafka hacia {bootstrap_servers} en el topic '{topic_name}'...")
    
    try:
        producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8')
        )
    except Exception as e:
        print(f"No se pudo conectar a Kafka. Asegúrate de que el contenedor de Kafka esté corriendo y el puerto 9092 accesible.")
        print(f"Error: {e}")
        return

    try:
        count = 0
        while True:
            data = generate_sensor_data()
            producer.send(topic_name, data)
            count += 1
            print(f"[{count}] Enviado: {data['sensor_id']} | Temp: {data['temperature']}")

            time.sleep(0.5) 
            
    except KeyboardInterrupt:
        print("\nDeteniendo productor...")
        producer.close()

if __name__ == "__main__":
    main()