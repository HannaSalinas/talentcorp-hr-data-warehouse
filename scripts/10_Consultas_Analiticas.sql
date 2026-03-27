-- ============================================================
-- SCRIPT 10: CONSULTAS ANALÍTICAS ESTRATÉGICAS
-- Base de Datos : RRHH_DW
-- Propósito     : 15 consultas multidimensionales para toma
--                 de decisiones estratégicas en RRHH
-- Autora        : Hanna
-- Fecha         : 2026
-- ============================================================
-- NIVELES DE ACCESO RECOMENDADOS:
--   [RRHH]       → solo equipo de Recursos Humanos
--   [GERENCIAL]  → visible para gerentes de cada departamento
--   [EJECUTIVO]  → alta dirección y CEO
--
-- POLÍTICA DE ALERTA (definida en diseño del sistema):
--   Cuando un indicador supera el 50% de concentración en
--   un área, el resultado debe ser visible para el gerente
--   del departamento afectado — no solo para RRHH.
--   Transparencia con propósito de mejora, no de sanción.
-- ============================================================

USE RRHH_DW;
GO

PRINT '============================================================';
PRINT 'CONSULTAS ANALÍTICAS ESTRATÉGICAS — TALENTCORP S.A.';
PRINT 'Período de análisis: 2023-2024';
PRINT '============================================================';
GO

-- ============================================================
-- CONSULTA 01 — [EJECUTIVO]
-- KPI: Headcount y masa salarial por departamento
-- ¿Cuánto cuesta cada departamento mensualmente?
-- ============================================================

PRINT '--- CONSULTA 01: Headcount y masa salarial por departamento ---';

SELECT
    dd.NombreDepartamento                          AS Departamento,
    COUNT(DISTINCT fh.EmpleadoSK)                  AS TotalEmpleados,
    AVG(fh.SalarioMesUSD)                          AS SalarioPromedioUSD,
    SUM(fh.SalarioMesUSD)                          AS MasaSalarialMensualUSD,
    MIN(fh.SalarioMesUSD)                          AS SalarioMinimoUSD,
    MAX(fh.SalarioMesUSD)                          AS SalarioMaximoUSD
FROM fact.Fact_Headcount     fh
JOIN dim.Dim_Departamento    dd ON fh.DepartamentoSK = dd.DepartamentoSK
JOIN dim.Dim_Tiempo          t  ON fh.FechaSnapshotID = t.TiempoID
WHERE t.AnioMes = '2024-12'
  AND dd.EsVersionActual = 1
GROUP BY dd.NombreDepartamento
ORDER BY MasaSalarialMensualUSD DESC;
GO

-- ============================================================
-- CONSULTA 02 — [RRHH]
-- KPI: Tasa de ausentismo por departamento 2023-2024
-- Fórmula: (días ausencia / días laborables) × 100
-- Umbral de alerta: > 50% de ausencias concentradas en un depto
-- ============================================================

PRINT '--- CONSULTA 02: Tasa de ausentismo por departamento ---';

SELECT
    dd.NombreDepartamento                          AS Departamento,
    COUNT(fa.AusenciaSK)                           AS TotalAusencias,
    SUM(fa.DiasTotales)                            AS TotalDiasAusencia,
    AVG(CAST(fa.DiasTotales AS DECIMAL(5,1)))      AS PromedioDiasPorAusencia,
    CAST(COUNT(fa.AusenciaSK) * 100.0
         / SUM(COUNT(fa.AusenciaSK)) OVER()
         AS DECIMAL(5,1))                          AS PctDelTotal,
    CASE
        WHEN CAST(COUNT(fa.AusenciaSK) * 100.0
             / SUM(COUNT(fa.AusenciaSK)) OVER()
             AS DECIMAL(5,1)) > 50
        THEN '🚨 ALERTA — Revisar con gerente'
        ELSE '✓ Normal'
    END                                            AS Alerta
FROM fact.Fact_Ausencias     fa
JOIN dim.Dim_Departamento    dd ON fa.DepartamentoSK = dd.DepartamentoSK
WHERE dd.EsVersionActual = 1
GROUP BY dd.NombreDepartamento
ORDER BY TotalAusencias DESC;
GO

