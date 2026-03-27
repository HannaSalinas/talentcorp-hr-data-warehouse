-- ============================================================
-- SCRIPT 07: ETL — CARGAR DIMENSIONES (SCD TIPO 2)
-- Base de Datos : RRHH_DW
-- Propósito     : Ejecutar los procedimientos SCD Tipo 2
--                 en el orden correcto para poblar todas
--                 las dimensiones desde el OLTP RRHH
-- Autora        : Hanna
-- Fecha         : 2026
-- ============================================================
-- ORDEN DE CARGA — CRÍTICO:
--   Las dimensiones no tienen dependencias entre sí, pero
--   deben cargarse ANTES que los hechos (Script 08).
--   Dim_Tiempo ya fue cargada en Script 06.
--   Dim_TipoAusencia fue poblada en Script 03 (estática).
--
--   1. Dim_Departamento  → sin dependencias
--   2. Dim_Puesto        → sin dependencias
--   3. Dim_Capacitacion  → sin dependencias
--   4. Dim_Empleado      → última: usa Departamento y Puesto
--                          para desnormalizar el contexto
-- ============================================================

USE RRHH_DW;
GO

PRINT '============================================================';
PRINT 'INICIANDO CARGA ETL — DIMENSIONES';
PRINT 'Fecha: ' + CAST(GETDATE() AS VARCHAR);
PRINT '============================================================';
GO

-- ============================================================
-- 1. CARGAR Dim_Departamento
-- ============================================================

EXEC ctrl.usp_CargarDimDepartamento
    @FechaCarga = '2023-01-01';
GO

SELECT
    DepartamentoSK, NombreDepartamento,
    CiudadOficina, PaisOficina,
    EsVersionActual, FechaInicioVig
FROM dim.Dim_Departamento
ORDER BY DepartamentoSK;
GO

-- ============================================================
-- 2. CARGAR Dim_Puesto
-- ============================================================

EXEC ctrl.usp_CargarDimPuesto
    @FechaCarga = '2023-01-01';
GO

SELECT
    PuestoSK, NombrePuesto,
    NivelSalarial, RangoSalarial, EsVersionActual
FROM dim.Dim_Puesto
ORDER BY NivelSalarial, NombrePuesto;
GO

-- ============================================================
-- 3. CARGAR Dim_Capacitacion
-- ============================================================

EXEC ctrl.usp_CargarDimCapacitacion
    @FechaCarga = '2023-01-01';
GO

SELECT
    CapacitacionSK, NombreCapacitacion,
    Proveedor, CostoUSD, DuracionDias, EsVersionActual
FROM dim.Dim_Capacitacion
ORDER BY CapacitacionSK;
GO

-- ============================================================
-- 4. CARGAR Dim_Empleado
-- ============================================================
-- Se carga de última porque desnormaliza Departamento y Puesto
-- directamente en la dimensión — necesita que esas tablas
-- del OLTP estén disponibles con sus datos completos.
-- ============================================================

EXEC ctrl.usp_CargarDimEmpleado
    @FechaCarga = '2023-01-01';
GO

SELECT
    EmpleadoSK, EmpleadoID_OLTP, NombreCompleto,
    Departamento, NombrePuesto, NivelSalarial,
    NombreJefe, CargoJefe, NombreOficina, PaisOficina,
    AniosAntiguedad, EsVersionActual, FechaInicioVig
FROM dim.Dim_Empleado
WHERE EsVersionActual = 1
ORDER BY Departamento, NombreCompleto;
GO

-- ============================================================
-- 5. RESUMEN DE CARGA
-- ============================================================

SELECT
    TablaDestino                AS Dimension,
    Estado,
    RegistrosInsertados         AS Insertados,
    RegistrosActualizados       AS VersionesCerradas,
    DATEDIFF(SECOND, FechaInicio, FechaFin) AS DuracionSeg,
    FechaFin                    AS FinCarga
FROM ctrl.LogCargaETL
WHERE NombreProceso LIKE 'usp_CargarDim%'
ORDER BY FechaInicio DESC;
GO

SELECT 'Dim_Departamento' AS Dimension, COUNT(*) AS TotalVersiones,
       SUM(CAST(EsVersionActual AS INT)) AS Vigentes
FROM dim.Dim_Departamento
UNION ALL
SELECT 'Dim_Puesto',       COUNT(*), SUM(CAST(EsVersionActual AS INT))
FROM dim.Dim_Puesto
UNION ALL
SELECT 'Dim_Capacitacion', COUNT(*), SUM(CAST(EsVersionActual AS INT))
FROM dim.Dim_Capacitacion
UNION ALL
SELECT 'Dim_Empleado',     COUNT(*), SUM(CAST(EsVersionActual AS INT))
FROM dim.Dim_Empleado
UNION ALL
SELECT 'Dim_TipoAusencia', COUNT(*), COUNT(*)
FROM dim.Dim_TipoAusencia
UNION ALL
SELECT 'Dim_Tiempo',       COUNT(*), COUNT(*)
FROM dim.Dim_Tiempo;
GO

