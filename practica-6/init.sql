CREATE TABLE IF NOT EXISTS Clientes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100),
    apellidos VARCHAR(100),
    fecha_registro DATE,
    num_pedidos INT,
    ciudad VARCHAR(100)
);