-- ============================================================
-- CONSULTA 03 — [RRHH]
-- KPI: Ausentismo por tipo — ¿qué tipo de ausencia domina?
-- ============================================================

PRINT '--- CONSULTA 03: Ausencias por tipo y año ---';

SELECT
    t.Anio                                         AS Año,
    ta.TipoAusencia,
    ta.Categoria,
    COUNT(*)                                       AS Cantidad,
    SUM(fa.DiasTotales)                            AS TotalDias,
    AVG(CAST(fa.DiasTotales AS DECIMAL(5,1)))      AS PromedioDias,
    SUM(CASE WHEN fa.EsJustificada = 0 THEN 1 ELSE 0 END) AS NoJustificadas
FROM fact.Fact_Ausencias     fa
JOIN dim.Dim_TipoAusencia    ta ON fa.TipoAusenciaSK  = ta.TipoAusenciaSK
JOIN dim.Dim_Tiempo          t  ON fa.FechaInicioID   = t.TiempoID
GROUP BY t.Anio, ta.TipoAusencia, ta.Categoria
ORDER BY t.Anio, TotalDias DESC;
GO

-- ============================================================
-- CONSULTA 04 — [GERENCIAL]
-- KPI: Desempeño promedio por departamento y período
-- Permite detectar departamentos con bajo desempeño sostenido
-- ============================================================

PRINT '--- CONSULTA 04: Desempeño promedio por departamento ---';

SELECT
    dd.NombreDepartamento                          AS Departamento,
    t.Anio                                         AS Año,
    COUNT(*)                                       AS TotalEvaluaciones,
    CAST(AVG(fe.Calificacion) AS DECIMAL(3,1))     AS PromedioCalificacion,
    MIN(fe.Calificacion)                           AS CalifMinima,
    MAX(fe.Calificacion)                           AS CalifMaxima,
    SUM(CASE WHEN fe.Calificacion >= 4.5 THEN 1 ELSE 0 END) AS Excelentes,
    SUM(CASE WHEN fe.Calificacion < 3.0  THEN 1 ELSE 0 END) AS Bajas
FROM fact.Fact_Evaluaciones  fe
JOIN dim.Dim_Departamento    dd ON fe.DepartamentoSK   = dd.DepartamentoSK
JOIN dim.Dim_Tiempo          t  ON fe.FechaEvaluacionID = t.TiempoID
WHERE dd.EsVersionActual = 1
GROUP BY dd.NombreDepartamento, t.Anio
ORDER BY t.Anio, PromedioCalificacion DESC;
GO

-- ============================================================
-- CONSULTA 05 — [EJECUTIVO]
-- KPI: Top 10 empleados con mejor desempeño acumulado
-- Candidatos a promoción o reconocimiento
-- ============================================================

PRINT '--- CONSULTA 05: Top 10 mejores desempeños acumulados ---';

SELECT TOP 10
    de.NombreCompleto                              AS Empleado,
    de.Departamento,
    de.NombrePuesto,
    de.NivelSalarial,
    COUNT(fe.EvaluacionSK)                         AS TotalEvaluaciones,
    CAST(AVG(fe.Calificacion) AS DECIMAL(3,1))     AS PromedioCalificacion,
    MIN(fe.Calificacion)                           AS CalifMinima,
    MAX(fe.Calificacion)                           AS CalifMaxima
FROM fact.Fact_Evaluaciones  fe
JOIN dim.Dim_Empleado        de ON fe.EmpleadoEvaluadoSK = de.EmpleadoSK
WHERE de.EsVersionActual = 1
GROUP BY de.NombreCompleto, de.Departamento,
         de.NombrePuesto, de.NivelSalarial
HAVING COUNT(fe.EvaluacionSK) >= 2
ORDER BY PromedioCalificacion DESC, TotalEvaluaciones DESC;
GO

