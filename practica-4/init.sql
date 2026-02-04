CREATE DATABASE IF NOT EXISTS OLTP;
USE OLTP;

CREATE TABLE IF NOT EXISTS Clientes (
    nombre VARCHAR(100),
    apellidos VARCHAR(100),
    fecha_registro DATE,
    total_pedidos INT,
    ciudad VARCHAR(100)
);