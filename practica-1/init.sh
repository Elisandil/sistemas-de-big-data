#!/bin/bash
set -e  

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "==================================="
echo -e "${GREEN}  Inicialización Automática${NC}"
echo "==================================="
echo ""

if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creando archivo .env...${NC}"
    cat > .env <<'EOF'
MOSQUITTO_VERSION=latest
NODE_RED_VERSION=latest
INFLUXDB_VERSION=2.7
GRAFANA_VERSION=latest

MOSQUITTO_PORT=1883
MOSQUITTO_TLS_PORT=8883
MOSQUITTO_WS_PORT=9001
NODE_RED_PORT=1880
INFLUXDB_PORT=8086
GRAFANA_PORT=3000

TIMEZONE=Europe/Madrid

MOSQUITTO_USERNAME=admin
MOSQUITTO_PASSWORD=admin123

NODE_RED_CREDENTIAL_SECRET=quien-sabe-donde-estara-mi-clave-nodered

INFLUXDB_RETENTION=0
INFLUXDB_USERNAME=admin
INFLUXDB_PASSWORD=admin123
INFLUXDB_ORG=practicatest
INFLUXDB_BUCKET=mytestbuckett
INFLUXDB_ADMIN_TOKEN=quien-sabe-donde-estara-mi-clave-influx

COINGECKO_MQTT_QOS=0
COINGECKO_MQTT_RETAIN=false
COINGECKO_COINS=bitcoin,ethereum,solana
COINGECKO_FIAT=eur
COINGECKO_INTERVAL_SECONDS=600
COINGECKO_TOPIC_TEMPLATE=coingecko/{symbol}
COINGECKO_SYMBOL_MAP={"bitcoin":"BTC","ethereum":"ETH","solana":"SOL"}

GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123
GRAFANA_INSTALL_PLUGINS=
GRAFANA_ROOT_URL=http://localhost:3000
EOF
    echo -e "${GREEN}✓${NC} Archivo .env creado"
else
    echo -e "${GREEN}✓${NC} Archivo .env ya existe"
fi

if [ ! -f "docker-compose.yml" ]; then
    echo -e "${YELLOW}Creando archivo docker-compose.yml...${NC}"
    cat > docker-compose.yml <<'EOF'
services:
  mosquitto:
    image: sbd-mosquitto:latest
    build:
      context: ./mosquitto
      dockerfile: Dockerfile
    env_file:
      - .env
    ports:
      - "${MOSQUITTO_PORT}:1883"
      - "${MOSQUITTO_TLS_PORT}:8883"
      - "${MOSQUITTO_WS_PORT}:9001"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/log:/mosquitto/log
    restart: unless-stopped
    networks:
      - practice-network

  node-red:
    image: nodered/node-red:latest
    container_name: node-red
    ports:
      - "${NODE_RED_PORT}:1880"
    environment:
      - TZ=${TIMEZONE}
      - NODE_RED_CREDENTIAL_SECRET=${NODE_RED_CREDENTIAL_SECRET}
    volumes:
      - ./node-red/data:/data
    restart: unless-stopped
    depends_on:
      - mosquitto
    networks:
      - practice-network

  influxdb:
    image: influxdb:2.7.12-alpine
    container_name: influxdb
    ports:
      - "${INFLUXDB_PORT}:8086"
    volumes:
      - ./influxdb/data:/var/lib/influxdb2
      - ./influxdb/config:/etc/influxdb2
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=${INFLUXDB_USERNAME}
      - DOCKER_INFLUXDB_INIT_PASSWORD=${INFLUXDB_PASSWORD}
      - DOCKER_INFLUXDB_INIT_ORG=${INFLUXDB_ORG}
      - DOCKER_INFLUXDB_INIT_BUCKET=${INFLUXDB_BUCKET}
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${INFLUXDB_ADMIN_TOKEN}
      - DOCKER_INFLUXDB_INIT_RETENTION=${INFLUXDB_RETENTION}
    restart: unless-stopped
    depends_on:
      - node-red
    networks:
      - practice-network

  coingecko-mqtt:
    build:
      context: ./coingecko-mqtt
      dockerfile: Dockerfile
    container_name: coingecko-mqtt
    restart: unless-stopped
    environment:
      BROKER_HOST: mosquitto
      BROKER_PORT: ${MOSQUITTO_PORT}
      MQTT_USERNAME: ${MOSQUITTO_USERNAME}
      MQTT_PASSWORD: ${MOSQUITTO_PASSWORD}
      MQTT_QOS: ${COINGECKO_MQTT_QOS}
      MQTT_RETAIN: ${COINGECKO_MQTT_RETAIN}
      COINS: ${COINGECKO_COINS}
      FIAT: ${COINGECKO_FIAT}
      INTERVAL_SECONDS: ${COINGECKO_INTERVAL_SECONDS}
      TOPIC_TEMPLATE: ${COINGECKO_TOPIC_TEMPLATE}
      SYMBOL_MAP: ${COINGECKO_SYMBOL_MAP}
    networks:
      - practice-network
    depends_on:
      - mosquitto

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "${GRAFANA_PORT}:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_INSTALL_PLUGINS=${GRAFANA_INSTALL_PLUGINS}
      - GF_SERVER_ROOT_URL=${GRAFANA_ROOT_URL}
    volumes:
      - ./grafana:/var/lib/grafana
    networks:
      - practice-network
    depends_on:
      - influxdb