-- ============================================================
-- CONSULTA 06 — [RRHH]
-- KPI: Inversión en capacitación por departamento
-- ROI de formación: costo vs calificación obtenida
-- ============================================================

PRINT '--- CONSULTA 06: Inversión en capacitación por departamento ---';

SELECT
    dd.NombreDepartamento                          AS Departamento,
    COUNT(*)                                       AS TotalCapacitaciones,
    SUM(fc.CostoUSD)                               AS InversionTotalUSD,
    AVG(fc.CostoUSD)                               AS CostoPromedioUSD,
    CAST(AVG(fc.CalificacionObtenida) AS DECIMAL(5,1)) AS CalifPromedio,
    SUM(CASE WHEN fc.Estado = 'Completada' THEN 1 ELSE 0 END) AS Completadas,
    CAST(SUM(CASE WHEN fc.Estado = 'Completada' THEN 1.0 ELSE 0 END)
         / COUNT(*) * 100 AS DECIMAL(5,1))         AS PctCompletadas
FROM fact.Fact_Capacitaciones fc
JOIN dim.Dim_Departamento     dd ON fc.DepartamentoSK = dd.DepartamentoSK
WHERE dd.EsVersionActual = 1
GROUP BY dd.NombreDepartamento
ORDER BY InversionTotalUSD DESC;
GO

-- ============================================================
-- CONSULTA 07 — [RRHH]
-- KPI: Evolución mensual del headcount 2023-2024
-- ¿Cómo ha crecido o decrecido la plantilla?
-- ============================================================

PRINT '--- CONSULTA 07: Evolución mensual del headcount ---';

SELECT
    t.AnioMes                                      AS Mes,
    COUNT(fh.HeadcountSK)                          AS TotalEmpleados,
    SUM(fh.SalarioMesUSD)                          AS MasaSalarialUSD,
    AVG(fh.SalarioMesUSD)                          AS SalarioPromedioUSD,
    AVG(fh.AntiguedadMeses)                        AS AntiguedadPromMeses
FROM fact.Fact_Headcount     fh
JOIN dim.Dim_Tiempo          t  ON fh.FechaSnapshotID = t.TiempoID
GROUP BY t.AnioMes
ORDER BY t.AnioMes;
GO

-- ============================================================
-- CONSULTA 08 — [RRHH]
-- KPI: Empleados con mayor ausentismo acumulado
-- Permite identificar casos que requieren atención de bienestar
-- ============================================================

PRINT '--- CONSULTA 08: Top 10 empleados con más días de ausencia ---';

SELECT TOP 10
    de.NombreCompleto                              AS Empleado,
    de.Departamento,
    de.NombrePuesto,
    COUNT(fa.AusenciaSK)                           AS NumAusencias,
    SUM(fa.DiasTotales)                            AS TotalDiasAusencia,
    SUM(CASE WHEN fa.EsJustificada = 0 THEN 1 ELSE 0 END) AS NoJustificadas,
    -- Ausencia más frecuente
    (SELECT TOP 1 ta2.TipoAusencia
     FROM fact.Fact_Ausencias fa2
     JOIN dim.Dim_TipoAusencia ta2 ON fa2.TipoAusenciaSK = ta2.TipoAusenciaSK
     WHERE fa2.EmpleadoSK = de.EmpleadoSK
     GROUP BY ta2.TipoAusencia
     ORDER BY COUNT(*) DESC)                       AS TipoMasFrecuente
FROM fact.Fact_Ausencias     fa
JOIN dim.Dim_Empleado        de ON fa.EmpleadoSK = de.EmpleadoSK
WHERE de.EsVersionActual = 1
GROUP BY de.NombreCompleto, de.Departamento,
         de.NombrePuesto, de.EmpleadoSK
ORDER BY TotalDiasAusencia DESC;
GO

-- ============================================================
-- CONSULTA 09 — [EJECUTIVO]
-- KPI: Brecha salarial por género y nivel
-- Análisis de equidad — compromiso con Decreto 1227/2015
-- ============================================================

PRINT '--- CONSULTA 09: Brecha salarial por género y nivel salarial ---';

