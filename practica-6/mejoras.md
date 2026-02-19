# Posibles mejoras:

### 1. Ingesta de datos en tiempo real desde el Internet de las Cosas (IoT)

En la práctica hemos procesado un lote estático (un archivo CSV). Sin embargo, NiFi brilla en el procesamiento de streaming. Podría utilizarse para escuchar miles de sensores de temperatura en tiempo real mediante protocolos como MQTT o Kafka, filtrar las lecturas anómalas al vuelo y enviar alertas a un sistema de mensajería (como Slack o un correo electrónico) antes de guardar los datos en la base de datos.

### 2. Enrutamiento dinámico y creación de APIs (Webhooks)
NiFi no solo lee archivos; puede actuar como un servidor web. Usando procesadores como HandleHttpRequest y HandleHttpResponse, NiFi puede recibir peticiones HTTP (por ejemplo, cuando un cliente hace una compra en una web), extraer el cuerpo del mensaje en formato JSON, y dependiendo del país del cliente, enrutar esa información a un sistema de facturación en Europa o a otro en América de forma totalmente dinámica.

### 3. Ciberseguridad y anonimización de logs
En entornos corporativos, NiFi se usa mucho para leer archivos de registro (logs) de cientos de servidores simultáneamente. Una posibilidad de uso sería capturar todos estos logs, utilizar procesadores para enmascarar o eliminar datos sensibles (como tarjetas de crédito, contraseñas o información personal, cumpliendo con la RGPD) y luego enviar el resultado limpio a un motor de búsqueda como Elasticsearch para que los analistas de seguridad lo revisen.

### 4. Migración hacia arquitecturas Cloud (Data Lakes)
En lugar de insertar los datos en un PostgreSQL local, NiFi dispone de procesadores nativos para conectarse con la nube. Podríamos haber usado la herramienta para hacer una migración híbrida: manteniendo los datos limpios en la base de datos local (OLTP), pero enviando una copia en formato Parquet a un Data Lake en la nube (como Amazon S3, Google Cloud Storage o Azure Blob Storage) para que el departamento de Machine Learning pueda entrenar modelos predictivos sin sobrecargar la base de datos principal.