# Documentación Técnica - Stack MING para Monitorización de Criptomonedas

## 1. Introducción

Este documento describe la implementación de un stack MING (Mosquitto, InfluxDB, Node-RED, Grafana) para la monitorización en tiempo real del precio de Bitcoin desde la API pública de CoinGecko.

### 1.1 Objetivos del Proyecto

- Desplegar infraestructura de observabilidad usando contenedores Docker
- Implementar pipeline de ingesta de datos desde API REST externa
- Almacenar series temporales en base de datos especializada
- Visualizar métricas en tiempo real con dashboard interactivo

## 2. Arquitectura General

### 2.1 Diagrama de Flujo de Datos

```
┌─────────────────┐
│  CoinGecko API  │ (Consulta cada 10 minutos)
└────────┬────────┘
         │ HTTPS
         ▼
┌─────────────────┐
│ coingecko-mqtt  │ (Servicio Python)
│   Publisher     │
└────────┬────────┘
         │ MQTT (topic: coingecko/BTC)
         ▼
┌─────────────────┐
│    Mosquitto    │ (Broker MQTT)
│   Port 1883     │
└────────┬────────┘
         │ MQTT Subscribe
         ▼
┌─────────────────┐
│    Node-RED     │ (Orquestador)
│   Port 1880     │ - Parser JSON
│                 │ - Transform data
└────────┬────────┘
         │ HTTP/InfluxDB Line Protocol
         ▼
┌─────────────────┐
│    InfluxDB     │ (TSDB)
│   Port 8086     │ - Bucket: crypto_data
│                 │ - Measurement: crypto_price
└────────┬────────┘
         │ Flux Query Language
         ▼
┌─────────────────┐
│     Grafana     │ (Visualización)
│   Port 3000     │ - Dashboard interactivo
└─────────────────┘
```

### 2.2 Componentes del Stack

| Componente | Tecnología | Versión | Función |
|------------|------------|---------|---------|
| **MQTT Broker** | Eclipse Mosquitto | 2 | Mensajería pub/sub |
| **Data Orchestrator** | Node-RED | latest | ETL y lógica de negocio |
| **Time Series DB** | InfluxDB | 2.7.12 | Almacenamiento persistente |
| **Visualization** | Grafana | latest | Dashboards y alertas |
| **Data Publisher** | Python 3.11 | custom | Recolector de API |

## 3. Implementación Detallada

### 3.1 Servicio coingecko-mqtt (Publisher)

**Responsabilidades**:
- Consultar API de CoinGecko cada 10 minutos
- Publicar datos en MQTT con formato JSON estandarizado
- Mantener conexión persistente con broker MQTT

**Configuración clave**:
```python
INTERVAL_SECONDS = 600
TOPIC_TEMPLATE = "coingecko/{symbol}"
COINS = "bitcoin"
FIAT = "eur"
```

**Formato de mensaje publicado**:
```json
{
  "coin_id": "bitcoin",
  "symbol": "BTC",
  "fiat": "EUR",
  "price": 64932.12,
  "change_24h": -0.32,
  "source": "coingecko",
  "timestamp": "2025-10-24T10:30:00.000Z"
}
```

**Justificación del diseño**:
- **Separación de responsabilidades**: El publisher solo se encarga de obtener datos
- **Retry logic**: Uso de `tenacity` para manejar rate limits de CoinGecko
- **Timestamp del origen**: Se preserva el timestamp de la API para precisión
- **Topic hierarchy**: Uso de `coingecko/BTC` permite escalabilidad a múltiples criptos

### 3.2 Mosquitto MQTT Broker

**Configuración de seguridad**:
```
allow_anonymous false
password_file /mosquitto/config/passwd
```

**Listeners configurados**:
- Puerto 1883: MQTT estándar (interno Docker)
- Puerto 8883: MQTT con TLS (preparado para producción)
- Puerto 9001: WebSocket (para clientes web)

**Justificación**:
- **Autenticación obligatoria**: Previene acceso no autorizado
- **Multi-protocolo**: Flexibilidad para diferentes tipos de clientes
- **Persistencia**: Los mensajes se guardan en disco ante reinicios

### 3.3 Node-RED (Orquestador ETL)

**Nodo Function - Transformación de datos**:
```javascript
const data = msg.payload;

msg.payload = {
    measurement: 'crypto_price',
    tags: {
        symbol: data.symbol,        
        currency: data.fiat,         
        source: data.source          
    },
    fields: {
        price: data.price,           
        change_24h: data.change_24h  
    },
    timestamp: new Date(data.timestamp)
};

return msg;
```

**Justificación del diseño**:
- **Visual programming**: Facilita debugging y modificaciones
- **Validación implícita**: El JSON parser falla si el mensaje está corrupto
- **Transformación explícita**: Separación clara entre formato MQTT e InfluxDB
- **Debug node**: Logging para troubleshooting en desarrollo

### 3.4 Esquema de Datos en InfluxDB

#### 3.4.1 Diseño del Measurement

**Measurement**: `crypto_price`

**Tags** (indexados, alta cardinalidad):
- `symbol`: Identificador de la criptomoneda (BTC, ETH, SOL)
- `currency`: Moneda fiat de referencia (EUR, USD)
- `source`: Origen de los datos (coingecko, binance, etc.)

**Fields** (valores numéricos):
- `price` (float): Precio actual de la criptomoneda
- `change_24h` (float): Porcentaje de cambio en 24 horas

**Timestamp**: UTC, heredado del mensaje MQTT

#### 3.4.2 Justificación del Esquema

**¿Por qué estos tags?**