SELECT
    de.NivelSalarial,
    de.Genero,
    COUNT(DISTINCT fh.EmpleadoSK)                  AS TotalEmpleados,
    CAST(AVG(fh.SalarioMesUSD) AS DECIMAL(10,2))   AS SalarioPromedioUSD,
    CAST(MIN(fh.SalarioMesUSD) AS DECIMAL(10,2))   AS SalarioMinimoUSD,
    CAST(MAX(fh.SalarioMesUSD) AS DECIMAL(10,2))   AS SalarioMaximoUSD
FROM fact.Fact_Headcount     fh
JOIN dim.Dim_Empleado        de ON fh.EmpleadoSK = de.EmpleadoSK
JOIN dim.Dim_Tiempo          t  ON fh.FechaSnapshotID = t.TiempoID
WHERE t.AnioMes = '2024-12'
  AND de.EsVersionActual = 1
GROUP BY de.NivelSalarial, de.Genero
ORDER BY de.NivelSalarial, de.Genero;
GO

-- ============================================================
-- CONSULTA 10 — [GERENCIAL]
-- KPI: Relación entre capacitación y desempeño
-- ¿Los empleados que más se capacitan tienen mejor calificación?
-- ============================================================

PRINT '--- CONSULTA 10: Capacitación vs desempeño individual ---';

SELECT
    de.NombreCompleto                              AS Empleado,
    de.Departamento,
    COUNT(DISTINCT fc.CapacitacionSK_Fact)         AS CapacitacionesCompletadas,
    SUM(fc.CostoUSD)                               AS InversionFormacionUSD,
    CAST(AVG(fc.CalificacionObtenida) AS DECIMAL(5,1)) AS PromCalifCapacitacion,
    CAST(AVG(fe.Calificacion) AS DECIMAL(3,1))     AS PromCalifDesempeno,
    CASE
        WHEN AVG(fe.Calificacion) >= 4.5 AND
             COUNT(DISTINCT fc.CapacitacionSK_Fact) >= 3
        THEN '⭐ Alto potencial'
        WHEN AVG(fe.Calificacion) >= 3.5
        THEN '✓ Buen desempeño'
        ELSE '△ Requiere atención'
    END                                            AS Clasificacion
FROM dim.Dim_Empleado        de
JOIN fact.Fact_Capacitaciones fc ON de.EmpleadoSK = fc.EmpleadoSK
                                 AND fc.Estado = 'Completada'
JOIN fact.Fact_Evaluaciones  fe ON de.EmpleadoSK = fe.EmpleadoEvaluadoSK
WHERE de.EsVersionActual = 1
GROUP BY de.NombreCompleto, de.Departamento, de.EmpleadoSK
HAVING COUNT(DISTINCT fc.CapacitacionSK_Fact) >= 2
ORDER BY PromCalifDesempeno DESC, CapacitacionesCompletadas DESC;
GO

-- ============================================================
-- CONSULTA 11 — [RRHH]
-- KPI: Antigüedad promedio por departamento y nivel
-- Indica riesgo de rotación en grupos con baja antigüedad
-- ============================================================

PRINT '--- CONSULTA 11: Antigüedad promedio por departamento ---';

SELECT
    dd.NombreDepartamento                          AS Departamento,
    dp.NivelSalarial,
    COUNT(DISTINCT fh.EmpleadoSK)                  AS Empleados,
    AVG(fh.AntiguedadMeses)                        AS AntiguedadPromMeses,
    CAST(AVG(fh.AntiguedadMeses) / 12.0
         AS DECIMAL(4,1))                          AS AntiguedadPromAnios,
    MIN(fh.AntiguedadMeses)                        AS MinimaAntiguedadMeses,
    MAX(fh.AntiguedadMeses)                        AS MaximaAntiguedadMeses
FROM fact.Fact_Headcount     fh
JOIN dim.Dim_Departamento    dd ON fh.DepartamentoSK = dd.DepartamentoSK
JOIN dim.Dim_Puesto          dp ON fh.PuestoSK       = dp.PuestoSK
JOIN dim.Dim_Tiempo          t  ON fh.FechaSnapshotID = t.TiempoID
WHERE t.AnioMes = '2024-12'
  AND dd.EsVersionActual = 1
  AND dp.EsVersionActual = 1
