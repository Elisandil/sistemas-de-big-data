# Ventas BI — Hadoop + Hive + JasperReports

Entorno BI sobre Big Data: ingesta de datos en HDFS, consultas con Hive y generación de informes PDF con JasperReports. Todo se ejecuta con Docker Compose.

## Stack

| Capa           | Tecnología                          |
|----------------|-------------------------------------|
| Almacenamiento | Hadoop HDFS 2.7.4                   |
| Data Warehouse | Apache Hive 2.3.2 + PostgreSQL      |
| Reporting      | JasperReports 6.20.6               |
| Cliente        | Java 17, JDBC Hive                  |
| Orquestación   | Docker Compose                      |

## Estructura

```
ventas-bi/
├── docker-compose.yml      ← infraestructura + app
├── Dockerfile              ← build de la app Java
├── pom.xml
├── settings.xml
├── hadoop.env
├── datos/
│   └── datos_venta.csv
├── lib/
│   └── hive-jdbc-2.3.2.jar
├── output/                 ← aquí se genera el PDF
└── src/main/java/
    ├── App.java
    ├── modelo/
    ├── repositorio/
    ├── servicio/
    ├── controlador/
    └── vista/
```

## Arranque

### 1. Levantar infraestructura

```bash
docker compose up -d
docker compose ps          # esperar a que todo esté "healthy" (~2 min)
```

### 2. Cargar datos y crear tabla

```bash
docker cp datos/datos_venta.csv namenode:/tmp/datos_venta.csv
docker exec namenode hdfs dfs -mkdir -p /user/hive/warehouse/ventas_jasper
docker exec namenode hdfs dfs -put -f /tmp/datos_venta.csv /user/hive/warehouse/ventas_jasper/

docker exec -i hive-server beeline -u jdbc:hive2://hive-server:10000 -n hive -e "\
  DROP TABLE IF EXISTS ventas_reporte; \
  CREATE EXTERNAL TABLE ventas_reporte ( \
    id INT, producto STRING, categoria STRING, \
    cantidad INT, precio_unitario DOUBLE, fecha STRING \
  ) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' \
  STORED AS TEXTFILE \
  LOCATION '/user/hive/warehouse/ventas_jasper/';"
```

### 3. Generar informe PDF

```bash
docker compose up ventas-app --build
```

El PDF se genera en `./output/VentasPorCategoria.pdf`.

### Parada

```bash
docker compose down -v
```

## Modelo de datos

```sql
SELECT categoria,
       SUM(cantidad)                   AS unidades,
       SUM(cantidad * precio_unitario) AS ingresos
FROM ventas_reporte
GROUP BY categoria;
```

## Notas

- La app soporta modo GUI (Swing) y modo headless. Docker usa el modo headless.
- El puerto 10000 de HiveServer2 se expone como 10001 en el host.
- La URL JDBC es configurable vía la variable de entorno `HIVE_JDBC_URL`.