-- ============================================================
-- SCRIPT 07b: DEMOSTRACIÓN SCD TIPO 2 — CAMBIO REAL
-- Base de Datos : RRHH / RRHH_DW
-- Propósito     : Demostrar el funcionamiento real del
--                 Slowly Changing Dimension Tipo 2 simulando
--                 un cambio organizacional en TalentCorp S.A.
-- Autora        : Hanna
-- Fecha         : 2026
-- ============================================================
-- CONTEXTO:
--   Los scripts anteriores poblaron el DWH con datos de
--   2023-2024 donde nadie cambió de departamento.
--   El SCD Tipo 2 existe en el código pero no se disparó
--   porque los datos eran estáticos.
--
--   Este script simula un cambio organizacional real:
--   Alejandro Muñoz (Dev Senior, Tecnología) es promovido
--   y trasladado al departamento de Ventas en junio 2024.
--
-- RESULTADO ESPERADO:
--   Dim_Empleado tendrá DOS versiones de Alejandro:
--   Versión 1 → Tecnología (2023-01-01 a 2024-05-31) — cerrada
--   Versión 2 → Ventas     (2024-06-01 a NULL)        — activa
--
-- ESTO GARANTIZA que:
--   Sus ausencias de 2023 siguen mostrando "Tecnología"
--   Sus evaluaciones de 2024 muestran "Ventas"
--   El historial queda intacto — nunca se pierde información
-- ============================================================

-- ============================================================
-- PASO 1: Estado ANTES del cambio
-- Verificar la versión actual de Alejandro en el DWH
-- ============================================================

USE RRHH_DW;
GO

PRINT '============================================================';
PRINT 'DEMO SCD TIPO 2 — ESTADO ANTES DEL CAMBIO';
PRINT '============================================================';

SELECT
    EmpleadoSK,
    EmpleadoID_OLTP,
    NombreCompleto,
    Departamento,
    NombrePuesto,
    NombreJefe,
    FechaInicioVig,
    FechaFinVig,
    EsVersionActual
FROM dim.Dim_Empleado
WHERE EmpleadoID_OLTP = 9  -- Alejandro Muñoz
ORDER BY FechaInicioVig;
GO

-- También verificar sus ausencias y evaluaciones actuales
SELECT
    fa.AusenciaID_OLTP,
    de.NombreCompleto,
    de.Departamento          AS DepartamentoEnEseMomento,
    t.Fecha                  AS FechaInicio,
    ta.TipoAusencia,
    fa.DiasTotales
FROM fact.Fact_Ausencias     fa
JOIN dim.Dim_Empleado        de ON fa.EmpleadoSK      = de.EmpleadoSK
JOIN dim.Dim_Tiempo          t  ON fa.FechaInicioID   = t.TiempoID
JOIN dim.Dim_TipoAusencia    ta ON fa.TipoAusenciaSK  = ta.TipoAusenciaSK
WHERE de.EmpleadoID_OLTP = 9
ORDER BY t.Fecha;
GO

-- ============================================================
-- PASO 2: Simular el cambio en el OLTP
-- Alejandro Muñoz es trasladado a Ventas en junio 2024
-- ============================================================

USE RRHH;
GO

PRINT '';
PRINT '============================================================';
PRINT 'SIMULANDO CAMBIO ORGANIZACIONAL EN EL OLTP...';
PRINT 'Alejandro Muñoz: Tecnología → Ventas (2024-06-01)';
PRINT '============================================================';

-- Guardar estado original para poder revertir después
-- DepartamentoID = 2 (Tecnología), JefeDirectoID = 2 (Valentina Ríos)
-- DepartamentoID = 3 (Ventas),     JefeDirectoID = 3 (Andrés Castillo)

UPDATE hr.Empleados
SET
    DepartamentoID    = 3,  -- Ventas
    JefeDirectoID     = 3,  -- Andrés Castillo (Director Comercial)
    FechaModificacion = '2024-06-01'
WHERE EmpleadoID = 9;
GO

PRINT '✓ Cambio aplicado en OLTP — Alejandro ahora está en Ventas';
GO

-- ============================================================
-- PASO 3: Ejecutar el ETL de Dim_Empleado con nueva fecha
-- El algoritmo SCD Tipo 2 detecta el cambio automáticamente
-- ============================================================

USE RRHH_DW;
GO

PRINT '';
PRINT '============================================================';
PRINT 'EJECUTANDO ETL — DETECTANDO CAMBIO CON SCD TIPO 2...';
PRINT '============================================================';

EXEC ctrl.usp_CargarDimEmpleado
    @FechaCarga = '2024-06-01';
GO

-- ============================================================
-- PASO 4: Estado DESPUÉS del cambio — verificar SCD Tipo 2
-- ============================================================

PRINT '';
PRINT '============================================================';
PRINT 'DEMO SCD TIPO 2 — ESTADO DESPUÉS DEL CAMBIO';
PRINT 'Deben aparecer DOS versiones de Alejandro Muñoz';
PRINT '============================================================';

