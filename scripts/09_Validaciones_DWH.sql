-- ============================================================
-- SCRIPT 09: VALIDACIONES DE CALIDAD — RRHH_DW
-- Base de Datos : RRHH_DW
-- Propósito     : 15 validaciones de calidad de datos que
--                 garantizan la integridad del DWH vs OLTP
-- Autora        : Hanna
-- Fecha         : 2026
-- ============================================================
-- FILOSOFÍA DE VALIDACIÓN:
--   Una validación que solo registra y nadie lee no sirve.
--   Las validaciones CRÍTICAS usan RAISERROR severidad 16 —
--   detienen el proceso ETL y fuerzan atención inmediata.
--   Las validaciones INFORMATIVAS registran en el log pero
--   no detienen el proceso.
--
-- CATEGORÍAS:
--   [CRÍTICA]     → detiene el proceso con RAISERROR
--   [INFORMATIVA] → registra en log, continúa el proceso
--   [MÉTRICA]     → indicador de calidad sin umbral de error
-- ============================================================

USE RRHH_DW;
GO

PRINT '============================================================';
PRINT 'INICIANDO VALIDACIONES DE CALIDAD — RRHH_DW';
PRINT 'Fecha: ' + CAST(GETDATE() AS VARCHAR);
PRINT '============================================================';
GO

-- ============================================================
-- VALIDACIÓN 01 — [CRÍTICA]
-- Completitud: todos los empleados OLTP llegaron al DWH
-- ============================================================
-- Si hay empleados en el OLTP que no tienen versión activa
-- en Dim_Empleado, el DWH está incompleto y los hechos
-- quedarán huérfanos o sin registrar.
-- ============================================================

DECLARE @V01_Faltantes INT;

SELECT @V01_Faltantes = COUNT(*)
FROM RRHH.hr.Empleados e
WHERE e.Activo = 1
  AND NOT EXISTS (
      SELECT 1 FROM dim.Dim_Empleado de
      WHERE de.EmpleadoID_OLTP = e.EmpleadoID
        AND de.EsVersionActual  = 1
  );

IF @V01_Faltantes > 0
    RAISERROR('❌ VAL-01 CRÍTICA: %d empleados activos del OLTP no están en Dim_Empleado. ETL incompleto.',
              16, 1, @V01_Faltantes);
ELSE
    PRINT '✓ VAL-01 PASÓ: Todos los empleados activos están en Dim_Empleado';
GO

-- ============================================================
-- VALIDACIÓN 02 — [CRÍTICA]
-- Integridad referencial: no deben existir hechos huérfanos
-- en Fact_Ausencias (EmpleadoSK sin match en Dim_Empleado)
-- ============================================================

DECLARE @V02_Huerfanos INT;

SELECT @V02_Huerfanos = COUNT(*)
FROM fact.Fact_Ausencias fa
WHERE NOT EXISTS (
    SELECT 1 FROM dim.Dim_Empleado de
    WHERE de.EmpleadoSK = fa.EmpleadoSK
);

IF @V02_Huerfanos > 0
    RAISERROR('❌ VAL-02 CRÍTICA: %d registros huérfanos en Fact_Ausencias. Integridad referencial comprometida.',
              16, 1, @V02_Huerfanos);
ELSE
    PRINT '✓ VAL-02 PASÓ: Fact_Ausencias sin registros huérfanos';
GO

-- ============================================================
-- VALIDACIÓN 03 — [CRÍTICA]
-- Completitud de hechos: conteo OLTP vs DWH en ausencias
-- Tolerancia: 0 — cada ausencia debe estar en el DWH
-- ============================================================

DECLARE @V03_OLTP INT, @V03_DWH INT, @V03_Diff INT;

SELECT @V03_OLTP = COUNT(*) FROM RRHH.hr.Ausencias;
SELECT @V03_DWH  = COUNT(*) FROM fact.Fact_Ausencias;
SET @V03_Diff = @V03_OLTP - @V03_DWH;