1. **symbol**: 
   - Permite filtrado eficiente por criptomoneda
   - Facilita queries multi-crypto: `filter(fn: (r) => r["symbol"] =~ /BTC|ETH/)`
   - Indexado para búsquedas rápidas

2. **currency**:
   - Permite comparativas BTC/EUR vs BTC/USD
   - Esencial para análisis multi-divisa
   - Cardinalidad baja (EUR, USD, GBP) = óptimo para indexación

3. **source**:
   - Preparado para múltiples fuentes de datos
   - Permite validación cruzada (CoinGecko vs Binance)
   - Trazabilidad de origen de datos

**¿Por qué estos fields?**

1. **price**:
   - Valor principal del análisis
   - Tipo float para precisión decimal
   - No es tag porque varía constantemente (alta cardinalidad)

2. **change_24h**:
   - Métrica calculada por CoinGecko
   - Ahorra procesamiento en Grafana
   - Permite alertas basadas en volatilidad

#### 3.4.3 Optimizaciones

```flux
// Query optimizada con pre-filtrado
from(bucket: "crypto_data")
  |> range(start: -1h)                    // 1. Filtro temporal primero
  |> filter(fn: (r) => r._measurement == "crypto_price")  // 2. Measurement
  |> filter(fn: (r) => r.symbol == "BTC") // 3. Tags indexados
  |> filter(fn: (r) => r._field == "price") // 4. Field específico
```

**Orden de filtros**:
1. `range()`: Reduce set de datos por tiempo (más restrictivo)
2. Tags indexados: Aprovecha índices
3. Fields: Filtro final en datos ya reducidos

### 3.5 Dashboard de Grafana

#### 3.5.1 Panel 1: Precio Actual (Gauge)

**Tipo**: Gauge
**Refresh**: 1 minuto

**Query Flux**:
```flux
from(bucket: "crypto_data")
  |> range(start: -1m)
  |> filter(fn: (r) => r["_measurement"] == "crypto_price")
  |> filter(fn: (r) => r["_field"] == "price")
  |> filter(fn: (r) => r["symbol"] == "BTC")
  |> last()
```

**Configuración visual**:
- **Thresholds**:
  - Base (0-50000): Amarillo
  - 50000-70000: Verde
  - >70000: Rojo
- **Unit**: Currency → Euro (€)
- **Decimals**: 2

**Justificación**:
- `range(start: -1m)`: Solo último minuto (eficiencia)
- `last()`: Último valor registrado
- Gauge muestra visualmente si el precio está en rango "normal"

#### 3.5.2 Panel 2: Serie Temporal Última Hora

**Tipo**: Time Series
**Refresh**: 1 minuto

**Query Flux**:
```flux
from(bucket: "crypto_data")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "crypto_price")
  |> filter(fn: (r) => r["_field"] == "price")
  |> filter(fn: (r) => r["symbol"] == "BTC")
```

**Configuración**:
- **Interpolación**: Linear
- **Line width**: 2
- **Fill opacity**: 10%
- **Tooltip**: All series

**Justificación**:
- Ventana de 1 hora muestra tendencia reciente sin saturar
- Con datos cada 10 min → 6 puntos por hora (balance visualización/granularidad)
- Interpolación lineal suaviza la curva

#### 3.5.3 Panel 3: Tendencia 24h (Stat)

**Tipo**: Stat
**Refresh**: 1 minuto

**Query Flux**:
```flux
from(bucket: "crypto_data")
  |> range(start: -1m)
  |> filter(fn: (r) => r["_measurement"] == "crypto_price")
  |> filter(fn: (r) => r["_field"] == "change_24h")
  |> filter(fn: (r) => r["symbol"] == "BTC")
  |> last()
```

**Configuración**:
- **Color mode**: Background
- **Graph mode**: None
- **Text size**: Title 16px, Value 48px
- **Value mappings**:
  - `> 0`: "↑ {value}%"
  - `< 0`: "↓ {value}%"
  - `= 0`: "→ {value}%"
- **Thresholds**:
  - Base (<0): Red (bajada)
  - 0: White (neutral)
  - \>0: Green (subida)

**Justificación**:
- CoinGecko ya calcula `change_24h` → no necesitamos computar en Grafana
- Stat panel con fondo coloreado = alta visibilidad
- Iconos ↑↓→ mejoran comprensión instantánea

**Alternativa implementable** (cálculo en Grafana):
```flux
// Precio actual
price_now = from(bucket: "crypto_data")
  |> range(start: -1m)
  |> filter(fn: (r) => r._field == "price")
  |> last()

// Precio hace 24h
price_24h = from(bucket: "crypto_data")
  |> range(start: -24h, stop: -23h)
  |> filter(fn: (r) => r._field == "price")
  |> first()

// Calcular diferencia porcentual
join(tables: {now: price_now, past: price_24h}, on: ["symbol"])
  |> map(fn: (r) => ({
      r with
      change_pct: (r._value_now - r._value_past) / r._value_past * 100.0
  }))
```

## 4. Configuración de Red y Seguridad

### 4.1 Red Docker Interna

**Network**: `iot-network` (bridge driver)

**Ventajas**:
- Aislamiento del host
- Resolución DNS automática entre contenedores
- Comunicación interna sin exponer puertos innecesarios

**Mapeo de puertos expuestos**:
```yaml
- Mosquitto: 1883, 8883, 9001 → Host
- Node-RED: 1880 → Host
- InfluxDB: 8086 → Host
- Grafana: 3000 → Host
- coingecko-mqtt: Sin puertos expuestos (solo comunicación interna)
```