networks:
  practice-network:
EOF
    echo -e "${GREEN}✓${NC} Archivo docker-compose.yml creado"
else
    echo -e "${GREEN}✓${NC} Archivo docker-compose.yml ya existe"
fi

echo ""
echo -e "${YELLOW}Creando estructura de directorios...${NC}"

mkdir -p mosquitto/config
mkdir -p mosquitto/data
mkdir -p mosquitto/log

mkdir -p node-red/data

mkdir -p influxdb/data
mkdir -p influxdb/config

mkdir -p grafana

mkdir -p coingecko-mqtt

echo -e "${GREEN}✓${NC} Estructura de directorios creada"

echo ""
echo -e "${YELLOW}Creando configuración de Mosquitto...${NC}"

cat > mosquitto/config/mosquitto.conf <<'EOF'
# Mosquitto Configuration File

# Listener MQTT por defecto
listener 1883
protocol mqtt

# Listener MQTT seguro (TLS/SSL)
listener 8883
protocol mqtt
# cafile /mosquitto/config/ca.crt
# certfile /mosquitto/config/server.crt
# keyfile /mosquitto/config/server.key

# Listener WebSocket
listener 9001
protocol websockets

# Autenticación con archivo de contraseñas
allow_anonymous false
password_file /mosquitto/config/passwd

# Archivo de persistencia
persistence true
persistence_location /mosquitto/data/

# Logging
log_dest file /mosquitto/log/mosquitto.log
log_dest stdout
log_type error
log_type warning
log_type notice
log_type information

# ACL (descomentar para usar control de acceso)
# acl_file /mosquitto/config/acl

# Configuración de conexión
max_connections -1
EOF

echo -e "${GREEN}✓${NC} Configuración de Mosquitto creada"

echo ""
echo -e "${YELLOW}Creando Dockerfile de Mosquitto...${NC}"

