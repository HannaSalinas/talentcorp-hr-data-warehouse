-- ============================================================
-- SCRIPT 08: ETL — CARGAR TABLAS DE HECHOS
-- Base de Datos : RRHH_DW
-- Propósito     : Ejecutar los procedimientos ETL para poblar
--                 las 4 tablas de hechos desde el OLTP RRHH
-- Autora        : Hanna
-- Fecha         : 2026
-- ============================================================
-- ORDEN DE CARGA DE HECHOS:
--   1. Fact_Ausencias      → depende de Dim_Empleado, Dim_Tiempo,
--                            Dim_Departamento, Dim_TipoAusencia
--   2. Fact_Evaluaciones   → depende de Dim_Empleado (x2),
--                            Dim_Departamento, Dim_Puesto, Dim_Tiempo
--   3. Fact_Capacitaciones → depende de Dim_Empleado,
--                            Dim_Capacitacion, Dim_Departamento
--   4. Fact_Headcount      → snapshot mensual — se genera por
--                            cada mes del período 2023-2024
-- ============================================================

USE RRHH_DW;
GO

PRINT '============================================================';
PRINT 'INICIANDO CARGA ETL — TABLAS DE HECHOS';
PRINT 'Fecha: ' + CAST(GETDATE() AS VARCHAR);
PRINT '============================================================';
GO

-- ============================================================
-- 1. CARGAR Fact_Ausencias
-- ============================================================

EXEC ctrl.usp_CargarFactAusencias;
GO

SELECT
    COUNT(*)               AS TotalAusencias,
    SUM(DiasTotales)       AS TotalDias,
    AVG(CAST(DiasTotales AS DECIMAL(5,1))) AS PromedioDias,
    SUM(CAST(EsJustificada AS INT))        AS Justificadas,
    COUNT(*) - SUM(CAST(EsJustificada AS INT)) AS NoJustificadas
FROM fact.Fact_Ausencias;
GO

-- ============================================================
-- 2. CARGAR Fact_Evaluaciones
-- ============================================================

EXEC ctrl.usp_CargarFactEvaluaciones;
GO

SELECT
    COUNT(*)                                   AS TotalEvaluaciones,
    AVG(Calificacion)                          AS PromedioGeneral,
    MIN(Calificacion)                          AS CalifMinima,
    MAX(Calificacion)                          AS CalifMaxima,
    SUM(CASE WHEN Calificacion >= 4.5 THEN 1 ELSE 0 END) AS Excelentes,
    SUM(CASE WHEN Calificacion < 3.0  THEN 1 ELSE 0 END) AS Bajas
FROM fact.Fact_Evaluaciones;
GO

-- ============================================================
-- 3. CARGAR Fact_Capacitaciones
-- ============================================================

EXEC ctrl.usp_CargarFactCapacitaciones;
GO

SELECT
    COUNT(*)                                           AS TotalAsignaciones,
    SUM(CASE WHEN Estado = 'Completada' THEN 1 ELSE 0 END) AS Completadas,
    SUM(CASE WHEN Estado = 'En Curso'   THEN 1 ELSE 0 END) AS EnCurso,
    SUM(CASE WHEN Estado = 'Cancelada'  THEN 1 ELSE 0 END) AS Canceladas,
    SUM(CostoUSD)                                      AS InversionTotalUSD,
    AVG(CalificacionObtenida)                          AS PromedioCalificacion
FROM fact.Fact_Capacitaciones;
GO

-- ============================================================
-- 4. CARGAR Fact_Headcount — snapshot mensual 2023-2024
-- ============================================================
-- Genera una fotografía del headcount para cada mes del
-- período histórico que tenemos en el OLTP.
-- En producción este procedimiento se ejecutaría automático
-- el primer día de cada mes con un SQL Server Agent Job.
-- ============================================================

PRINT 'Generando snapshots mensuales 2023-2024...';
GO

-- 2023
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-01-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-02-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-03-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-04-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-05-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-06-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-07-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-08-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-09-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-10-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-11-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2023-12-01';
-- 2024
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-01-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-02-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-03-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-04-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-05-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-06-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-07-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-08-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-09-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-10-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-11-01';
EXEC ctrl.usp_CargarFactHeadcount @FechaSnapshot = '2024-12-01';
GO

SELECT
    t.AnioMes                      AS Mes,
    COUNT(*)                       AS Empleados,
    AVG(fh.SalarioMesUSD)          AS SalarioPromedioUSD,
    SUM(fh.SalarioMesUSD)          AS MasaSalarialUSD,
    AVG(fh.AntiguedadMeses)        AS AntigüedadPromMeses
FROM fact.Fact_Headcount fh
JOIN dim.Dim_Tiempo      t  ON fh.FechaSnapshotID = t.TiempoID
GROUP BY t.AnioMes
ORDER BY t.AnioMes;
GO

-- ============================================================
-- 5. RESUMEN FINAL DE TODA LA CARGA ETL
-- ============================================================

PRINT '';
PRINT '── RESUMEN TABLAS DE HECHOS ─────────────────────────────';
GO

SELECT
    'Fact_Ausencias'      AS TablaHechos, COUNT(*) AS Registros
FROM fact.Fact_Ausencias
UNION ALL
SELECT 'Fact_Evaluaciones',  COUNT(*) FROM fact.Fact_Evaluaciones
UNION ALL
SELECT 'Fact_Capacitaciones',COUNT(*) FROM fact.Fact_Capacitaciones
UNION ALL
SELECT 'Fact_Headcount',     COUNT(*) FROM fact.Fact_Headcount;
GO

PRINT '';
PRINT '── LOG ETL COMPLETO ────────────────────────────────────';
GO

SELECT
    NombreProceso,
    TablaDestino,
    Estado,
    RegistrosInsertados,
    DATEDIFF(SECOND, FechaInicio, FechaFin) AS DuracionSeg,
    FechaFin
FROM ctrl.LogCargaETL
WHERE Estado = 'Completado'
ORDER BY FechaFin DESC;
GO

PRINT '';
PRINT '============================================================';
PRINT '✅ SCRIPT 08 COMPLETADO — HECHOS CARGADOS';
PRINT '';
PRINT '  Fact_Ausencias       → desde OLTP hr.Ausencias';
PRINT '  Fact_Evaluaciones    → desde OLTP hr.Evaluaciones';
PRINT '  Fact_Capacitaciones  → desde OLTP hr.EmpleadosCapacitaciones';
PRINT '  Fact_Headcount       → 24 snapshots (ene 2023 - dic 2024)';
PRINT '';
PRINT '  El DWH está listo para consultas analíticas.';
PRINT '  Siguiente paso: Ejecutar 09_Validaciones_DWH.sql';
PRINT '============================================================';
GO