PRINT 'VAL-03 — Ausencias: OLTP=' + CAST(@V03_OLTP AS VARCHAR)
      + ' | DWH=' + CAST(@V03_DWH AS VARCHAR)
      + ' | Diferencia=' + CAST(@V03_Diff AS VARCHAR);

IF @V03_Diff > 0
    RAISERROR('❌ VAL-03 CRÍTICA: %d ausencias del OLTP no llegaron al DWH.',
              16, 1, @V03_Diff);
ELSE
    PRINT '✓ VAL-03 PASÓ: Conteo de ausencias OLTP = DWH';
GO

-- ============================================================
-- VALIDACIÓN 04 — [CRÍTICA]
-- Completitud de hechos: evaluaciones OLTP vs DWH
-- ============================================================

DECLARE @V04_OLTP INT, @V04_DWH INT, @V04_Diff INT;

SELECT @V04_OLTP = COUNT(*) FROM RRHH.hr.Evaluaciones;
SELECT @V04_DWH  = COUNT(*) FROM fact.Fact_Evaluaciones;
SET @V04_Diff = @V04_OLTP - @V04_DWH;

PRINT 'VAL-04 — Evaluaciones: OLTP=' + CAST(@V04_OLTP AS VARCHAR)
      + ' | DWH=' + CAST(@V04_DWH AS VARCHAR)
      + ' | Diferencia=' + CAST(@V04_Diff AS VARCHAR);

IF @V04_Diff > 0
    RAISERROR('❌ VAL-04 CRÍTICA: %d evaluaciones del OLTP no llegaron al DWH.',
              16, 1, @V04_Diff);
ELSE
    PRINT '✓ VAL-04 PASÓ: Conteo de evaluaciones OLTP = DWH';
GO

-- ============================================================
-- VALIDACIÓN 05 — [CRÍTICA]
-- Rango de calificaciones en Fact_Evaluaciones
-- Las calificaciones deben estar entre 1.0 y 5.0
-- ============================================================

DECLARE @V05_FueraRango INT;

SELECT @V05_FueraRango = COUNT(*)
FROM fact.Fact_Evaluaciones
WHERE Calificacion < 1.0 OR Calificacion > 5.0;

IF @V05_FueraRango > 0
    RAISERROR('❌ VAL-05 CRÍTICA: %d evaluaciones con calificación fuera del rango 1.0-5.0.',
              16, 1, @V05_FueraRango);
ELSE
    PRINT '✓ VAL-05 PASÓ: Todas las calificaciones en rango válido (1.0-5.0)';
GO

-- ============================================================
-- VALIDACIÓN 06 — [CRÍTICA]
-- Dim_Tiempo cubre todas las fechas de los hechos
-- Si una fecha de ausencia no está en Dim_Tiempo,
-- el ETL no pudo cargar ese registro.
-- ============================================================

DECLARE @V06_FechasSinDim INT;

SELECT @V06_FechasSinDim = COUNT(*)
FROM RRHH.hr.Ausencias a
WHERE NOT EXISTS (
    SELECT 1 FROM dim.Dim_Tiempo t WHERE t.Fecha = a.FechaInicio
)
OR NOT EXISTS (
    SELECT 1 FROM dim.Dim_Tiempo t WHERE t.Fecha = a.FechaFin
);

IF @V06_FechasSinDim > 0
    RAISERROR('❌ VAL-06 CRÍTICA: %d ausencias tienen fechas fuera del rango de Dim_Tiempo.',
              16, 1, @V06_FechasSinDim);
ELSE
    PRINT '✓ VAL-06 PASÓ: Dim_Tiempo cubre todas las fechas de ausencias';
GO

-- ============================================================
-- VALIDACIÓN 07 — [INFORMATIVA]
-- Ausencias sin justificación — monitoreo de ausentismo
-- No es un error, pero es un indicador de alerta de RRHH
-- ============================================================

