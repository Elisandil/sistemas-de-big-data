#!/bin/bash
set -e

# 1) Copiar CSV al contenedor namenode
docker cp datos/datos_venta.csv namenode:/tmp/datos_venta.csv

# 2) Crear directorio HDFS y subir el fichero
docker exec namenode hdfs dfs -mkdir -p /user/hive/warehouse/ventas_jasper
docker exec namenode hdfs dfs -put -f /tmp/datos_venta.csv /user/hive/warehouse/ventas_jasper/

# 3) Crear tabla externa en Hive
docker exec -i hive-server beeline -u jdbc:hive2://hive-server:10000 -n hive <<EOF
DROP TABLE IF EXISTS ventas_reporte;
CREATE EXTERNAL TABLE ventas_reporte (
    id              INT,
    producto        STRING,
    categoria       STRING,
    cantidad        INT,
    precio_unitario DOUBLE,
    fecha           STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/hive/warehouse/ventas_jasper/';

SELECT categoria, SUM(cantidad) AS unidades, SUM(cantidad*precio_unitario) AS ingresos
FROM ventas_reporte
GROUP BY categoria;
EOF