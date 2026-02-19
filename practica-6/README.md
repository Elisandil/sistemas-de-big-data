# Guía de Implementación del Flujo ETL en Apache NiFi

Esta guía detalla cómo configurar los procesadores en NiFi para cumplir con los requisitos de la práctica.

---

## 0. Prerrequisitos

NOTA: En el caso de no disponer de .csv ejecutar el archivo generar_datos.py, se encargará de todo.

* **Driver JDBC:** Descarga el driver JDBC de PostgreSQL (archivo `.jar`) y colócalo en la carpeta `nifi_data` que se creará al levantar Docker.
* **Acceso:** Accede a NiFi en -> Definido en el .env.template
    * **Usuario:** -> Definido en el .env.template
    * **Contraseña:** -> Definido en el .env.template

---

## El Flujo Paso a Paso

### Resumen del Flujo Gráfico   

```
GetFile -> SplitText -> ExtractText -> RouteOnAttribute (Validar) -> DetectDuplicate
                                            |                         |
                                            | (Fallo)                 | (Duplicado)
                                            v                         v
                                       MergeContent ----------> PutFile (Rechazados)
                                            |
                                            | (Éxito / Non-Duplicate)
                                            v
                                     UpdateAttribute (Transformar)
                                            |
                    ________________________|________________________
                   |                                                 |
            ReplaceText (CSV)                                   PutSQL (DB)
                   |                                                 |
             MergeContent                                      (Finalizado)
                   |
            PutFile (Limpios)
```
NOTA: Debería de haber hecho una captura de pantalla en NiFi, pero se me ha olvidado.

### Paso 1: Lectura del CSV
**Processor:** `GetFile`

* **Input Directory:** `/opt/nifi/nifi-current/data_exchange` (Mapeada a tu carpeta local `nifi_data`).
* **Keep Source File:** `false` (Para evitar bucles de lectura).

### Paso 2: Dividir el archivo en líneas
**Processor:** `SplitText`

* **Line Split Count:** `1` (Procesamos registro a registro).

### Paso 3: Extraer atributos (Parsing)
**Processor:** `ExtractText`

Utilizaremos Expresiones Regulares para convertir las líneas CSV en atributos de NiFi. Añade las siguientes **Propiedades Dinámicas (+)**:

| Propiedad | Expresión Regular |
| :--- | :--- |
| `csv.nombre` | `^([^,]*),.*` |
| `csv.apellidos` | `^[^,]*,([^,]*),.*` |
| `csv.fecha` | `^[^,]*,[^,]*,([^,]*),.*` |
| `csv.pedidos` | `^[^,]*,[^,]*,[^,]*,([^,]*),.*` |
| `csv.ciudad` | `^[^,]*,[^,]*,[^,]*,[^,]*,([^,]*).*` |

> **Nota:** Una forma más limpia es usar `QueryRecord` o `CSVReader`, pero he utilizado `ExtractText` 

### Paso 4: Detección de Errores (Calidad de Datos)
Aquí bifurcamos el flujo en dos subpasos:

#### A. Detectar Vacíos
**Processor:** `RouteOnAttribute`
* **Routing Strategy:** `Route to Property name`

| Nombre de Propiedad | Expresión (NiFi Expression Language) |
| :--- | :--- |
| **incompleto** | `${csv.nombre:isEmpty():or(${csv.apellidos:isEmpty()}):or(${csv.ciudad:isEmpty()})}` |
| **valido** | `${csv.nombre:isEmpty():not():and(${csv.apellidos:isEmpty():not()}):and(${csv.ciudad:isEmpty():not()})}` |

#### B. Detectar Duplicados (Solo para los 'validos')
**Processor:** `DetectDuplicate`
* **Cache Entry Identifier:** `${csv.nombre}|${csv.apellidos}|${csv.fecha}`
* **Relación:** `duplicate` va a Rechazados, `non-duplicate` sigue el proceso.

### Paso 5: Gestión de Rechazados
Conecta las relaciones `incompleto` (4A) y `duplicate` (4B) aquí.

1.  **Processor `ReplaceText`:** (Opcional) Indica el motivo del fallo o mantén el contenido original.
2.  **Processor `MergeContent`:** Agrupa los registros para evitar archivos minúsculos.
3.  **Processor `PutFile`:**
    * **Directory:** `/opt/nifi/nifi-current/data_exchange`
    * **Filename:** `clientes_rechazados.csv`

### Paso 6: Transformación y Normalización (Para 'non-duplicate')
**Processor:** `UpdateAttribute`

Añade las siguientes propiedades para normalizar los datos:

* `nombre_clean`: `${csv.nombre:toUpper()}`
* `apellidos_clean`: `${csv.apellidos:toUpper()}`
* `ciudad_clean`: `${csv.ciudad:toUpper()}`
* `fecha_espanol`: `${csv.fecha:toDate('MM/dd/yyyy'):format('dd/MM/yyyy')}` (Para CSV de salida).
* `fecha_postgres`: `${csv.fecha:toDate('MM/dd/yyyy'):format('yyyy-MM-dd')}` (Para la DB).

### Paso 7: Generar CSV Limpio
1.  **Processor `ReplaceText`:**
    * **Replacement Value:** `${nombre_clean},${apellidos_clean},${fecha_espanol},${csv.pedidos},${ciudad_clean}`
2.  **Processor `MergeContent`:** Agrupa los registros.
3.  **Processor `PutFile`:**
    * **Directory:** `/opt/nifi/nifi-current/data_exchange`
    * **Filename:** `clientes_limpios.csv`

### Paso 8: Insertar en PostgreSQL
Desde el `UpdateAttribute` (Paso 6), saca una segunda flecha hacia:

**Processor:** `PutSQL`

#### Configuración del Controller Service (DBCPConnectionPool):
* **Database Connection URL:** `jdbc:postgresql://postgres_db:5432/OLTP`
* **Driver Class Name:** `org.postgresql.Driver`
* **Driver Location:** `/opt/nifi/nifi-current/data_exchange/postgresql-42.x.x.jar`
* **User:** `alumno`
* **Password:** `secreto_ies_alandalus`

#### Configuración de la sentencia SQL:
```sql
INSERT INTO Clientes (nombre, apellidos, fecha_registro, num_pedidos, ciudad)
VALUES ('${nombre_clean}', '${apellidos_clean}', '${fecha_postgres}'::DATE, ${csv.pedidos}, '${ciudad_clean}')
```