DECLARE @V07_SinJustificar INT;
DECLARE @V07_Total         INT;
DECLARE @V07_Pct           DECIMAL(5,1);

SELECT @V07_SinJustificar = COUNT(*)
FROM fact.Fact_Ausencias
WHERE EsJustificada = 0;

SELECT @V07_Total = COUNT(*) FROM fact.Fact_Ausencias;

SET @V07_Pct = CAST(@V07_SinJustificar * 100.0 
                    / NULLIF(@V07_Total, 0) AS DECIMAL(5,1));

PRINT 'VAL-07 — Ausencias no justificadas: ' 
      + CAST(@V07_SinJustificar AS VARCHAR)
      + ' (' + CAST(@V07_Pct AS VARCHAR) + '% del total)';

IF @V07_SinJustificar > 5
    PRINT '⚠ VAL-07 ALERTA: Más de 5 ausencias no justificadas — revisar con RRHH';
ELSE
    PRINT '✓ VAL-07 PASÓ: Nivel de ausencias no justificadas dentro del umbral';
GO

-- ============================================================
-- VALIDACIÓN 08 — [INFORMATIVA]
-- Empleados sin evaluación en el DWH
-- Todos deben tener al menos una evaluación
-- ============================================================

DECLARE @V08_SinEval INT;

SELECT @V08_SinEval = COUNT(DISTINCT de.EmpleadoSK)
FROM dim.Dim_Empleado de
WHERE de.EsVersionActual = 1
  AND NOT EXISTS (
      SELECT 1 FROM fact.Fact_Evaluaciones fe
      WHERE fe.EmpleadoEvaluadoSK = de.EmpleadoSK
  );

PRINT 'VAL-08 — Empleados sin evaluación en DWH: ' + CAST(@V08_SinEval AS VARCHAR);

IF @V08_SinEval > 0
    PRINT '⚠ VAL-08 ALERTA: ' + CAST(@V08_SinEval AS VARCHAR)
          + ' empleados no tienen evaluación registrada en el DWH';
ELSE
    PRINT '✓ VAL-08 PASÓ: Todos los empleados tienen al menos una evaluación';
GO

-- ============================================================
-- VALIDACIÓN 09 — [CRÍTICA]
-- Consistencia SCD Tipo 2: cada empleado debe tener
-- exactamente UNA versión activa (EsVersionActual = 1)
-- Más de una versión activa indica corrupción del SCD.
-- ============================================================

DECLARE @V09_DuplicadosSCD INT;

SELECT @V09_DuplicadosSCD = COUNT(*)
FROM (
    SELECT EmpleadoID_OLTP, COUNT(*) AS Versiones
    FROM dim.Dim_Empleado
    WHERE EsVersionActual = 1
    GROUP BY EmpleadoID_OLTP
    HAVING COUNT(*) > 1
) AS Duplicados;

IF @V09_DuplicadosSCD > 0
    RAISERROR('❌ VAL-09 CRÍTICA: %d empleados tienen más de una versión activa en Dim_Empleado. SCD Tipo 2 corrupto.',
              16, 1, @V09_DuplicadosSCD);
ELSE
    PRINT '✓ VAL-09 PASÓ: SCD Tipo 2 íntegro — un empleado, una versión activa';
GO

-- ============================================================
-- VALIDACIÓN 10 — [CRÍTICA]
-- Snapshot headcount: debe existir un registro por cada
-- empleado activo en cada mes cargado
-- 55 empleados × 24 meses = 1,320 registros esperados
-- ============================================================

DECLARE @V10_Esperados INT = 55 * 24;
DECLARE @V10_Reales    INT;

SELECT @V10_Reales = COUNT(*) FROM fact.Fact_Headcount;

PRINT 'VAL-10 — Headcount: Esperados=' + CAST(@V10_Esperados AS VARCHAR)
      + ' | Reales=' + CAST(@V10_Reales AS VARCHAR);