GROUP BY dd.NombreDepartamento, dp.NivelSalarial
ORDER BY dd.NombreDepartamento, dp.NivelSalarial;
GO

-- ============================================================
-- CONSULTA 12 — [RRHH]
-- KPI: Ausentismo en días festivos y fines de semana
-- Detecta ausencias registradas en días no laborables
-- (posible error de registro en el OLTP)
-- ============================================================

PRINT '--- CONSULTA 12: Ausencias en días no laborables ---';

SELECT
    CASE WHEN t.EsFinDeSemana = 1 THEN 'Fin de semana'
         WHEN t.EsFestivoCOL  = 1 THEN 'Festivo Colombia'
    END                                            AS TipoDia,
    COUNT(*)                                       AS TotalAusencias,
    dd.NombreDepartamento                          AS Departamento
FROM fact.Fact_Ausencias     fa
JOIN dim.Dim_Tiempo          t  ON fa.FechaInicioID   = t.TiempoID
JOIN dim.Dim_Departamento    dd ON fa.DepartamentoSK  = dd.DepartamentoSK
WHERE (t.EsFinDeSemana = 1 OR t.EsFestivoCOL = 1)
  AND dd.EsVersionActual = 1
GROUP BY
    CASE WHEN t.EsFinDeSemana = 1 THEN 'Fin de semana'
         WHEN t.EsFestivoCOL  = 1 THEN 'Festivo Colombia'
    END,
    dd.NombreDepartamento
ORDER BY TotalAusencias DESC;
GO

-- ============================================================
-- CONSULTA 13 — [EJECUTIVO]
-- KPI: Tendencia de desempeño semestral 2023-2024
-- ¿Está mejorando o empeorando el desempeño general?
-- ============================================================

PRINT '--- CONSULTA 13: Tendencia de desempeño semestral ---';

SELECT
    t.Anio                                         AS Año,
    t.Semestre,
    CAST(t.Anio AS VARCHAR) + '-S'
    + CAST(t.Semestre AS VARCHAR)                  AS Período,
    COUNT(*)                                       AS TotalEvaluaciones,
    CAST(AVG(fe.Calificacion) AS DECIMAL(3,1))     AS PromedioGeneral,
    SUM(CASE WHEN fe.Calificacion >= 4.5 THEN 1 ELSE 0 END) AS Excelentes,
    SUM(CASE WHEN fe.Calificacion >= 3.5
              AND fe.Calificacion < 4.5 THEN 1 ELSE 0 END)  AS Buenos,
    SUM(CASE WHEN fe.Calificacion < 3.5 THEN 1 ELSE 0 END)  AS PorMejorar
FROM fact.Fact_Evaluaciones  fe
JOIN dim.Dim_Tiempo          t  ON fe.FechaEvaluacionID = t.TiempoID
GROUP BY t.Anio, t.Semestre
ORDER BY t.Anio, t.Semestre;
GO

-- ============================================================
-- CONSULTA 14 — [GERENCIAL]
-- KPI: Empleados sin capacitación en últimos 12 meses
-- Riesgo de obsolescencia de habilidades
-- ============================================================

PRINT '--- CONSULTA 14: Empleados sin capacitación reciente ---';

SELECT
    de.NombreCompleto                              AS Empleado,
    de.Departamento,
    de.NombrePuesto,
    de.NivelSalarial,
    de.AniosAntiguedad,
    ISNULL(
        CAST(MAX(t.Fecha) AS VARCHAR),
        'Sin capacitaciones'
    )                                              AS UltimaCapacitacion,
    ISNULL(
        DATEDIFF(MONTH, MAX(t.Fecha), '2024-12-31'),
        999
    )                                              AS MesesSinCapacitacion
FROM dim.Dim_Empleado        de
LEFT JOIN fact.Fact_Capacitaciones fc
       ON de.EmpleadoSK = fc.EmpleadoSK
      AND fc.Estado = 'Completada'