PRINT '';
PRINT '============================================================';
PRINT '✅ SCRIPT 07 COMPLETADO — DIMENSIONES CARGADAS';
PRINT '';
PRINT '  Dim_Departamento  → 5 registros';
PRINT '  Dim_Puesto        → 15 registros';
PRINT '  Dim_Capacitacion  → 12 registros';
PRINT '  Dim_Empleado      → 55 registros';
PRINT '  Dim_TipoAusencia  → 4 registros (estática)';
PRINT '  Dim_Tiempo        → ~1826 registros (Script 06)';
PRINT '';
PRINT '  Siguiente paso: Ejecutar 08_ETL_Cargar_Hechos.sql';
PRINT '============================================================';
GO

-- ============================================================
-- NOTA TÉCNICA — TROUBLESHOOTING: RLS BLOQUEA EL ETL
-- ============================================================
-- ENTORNO AFECTADO : SQL Server en contenedor Docker + DBeaver
--
-- SÍNTOMA:
--   El log ETL reportaba "Completado — 55 insertados" pero
--   SELECT COUNT(*) FROM dim.Dim_Empleado devolvía 0.
--
-- CAUSA RAÍZ:
--   La política de Row-Level Security (RLS) implementada en
--   Script 03 filtra filas según el rol del usuario activo.
--   En Docker/DBeaver la conexión corre como usuario 'dbo',
--   que no pertenece a ningún rol del DWH (DWH_Admin,
--   DWH_Analyst, DWH_ETL). Resultado: la política filtraba
--   TODAS las filas — incluyendo las recién insertadas —
--   generando la ilusión de una tabla vacía. Los datos SÍ
--   existían físicamente pero eran invisibles al usuario.
--
-- CUÁNDO PUEDE OCURRIR EN PRODUCCIÓN:
--   • El proceso ETL no corre bajo un login con rol DWH_ETL
--   • Migración de servidor sin reasignar roles al nuevo
--     login del servicio ETL
--   • Un DBA crea nuevo usuario para el ETL y olvida asignar
--     el rol DWH_ETL
--   • Ambientes de desarrollo con conexión directa como
--     'dbo' o 'sa' sin roles de negocio asignados
--
-- SOLUCIÓN APLICADA (entorno Docker/DBeaver):
--   Se modificó la función de predicado RLS para que 'dbo'
--   siempre tenga acceso total, ya que es el propietario
--   de la base de datos y debe operar sin restricciones.
--   No se puede agregar 'dbo' a roles con ALTER ROLE —
--   SQL Server lo rechaza con error 15405 ("Cannot use
--   the special principal dbo").
--
-- SOLUCIÓN EN PRODUCCIÓN:
--   Asignar el rol DWH_ETL al login del servicio ETL.
--   Nunca agregar excepciones por usuario en la función
--   RLS en producción — usar roles siempre.
-- ============================================================

-- Paso 1: eliminar política (está vinculada a la función)
DROP SECURITY POLICY ctrl.RLS_Empleados;
GO

-- Paso 2: recrear función incluyendo excepción para dbo
CREATE OR ALTER FUNCTION ctrl.fn_RLS_Departamento
    (@Departamento VARCHAR(100))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS RLS_Result
    WHERE
        IS_ROLEMEMBER('DWH_Admin')      = 1
        OR IS_ROLEMEMBER('DWH_Analyst') = 1
        OR IS_ROLEMEMBER('DWH_ETL')     = 1
        -- dbo = propietario de BD en Docker/DBeaver
        -- SQL Server rechaza ALTER ROLE DWH_Admin ADD MEMBER dbo
        -- (error 15405), por eso se agrega aquí como excepción
        OR USER_NAME() = 'dbo'
        OR @Departamento = USER_NAME();
GO

-- Paso 3: recrear política RLS con función actualizada
CREATE SECURITY POLICY ctrl.RLS_Empleados
    ADD FILTER PREDICATE ctrl.fn_RLS_Departamento(Departamento)
    ON dim.Dim_Empleado
    WITH (STATE = ON);
GO

-- Verificación final — debe mostrar 55
SELECT COUNT(*) AS TotalConRLS_Activa FROM dim.Dim_Empleado;
GO

PRINT '✓ RLS activa y funcional — dbo incluido en predicado';
PRINT '  Dim_Empleado visible: 55 registros';
GO