IF @V10_Reales < @V10_Esperados
    RAISERROR('❌ VAL-10 CRÍTICA: Fact_Headcount tiene %d registros, se esperaban %d.',
              16, 1, @V10_Reales, @V10_Esperados);
ELSE
    PRINT '✓ VAL-10 PASÓ: Fact_Headcount completo (1,320 snapshots)';
GO

-- ============================================================
-- VALIDACIÓN 11 — [MÉTRICA]
-- Distribución de calificaciones de evaluación
-- Permite detectar sesgo del evaluador (todos 5.0 o todos 1.0)
-- ============================================================

PRINT '';
PRINT 'VAL-11 — Distribución de calificaciones de desempeño:';

SELECT
    CASE
        WHEN Calificacion >= 4.5 THEN '⭐ Excelente (4.5-5.0)'
        WHEN Calificacion >= 3.5 THEN '✓  Bueno    (3.5-4.4)'
        WHEN Calificacion >= 2.5 THEN '△  Regular  (2.5-3.4)'
        ELSE                          '▽  Bajo     (1.0-2.4)'
    END                              AS Rango,
    COUNT(*)                         AS Cantidad,
    CAST(COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER()
        AS DECIMAL(5,1))             AS Porcentaje
FROM fact.Fact_Evaluaciones
GROUP BY
    CASE
        WHEN Calificacion >= 4.5 THEN '⭐ Excelente (4.5-5.0)'
        WHEN Calificacion >= 3.5 THEN '✓  Bueno    (3.5-4.4)'
        WHEN Calificacion >= 2.5 THEN '△  Regular  (2.5-3.4)'
        ELSE                          '▽  Bajo     (1.0-2.4)'
    END
ORDER BY MIN(Calificacion) DESC;
GO

-- ============================================================
-- VALIDACIÓN 12 — [MÉTRICA]
-- Tasa de completitud de capacitaciones por departamento
-- ============================================================

PRINT '';
PRINT 'VAL-12 — Tasa de completitud de capacitaciones por departamento:';

SELECT
    de.Departamento,
    COUNT(*)                                              AS TotalAsignaciones,
    SUM(CASE WHEN fc.Estado = 'Completada' THEN 1 ELSE 0 END) AS Completadas,
    CAST(SUM(CASE WHEN fc.Estado = 'Completada' THEN 1 ELSE 0 END) * 100.0
         / NULLIF(COUNT(*), 0) AS DECIMAL(5,1))           AS PctCompletadas
FROM fact.Fact_Capacitaciones fc
JOIN dim.Dim_Empleado         de ON fc.EmpleadoSK = de.EmpleadoSK
                                 AND de.EsVersionActual = 1
GROUP BY de.Departamento
ORDER BY PctCompletadas DESC;
GO

-- ============================================================
-- VALIDACIÓN 13 — [INFORMATIVA]
-- Consistencia de fechas: FechaFin no puede ser antes
-- que FechaInicio en ausencias
-- ============================================================

DECLARE @V13_FechasInvalidas INT;

SELECT @V13_FechasInvalidas = COUNT(*)
FROM fact.Fact_Ausencias
WHERE FechaFinID < FechaInicioID;

IF @V13_FechasInvalidas > 0
    PRINT '⚠ VAL-13 ALERTA: ' + CAST(@V13_FechasInvalidas AS VARCHAR)
          + ' ausencias tienen FechaFin anterior a FechaInicio';
ELSE
    PRINT '✓ VAL-13 PASÓ: Todas las ausencias tienen fechas coherentes';
GO

-- ============================================================
-- VALIDACIÓN 14 — [MÉTRICA]
-- Cobertura de capacitaciones: % de empleados que tienen
-- al menos una capacitación registrada en el DWH
-- ============================================================

DECLARE @V14_TotalEmp    INT;
DECLARE @V14_ConCapacit  INT;

SELECT @V14_TotalEmp   = COUNT(DISTINCT EmpleadoSK)
FROM dim.Dim_Empleado WHERE EsVersionActual = 1;