LEFT JOIN dim.Dim_Tiempo     t
       ON fc.FechaCompletadoID = t.TiempoID
WHERE de.EsVersionActual = 1
GROUP BY de.NombreCompleto, de.Departamento,
         de.NombrePuesto, de.NivelSalarial,
         de.AniosAntiguedad, de.EmpleadoSK
HAVING ISNULL(DATEDIFF(MONTH, MAX(t.Fecha), '2024-12-31'), 999) > 12
ORDER BY MesesSinCapacitacion DESC;
GO

-- ============================================================
-- CONSULTA 15 — [EJECUTIVO]
-- DASHBOARD EJECUTIVO: resumen integral de KPIs estratégicos
-- Vista 360° del estado del talento en TalentCorp S.A.
-- ============================================================

PRINT '--- CONSULTA 15: Dashboard ejecutivo — KPIs estratégicos ---';

SELECT
    'Headcount total 2024'         AS KPI,
    CAST(COUNT(DISTINCT fh.EmpleadoSK) AS VARCHAR) + ' empleados' AS Valor,
    'Dic 2024'                     AS Período
FROM fact.Fact_Headcount fh
JOIN dim.Dim_Tiempo t ON fh.FechaSnapshotID = t.TiempoID
WHERE t.AnioMes = '2024-12'

UNION ALL

SELECT
    'Masa salarial mensual',
    'USD ' + FORMAT(SUM(fh2.SalarioMesUSD), 'N0'),
    'Dic 2024'
FROM fact.Fact_Headcount fh2
JOIN dim.Dim_Tiempo t2 ON fh2.FechaSnapshotID = t2.TiempoID
WHERE t2.AnioMes = '2024-12'

UNION ALL

SELECT
    'Calificación promedio de desempeño',
    CAST(CAST(AVG(fe.Calificacion) AS DECIMAL(3,1)) AS VARCHAR) + ' / 5.0',
    '2023-2024'
FROM fact.Fact_Evaluaciones fe

UNION ALL

SELECT
    'Total días de ausencia',
    CAST(SUM(fa.DiasTotales) AS VARCHAR) + ' días',
    '2023-2024'
FROM fact.Fact_Ausencias fa

UNION ALL

SELECT
    'Inversión total en capacitación',
    'USD ' + FORMAT(SUM(fc.CostoUSD), 'N0'),
    '2023-2024'
FROM fact.Fact_Capacitaciones fc
WHERE fc.Estado = 'Completada'

UNION ALL

SELECT
    'Tasa de completitud de capacitaciones',
    CAST(CAST(SUM(CASE WHEN Estado='Completada' THEN 1.0 ELSE 0 END)
         / COUNT(*) * 100 AS DECIMAL(5,1)) AS VARCHAR) + '%',
    '2023-2024'
FROM fact.Fact_Capacitaciones

UNION ALL

SELECT
    'Empleados con desempeño excelente',
    CAST(COUNT(DISTINCT EmpleadoEvaluadoSK) AS VARCHAR) + ' empleados',
    '2023-2024'
FROM fact.Fact_Evaluaciones
WHERE Calificacion >= 4.5

UNION ALL

SELECT
    'Ausencias no justificadas',
    CAST(SUM(CASE WHEN EsJustificada=0 THEN 1 ELSE 0 END) AS VARCHAR)
    + ' de ' + CAST(COUNT(*) AS VARCHAR),
    '2023-2024'
FROM fact.Fact_Ausencias;
GO

PRINT '';
PRINT '============================================================';
PRINT '✅ SCRIPT 10 COMPLETADO — CONSULTAS ANALÍTICAS';
PRINT '';
PRINT '  15 consultas estratégicas ejecutadas';
PRINT '  Niveles de acceso: RRHH | GERENCIAL | EJECUTIVO';
PRINT '';
PRINT '  ✅ PROYECTO COMPLETO — Sistema BI TalentCorp S.A.';
PRINT '  Scripts 01-10 ejecutados exitosamente';
PRINT '============================================================';
GO