cat > mosquitto/Dockerfile <<'EOF'
FROM eclipse-mosquitto:2
COPY passwd.sh /usr/local/bin/passwd.sh
RUN chmod +x /usr/local/bin/passwd.sh
ENV MOSQUITTO_USERNAME=""
ENV MOSQUITTO_PASSWORD=""
ENTRYPOINT ["/usr/local/bin/passwd.sh"]
CMD ["mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]
EOF

echo -e "${GREEN}✓${NC} Dockerfile de Mosquitto creado"

echo ""
echo -e "${YELLOW}Creando script de gestión de contraseñas de Mosquitto...${NC}"

cat > mosquitto/passwd.sh <<'EOF'
#!/bin/sh
set -eu
mkdir -p /mosquitto/config
if [ -n "${MOSQUITTO_USERNAME:-}" ] && [ -n "${MOSQUITTO_PASSWORD:-}" ]; then
  PASSFILE="/mosquitto/config/passwd"
  if [ ! -f "$PASSFILE" ]; then
    mosquitto_passwd -b -c "$PASSFILE" "$MOSQUITTO_USERNAME" "$MOSQUITTO_PASSWORD"
  else
    mosquitto_passwd -b "$PASSFILE" "$MOSQUITTO_USERNAME" "$MOSQUITTO_PASSWORD"
  fi
  chown mosquitto:mosquitto "$PASSFILE"
  chmod 600 "$PASSFILE"
else
  echo "Aviso: MOSQUITTO_USERNAME/MOSQUITTO_PASSWORD no definidos; se omitirá la generación de /mosquitto/config/passwd" >&2
fi
exec /docker-entrypoint.sh "$@"
EOF

chmod +x mosquitto/passwd.sh

echo -e "${GREEN}✓${NC} Script passwd.sh creado y permisos configurados"

echo ""
echo -e "${YELLOW}Creando archivos de coingecko-mqtt...${NC}"

cat > coingecko-mqtt/requirements.txt <<'EOF'
paho-mqtt==1.6.1
requests==2.32.3
tenacity==9.0.0
EOF

echo -e "${GREEN}✓${NC} requirements.txt creado"

cat > coingecko-mqtt/Dockerfile <<'EOF'
FROM python:3.11-slim

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Instalar dependencias del sistema (red/SSL) y Python
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Salud básica: el contenedor corre indefinidamente publicando
HEALTHCHECK --interval=1m --timeout=5s --start-period=20s CMD python -c "import socket; import os; s=socket.socket(); s.settimeout(3); s.connect((os.environ.get('BROKER_HOST','mosquitto'), int(os.environ.get('BROKER_PORT','1883')))); print('ok')"

CMD ["python", "app.py"]
EOF

echo -e "${GREEN}✓${NC} Dockerfile creado"

# Crear app.py
cat > coingecko-mqtt/app.py <<'EOF'
import os
import time
import json
import uuid
import requests
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
import paho.mqtt.client as mqtt
from datetime import datetime, timezone

# ------------------ Configuración por entorno ------------------
BROKER_HOST = os.getenv("BROKER_HOST", "mosquitto")
BROKER_PORT = int(os.getenv("BROKER_PORT", "1883"))
MQTT_USERNAME = os.getenv("MQTT_USERNAME")
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD")
MQTT_QOS = int(os.getenv("MQTT_QOS", "0"))
MQTT_RETAIN = os.getenv("MQTT_RETAIN", "false").lower() == "true"

# Plantilla de topic: p.ej. coingecko/BTC, coingecko/ETH
TOPIC_TEMPLATE = os.getenv("TOPIC_TEMPLATE", "coingecko/{symbol}")

# Monedas (CoinGecko IDs, no tickers): "bitcoin,ethereum,cardano"
COINS = os.getenv("COINS", "bitcoin,ethereum")
# Divisa de referencia
FIAT = os.getenv("FIAT", "eur")

# Frecuencia de consulta (segundos)
INTERVAL_SECONDS = int(os.getenv("INTERVAL_SECONDS", "600"))

# Base URL (público) y opción PRO/DEMO
CG_BASE_URL = os.getenv("CG_BASE_URL", "https://api.coingecko.com/api/v3")
CG_API_KEY = os.getenv("CG_API_KEY")  # opcional (Demo/Pro)
CG_TIMEOUT = float(os.getenv("CG_TIMEOUT", "10.0"))

# Mapeo opcional id->símbolo para el topic (si no, usamos el id)
SYMBOL_MAP = json.loads(os.getenv("SYMBOL_MAP", "{}"))  # {"bitcoin":"BTC","ethereum":"ETH"}

# ------------------ Cliente MQTT ------------------
client_id = f"coingecko_publisher_{uuid.uuid4().hex[:8]}"
mqttc = mqtt.Client(client_id=client_id, clean_session=True)
if MQTT_USERNAME:
    mqttc.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
mqttc.connect(BROKER_HOST, BROKER_PORT)

# ------------------ Helper HTTP con reintentos ------------------
class Http429(Exception): pass

def _headers():
    h = {"Accept": "application/json"}
    if CG_API_KEY:
        # CoinGecko acepta cabecera x-cg-pro-api-key o query param, usamos header
        h["x-cg-pro-api-key"] = CG_API_KEY
    return h

@retry(
    retry=retry_if_exception_type((requests.RequestException, Http429)),
    wait=wait_exponential(multiplier=1, min=2, max=60),
    stop=stop_after_attempt(5),
    reraise=True
)
def fetch_prices(ids: str, fiat: str):
    url = f"{CG_BASE_URL}/simple/price"
    params = {"ids": ids, "vs_currencies": fiat, "include_market_cap": "false",
              "include_24hr_vol": "false", "include_24hr_change": "true", "precision": "full"}
    resp = requests.get(url, params=params, headers=_headers(), timeout=CG_TIMEOUT)
    # Manejo de rate limit
    if resp.status_code == 429:
        # Respetar Retry-After si existe
        retry_after = int(resp.headers.get("Retry-After", "0"))
        if retry_after > 0:
            time.sleep(retry_after)
        raise Http429(f"Rate limited by CoinGecko (429). Headers: {dict(resp.headers)}")
    resp.raise_for_status()
    return resp.json()

def now_iso():
    return datetime.now(timezone.utc).isoformat()

# ------------------ Loop principal ------------------
def main():
    ids = ",".join([c.strip() for c in COINS.split(",") if c.strip()])
    fiat = FIAT.strip().lower()

    if not ids:
        raise SystemExit("COINS no puede estar vacío.")

    print(f"[INIT] Broker: {BROKER_HOST}:{BROKER_PORT} | Coins: {ids} | Fiat: {fiat} | Interval: {INTERVAL_SECONDS}s")
    if CG_API_KEY:
        print("[INIT] Usando CoinGecko API key (Demo/Pro). Ajusta límites según tu plan.")

    while True:
        try:
            data = fetch_prices(ids, fiat)
            ts = now_iso()
            # data ej: {"bitcoin":{"eur":64932.12,"eur_24h_change":-0.32}, "ethereum":{...}}
            for coin_id, payload in data.items():
                symbol = SYMBOL_MAP.get(coin_id, coin_id)
                topic = TOPIC_TEMPLATE.format(symbol=symbol.upper(), id=coin_id.lower())
                message = {
                    "coin_id": coin_id,
                    "symbol": symbol.upper(),
                    "fiat": fiat.upper(),
                    "price": payload.get(fiat),
                    "change_24h": payload.get(f"{fiat}_24h_change"),
                    "source": "coingecko",
                    "timestamp": ts
                }
                mqttc.publish(topic, json.dumps(message), qos=MQTT_QOS, retain=MQTT_RETAIN)
                print(f"[MQTT] {topic} => {message}")
        except Exception as e:
            print(f"[ERROR] {e}")

        time.sleep(INTERVAL_SECONDS)

if __name__ == "__main__":
    main()
EOF

echo -e "${GREEN}✓${NC} app.py creado"

echo -e "${GREEN}✓${NC} Archivos de coingecko-mqtt creados"

echo ""
echo -e "${YELLOW}Configurando permisos...${NC}"

sudo chown -R 1883:1883 mosquitto/ 2>/dev/null || chown -R 1883:1883 mosquitto/ 2>/dev/null || echo -e "${YELLOW}⚠ ${NC}  No se pudieron cambiar permisos de mosquitto (puede que necesites ejecutar con sudo)"

sudo chown -R 472:472 grafana/ 2>/dev/null || chown -R 472:472 grafana/ 2>/dev/null || echo -e "${YELLOW}⚠ ${NC}  No se pudieron cambiar permisos de grafana (puede que necesites ejecutar con sudo)"

chmod -R 755 node-red/ influxdb/ 2>/dev/null || echo -e "${YELLOW}⚠ ${NC}  Advertencia con permisos adicionales"

echo -e "${GREEN}✓${NC} Permisos configurados"

echo ""
echo -e "${YELLOW}Construyendo imágenes y iniciando servicios con Docker Compose...${NC}"
echo ""

docker-compose build

echo ""
echo -e "${GREEN}✓${NC} Imágenes construidas"
echo ""

docker-compose up -d

echo ""
echo -e "${GREEN}✓${NC} Servicios iniciados"

echo ""
echo -e "${YELLOW}Esperando a que los servicios estén listos...${NC}"
sleep 15

echo ""
echo -e "${YELLOW}Estado de los contenedores:${NC}"
docker-compose ps

echo ""
echo "==================================="
echo -e "${GREEN}  ¡Inicialización completada!${NC}"
echo "==================================="
echo ""
echo "Servicios disponibles:"
echo "  • Mosquitto MQTT:      (definido en .env MOSQUITTO_PORT)"
echo "  • Mosquitto MQTT TLS:  (definido en .env MOSQUITTO_TLS_PORT)"
echo "  • Mosquitto WebSocket: (definido en .env MOSQUITTO_WS_PORT)"
echo "  • Node-RED:            (definido en .env NODE_RED_PORT)"
echo "  • InfluxDB:            (definido en .env INFLUXDB_PORT)"
echo "  • Grafana:             (definido en .env GRAFANA_PORT)"
echo ""
echo "Credenciales Mosquitto:"
echo "  Usuario:  (definido en .env MOSQUITTO_USERNAME)"
echo "  Password: (definido en .env MOSQUITTO_PASSWORD)"
echo ""
echo "Credenciales InfluxDB:"
echo "  Usuario:  (definido en .env INFLUXDB_USERNAME)"
echo "  Password: (definido en .env INFLUXDB_PASSWORD)"
echo "  Org:      (definido en .env INFLUXDB_ORG)"
echo "  Bucket:   (definido en .env INFLUXDB_BUCKET)"
echo "  Token:    (definido en .env INFLUXDB_TOKEN)"
echo ""
echo "Credenciales Grafana:"
echo "  Usuario:  (definido en .env GRAFANA_ADMIN_USERNAME)"
echo "  Password: (definido en .env GRAFANA_ADMIN_PASSWORD)"
echo ""
echo "Comandos útiles:"
echo "  • Ver logs: docker-compose logs -f [servicio]"
echo "  • Detener: docker-compose down"
echo "  • Reiniciar: docker-compose restart [servicio]"
echo "  • Ver estado: docker-compose ps"
echo "  • Reconstruir: docker-compose build [servicio]"
echo ""
echo -e "${YELLOW}Nota:${NC} CoinGecko MQTT publicará precios en topics: coingecko/BTC, coingecko/ETH, coingecko/SOL"
echo -e "${YELLOW}Importante:${NC} Mosquitto requiere autenticación. Configura MOSQUITTO_USERNAME y MOSQUITTO_PASSWORD en .env"
echo ""