SELECT @V14_ConCapacit = COUNT(DISTINCT EmpleadoSK)
FROM fact.Fact_Capacitaciones;

PRINT 'VAL-14 — Cobertura de capacitaciones: '
      + CAST(@V14_ConCapacit AS VARCHAR) + ' de '
      + CAST(@V14_TotalEmp AS VARCHAR) + ' empleados ('
      + CAST(CAST(@V14_ConCapacit * 100.0
             / NULLIF(@V14_TotalEmp, 0) AS DECIMAL(5,1)) AS VARCHAR) + '%)';
GO

-- ============================================================
-- VALIDACIÓN 15 — [MÉTRICA]
-- Consistencia salarial: salarios en DWH dentro del rango
-- del puesto definido en Dim_Puesto
-- Detecta si algún empleado gana fuera de la banda salarial
-- ============================================================

PRINT '';
PRINT 'VAL-15 — Empleados con salario fuera de banda salarial del puesto:';

SELECT
    de.NombreCompleto,
    de.NombrePuesto,
    dp.RangoSalarial,
    fh.SalarioMesUSD                AS SalarioActual,
    CASE
        WHEN fh.SalarioMesUSD < dp.SalarioMinUSD THEN 'Por debajo del mínimo'
        WHEN fh.SalarioMesUSD > dp.SalarioMaxUSD THEN 'Por encima del máximo'
    END                             AS Observacion
FROM fact.Fact_Headcount  fh
JOIN dim.Dim_Empleado     de ON fh.EmpleadoSK  = de.EmpleadoSK
                             AND de.EsVersionActual = 1
JOIN dim.Dim_Puesto       dp ON fh.PuestoSK    = dp.PuestoSK
                             AND dp.EsVersionActual = 1
JOIN dim.Dim_Tiempo       t  ON fh.FechaSnapshotID = t.TiempoID
WHERE t.AnioMes = '2024-12'   -- último snapshot disponible
  AND (fh.SalarioMesUSD < dp.SalarioMinUSD
    OR fh.SalarioMesUSD > dp.SalarioMaxUSD);
GO

-- ============================================================
-- RESUMEN EJECUTIVO DE VALIDACIONES
-- ============================================================

PRINT '';
PRINT '============================================================';
PRINT '📊 RESUMEN DE CALIDAD DEL DWH — RRHH_DW';
PRINT '';

SELECT
    'OLTP → DWH'             AS Verificacion,
    (SELECT COUNT(*) FROM RRHH.hr.Empleados   WHERE Activo = 1) AS OLTP,
    (SELECT COUNT(*) FROM dim.Dim_Empleado    WHERE EsVersionActual = 1) AS DWH
UNION ALL
SELECT
    'Ausencias',
    (SELECT COUNT(*) FROM RRHH.hr.Ausencias),
    (SELECT COUNT(*) FROM fact.Fact_Ausencias)
UNION ALL
SELECT
    'Evaluaciones',
    (SELECT COUNT(*) FROM RRHH.hr.Evaluaciones),
    (SELECT COUNT(*) FROM fact.Fact_Evaluaciones)
UNION ALL
SELECT
    'Capacitaciones',
    (SELECT COUNT(*) FROM RRHH.hr.EmpleadosCapacitaciones),
    (SELECT COUNT(*) FROM fact.Fact_Capacitaciones);
GO

PRINT '';
PRINT '============================================================';
PRINT '✅ SCRIPT 09 COMPLETADO — VALIDACIONES DE CALIDAD';
PRINT '';
PRINT '  15 validaciones ejecutadas';
PRINT '  6  validaciones CRÍTICAS    (RAISERROR si fallan)';
PRINT '  4  validaciones INFORMATIVAS (alerta en log)';
PRINT '  5  validaciones MÉTRICAS    (indicadores de calidad)';
PRINT '';
PRINT '  Siguiente paso: Ejecutar 10_Consultas_Analiticas.sql';
PRINT '============================================================';
GO