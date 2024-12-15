-- **INFORME 1: Resumen de clientes por REGIÓN**
-- Requerimientos:
-- - Mostrar regiones, cantidad de clientes con más de 20 años inscritos y total general de clientes por REGIÓN.
-- - Ordenar los resultados por cantidad de clientes con más de 20 años inscritos (ascendente).
-- - Crear índices para optimizar las consultas.

-- Crear índice IDX_COD_REGION para optimizar búsquedas por región
CREATE INDEX IDX_COD_REGION ON CLIENTE (COD_REGION);
CREATE INDEX IDX_CLI_REGION ON CLIENTE (COD_REGION, FECHA_INSCRIPCION);

EXPLAIN PLAN FOR
SELECT 
    NVL(R.COD_REGION || ' - ' || R.NOMBRE_REGION, 'SIN REGIÓN') AS NOMBRE_REGION,
    COUNT(CASE WHEN (SYSDATE - C.FECHA_INSCRIPCION) >= (20 * 365) THEN 1 END) AS CLIENTES_20_ANIOS,
    COUNT(*) AS TOTAL_CLIENTES
FROM CLIENTE C
INNER JOIN REGION R 
    ON C.COD_REGION = R.COD_REGION
GROUP BY R.COD_REGION, R.NOMBRE_REGION
HAVING COUNT(*) > 0;

SELECT * 
FROM TABLE(DBMS_XPLAN.DISPLAY);


-- Crear vista para el informe de clientes por región
CREATE OR REPLACE VIEW VISTA_RESUMEN_REGIONES AS
SELECT 
    NVL(R.COD_REGION || ' - ' || R.NOMBRE_REGION, 'SIN REGIÓN') AS NOMBRE_REGION,
    COUNT(CASE WHEN (SYSDATE - C.FECHA_INSCRIPCION) >= (20 * 365) THEN 1 END) AS CLIENTES_20_ANIOS,
    COUNT(*) AS TOTAL_CLIENTES
FROM CLIENTE C
INNER JOIN REGION R 
    ON C.COD_REGION = R.COD_REGION
GROUP BY R.COD_REGION, R.NOMBRE_REGION
HAVING COUNT(*) > 0
ORDER BY CLIENTES_20_ANIOS ASC;

-- **INFORME 2: Transacciones con vencimientos en el segundo semestre**
-- Requerimientos:
-- - Visualizar transacciones con vencimientos entre junio y diciembre.
-- - Mostrar descripción y promedio de montos, ordenados ascendentemente.
-- - Generar dos alternativas (SET y Subconsulta).
-- - Actualizar la tasa de interés según los datos generados.

--Informe 1 alternartiva 1

SELECT 
    TO_CHAR(tr.fecha_transaccion, 'DD-MM-YYYY') AS FECHA,
    t.cod_tptran_tarjeta AS CODIGO,
    t.nombre_tptran_tarjeta AS DESCRIPCION,
    ROUND(AVG(NVL(tr.monto_total_transaccion, 0))) AS MONTO_PROMEDIO
FROM transaccion_tarjeta_cliente tr
INNER JOIN tipo_transaccion_tarjeta t 
    ON tr.cod_tptran_tarjeta = t.cod_tptran_tarjeta
WHERE EXTRACT(MONTH FROM tr.fecha_transaccion) BETWEEN 6 AND 12
GROUP BY tr.fecha_transaccion, t.cod_tptran_tarjeta, t.nombre_tptran_tarjeta
ORDER BY MONTO_PROMEDIO ASC;


---informe 2 Alternnativa 2
CREATE TABLE SELECCION_TIPO_TRANSACCION AS
SELECT 
    TO_CHAR(tr.fecha_transaccion, 'DD-MM-YYYY') AS FECHA,
    t.cod_tptran_tarjeta AS COD_TIPO_TRANSAC,
    t.nombre_tptran_tarjeta AS NOMBRE_TIPO_TRANSAC,
    ROUND(AVG(NVL(tr.monto_total_transaccion, 0)), 2) AS MONTO_PROMEDIO
FROM transaccion_tarjeta_cliente tr
INNER JOIN tipo_transaccion_tarjeta t 
    ON tr.cod_tptran_tarjeta = t.cod_tptran_tarjeta
WHERE EXTRACT(MONTH FROM tr.fecha_transaccion) BETWEEN 6 AND 12
  AND tr.monto_total_transaccion IS NOT NULL
GROUP BY t.cod_tptran_tarjeta, t.nombre_tptran_tarjeta, TO_CHAR(tr.fecha_transaccion, 'DD-MM-YYYY')
ORDER BY MONTO_PROMEDIO ASC;

-- Consultar la tabla
SELECT 
    fecha AS FECHA,
    cod_tipo_transac AS COD_TIPO_TRANSAC,
    nombre_tipo_transac AS NOMBRE_TIPO_TRANSAC,
    monto_promedio AS MONTO_PROMEDIO
FROM seleccion_tipo_transaccion
ORDER BY MONTO_PROMEDIO ASC;

SELECT 
    NOMBRE_TIPO_TRANSAC, 
    MONTO_PROMEDIO
FROM SELECCION_TIPO_TRANSACCION
WHERE MONTO_PROMEDIO > 500000
UNION
SELECT 
    t.nombre_tptran_tarjeta AS NOMBRE_TIPO_TRANSAC, 
    0 AS MONTO_PROMEDIO
FROM tipo_transaccion_tarjeta t
WHERE t.nombre_tptran_tarjeta LIKE '%Avance%'
ORDER BY MONTO_PROMEDIO ASC;


-- Actualización de la tasa de interés
UPDATE TIPO_TRANSACCION_TARJETA TTT
SET TTT.TASAINT_TPTRAN_TARJETA = TTT.TASAINT_TPTRAN_TARJETA * 0.99
WHERE TTT.COD_TPTRAN_TARJETA IN (
    SELECT STT.COD_TIPO_TRANSAC 
    FROM SELECCION_TIPO_TRANSACCION STT
);
COMMIT;

-- Crear vista para las tasas actualizadas
CREATE OR REPLACE VIEW VISTA_TASA_INTERES_ACTUALIZADA AS
SELECT 
    ttt.cod_tptran_tarjeta AS CODIGO_TRANSACCION,
    ttt.nombre_tptran_tarjeta AS NOMBRE_TRANSACCION,
    ttt.tasaint_tptran_tarjeta AS TASA_INTERES_ACTUALIZADA
FROM tipo_transaccion_tarjeta ttt
WHERE ttt.cod_tptran_tarjeta IN (
    SELECT stt.cod_tipo_transac 
    FROM seleccion_tipo_transaccion stt
);

-- Paso 2: Consultar desde la Tabla seleccion_tipo_transaccion

SELECT 
    fecha AS FECHA,
    cod_tipo_transac AS COD_TIPO_TRANSAC,
    nombre_tipo_transac AS NOMBRE_TIPO_TRANSAC,
    monto_promedio AS MONTO_PROMEDIO
FROM seleccion_tipo_transaccion
ORDER BY monto_promedio ASC;

-- Agregar comentarios finales al script explicando el razonamiento detrás de cada paso
-- 1. El informe 1 aprovecha el índice IDX_COD_REGION para evitar escaneos completos.
-- 2. Las funciones de fechas se usan para calcular dinámicamente los clientes con más de 20 años inscritos.
-- 3. El informe 2 ofrece dos enfoques: operador SET (rápido pero menos flexible) y subconsulta (más versátil).
-- 4. La tasa de interés se ajusta con base en la tabla temporal generada por la alternativa 2.