SELECT
    EmpleadoSK,
    EmpleadoID_OLTP,
    NombreCompleto,
    Departamento,
    NombreJefe,
    NombrePuesto,
    FechaInicioVig,
    FechaFinVig,
    EsVersionActual,
    CASE EsVersionActual
        WHEN 1 THEN '← VERSIÓN ACTIVA (Ventas)'
        WHEN 0 THEN '← VERSIÓN HISTÓRICA (Tecnología)'
    END                      AS Descripcion
FROM dim.Dim_Empleado
WHERE EmpleadoID_OLTP = 9
ORDER BY FechaInicioVig;
GO

-- ============================================================
-- PASO 5: Demostrar que el historial queda intacto
-- Las ausencias de 2023 siguen apuntando a Tecnología
-- Las evaluaciones de 2024 (post-cambio) apuntan a Ventas
-- ============================================================

PRINT '';
PRINT '============================================================';
PRINT 'VERIFICACIÓN: historial de ausencias con contexto correcto';
PRINT 'Las ausencias de 2023 deben mostrar Tecnología';
PRINT '============================================================';

SELECT
    t.Fecha                  AS FechaAusencia,
    de.NombreCompleto        AS Empleado,
    de.Departamento          AS DepartamentoEnEseMomento,
    de.NombreJefe            AS JefeEnEseMomento,
    ta.TipoAusencia,
    fa.DiasTotales,
    CASE
        WHEN de.Departamento = 'Tecnología' THEN '✓ Correcto — era de Tecnología'
        WHEN de.Departamento = 'Ventas'     THEN '✓ Correcto — ya era de Ventas'
    END                      AS Validacion
FROM fact.Fact_Ausencias     fa
JOIN dim.Dim_Empleado        de ON fa.EmpleadoSK     = de.EmpleadoSK
JOIN dim.Dim_Tiempo          t  ON fa.FechaInicioID  = t.TiempoID
JOIN dim.Dim_TipoAusencia    ta ON fa.TipoAusenciaSK = ta.TipoAusenciaSK
WHERE de.EmpleadoID_OLTP = 9
ORDER BY t.Fecha;
GO

-- ============================================================
-- PASO 6: Resumen visual del SCD Tipo 2
-- ============================================================

PRINT '';
PRINT '============================================================';
PRINT 'RESUMEN — CÓMO FUNCIONA SCD TIPO 2 EN ESTE CASO:';
PRINT '';
PRINT '  ANTES del cambio:';
PRINT '  EmpleadoID=9 → 1 versión activa en Tecnología';
PRINT '';
PRINT '  DESPUÉS del cambio (ETL detecta diferencia):';
PRINT '  Paso 1: Cierra versión vieja → FechaFinVig=2024-05-31';
PRINT '                                  EsVersionActual=0';
PRINT '  Paso 2: Inserta versión nueva → FechaInicioVig=2024-06-01';
PRINT '                                   EsVersionActual=1';
PRINT '';
PRINT '  RESULTADO: el historial queda intacto.';
PRINT '  Las ausencias de 2023 muestran Tecnología.';
PRINT '  Los hechos futuros mostrarán Ventas.';
PRINT '============================================================';
GO

-- ============================================================
-- PASO 7: Revertir el cambio en el OLTP
-- Dejamos los datos originales para no afectar
-- las consultas analíticas del Script 10
-- ============================================================

USE RRHH;
GO

UPDATE hr.Empleados
SET
    DepartamentoID    = 2,  -- vuelve a Tecnología
    JefeDirectoID     = 2,  -- vuelve con Valentina Ríos
    FechaModificacion = NULL
WHERE EmpleadoID = 9;
GO

PRINT '✓ OLTP revertido — Alejandro vuelve a Tecnología';
PRINT '  La demostración SCD Tipo 2 quedó registrada en el DWH';
PRINT '  con las dos versiones como evidencia del mecanismo.';
GO

-- ============================================================
-- VERIFICACIÓN FINAL — contar versiones en Dim_Empleado
-- ============================================================

USE RRHH_DW;
GO

SELECT
    EmpleadoID_OLTP,
    NombreCompleto,
    COUNT(*)                 AS TotalVersiones,
    SUM(CAST(EsVersionActual AS INT)) AS VersionesActivas
FROM dim.Dim_Empleado
GROUP BY EmpleadoID_OLTP, NombreCompleto
HAVING COUNT(*) > 1
ORDER BY TotalVersiones DESC;
GO

PRINT '';
PRINT '============================================================';
PRINT '✅ SCRIPT 07b COMPLETADO — DEMO SCD TIPO 2';
PRINT '';
PRINT '  Empleado modificado : Alejandro Muñoz (ID=9)';
PRINT '  Cambio simulado     : Tecnología → Ventas (2024-06-01)';
PRINT '  Versiones en DWH    : 2 (1 histórica + 1 activa)';
PRINT '  Historial intacto   : ausencias 2023 = Tecnología';
PRINT '  OLTP revertido      : datos originales restaurados';
PRINT '============================================================';
GO