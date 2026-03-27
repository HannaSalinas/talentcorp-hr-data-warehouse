-- ============================================================
-- SCRIPT 04: PROCEDIMIENTOS SCD TIPO 2 — DIMENSIONES
-- Base de Datos : RRHH_DW
-- Propósito     : Stored procedures para cargar y mantener
--                 dimensiones con Slowly Changing Dimension
--                 Tipo 2 — preserva historial de cambios
-- Autora        : Hanna
-- Fecha         : 2026
-- ============================================================
-- CONCEPTO — SCD TIPO 2:
--   Cuando un atributo de una dimensión cambia (ej: un empleado
--   cambia de departamento), NO se actualiza la fila existente.
--   En cambio:
--     1. Se cierra la fila vieja: FechaFinVig = hoy - 1 día
--                                 EsVersionActual = 0
--     2. Se inserta una fila nueva con los datos actualizados
--                                 FechaInicioVig = hoy
--                                 EsVersionActual = 1
--   Resultado: el historial queda intacto. Una ausencia de 2023
--   siempre apunta a la versión del empleado que existía en 2023.
--
-- POLÍTICA DE RETENCIÓN — Ley 1581/2012 Colombia:
--   Versiones históricas (EsVersionActual = 0) con más de 5 años
--   se eliminan automáticamente con usp_PurgarHistorialDimensiones.
--   La versión actual NUNCA se elimina.
-- ============================================================

USE RRHH_DW;
GO

-- ============================================================
-- 1. PROCEDIMIENTO: Cargar Dim_Empleado con SCD Tipo 2
-- ============================================================
-- Algoritmo en 3 pasos:
--   PASO 1 — Detectar registros NUEVOS (no existen en la dim)
--            → INSERT directo
--   PASO 2 — Detectar registros CAMBIADOS (existen pero algún
--            atributo tracked cambió)
--            → UPDATE fila vieja + INSERT fila nueva
--   PASO 3 — Registros SIN CAMBIOS → no hacer nada
--
-- Atributos tracked (los que activan SCD Tipo 2):
--   Departamento, NombrePuesto, NivelSalarial, NombreJefe,
--   NombreOficina — si cualquiera de estos cambia, nueva versión
-- ============================================================

CREATE OR ALTER PROCEDURE ctrl.usp_CargarDimEmpleado
    @FechaCarga DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Si no se pasa fecha, usar hoy
    IF @FechaCarga IS NULL SET @FechaCarga = CAST(GETDATE() AS DATE);

    DECLARE @LogID       INT;
    DECLARE @Insertados  INT = 0;
    DECLARE @Actualizados INT = 0;

    -- Registrar inicio en log ETL
    INSERT INTO ctrl.LogCargaETL
        (NombreProceso, TablaDestino, TipoCarga, FechaInicio)
    VALUES
        ('usp_CargarDimEmpleado', 'dim.Dim_Empleado', 'INCREMENTAL', GETDATE());

    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        -- ── PASO 1: Insertar empleados NUEVOS ─────────────────
        -- Son los que tienen EmpleadoID_OLTP que no existe aún
        -- en la dimensión con EsVersionActual = 1.

        INSERT INTO dim.Dim_Empleado (
            EmpleadoID_OLTP, Identificacion, NombreCompleto, Genero,
            Departamento, NombrePuesto, NivelSalarial,
            NombreJefe, CargoJefe, NombreOficina, PaisOficina,
            AniosAntiguedad, FechaInicioVig, FechaFinVig, EsVersionActual
        )
        SELECT
            e.EmpleadoID,
            e.Identificacion,
            e.Nombre + ' ' + e.Apellidos,
            e.Genero,
            d.NombreDepartamento,
            p.NombrePuesto,
            p.NivelSalarial,
            -- Nombre del jefe (NULL si es el nivel más alto)
            ISNULL(j.Nombre + ' ' + j.Apellidos, 'Sin Jefe Directo'),
            ISNULL(pj.NombrePuesto, 'Alta Dirección'),
            o.Ciudad,
            o.Pais,
            CAST(DATEDIFF(MONTH, e.FechaContratacion, @FechaCarga) / 12.0
                 AS DECIMAL(4,1)),
            @FechaCarga,
            NULL,   -- FechaFinVig NULL = versión activa
            1
        FROM RRHH.hr.Empleados       e
        JOIN RRHH.hr.Departamentos    d  ON e.DepartamentoID = d.DepartamentoID
        JOIN RRHH.hr.Puestos          p  ON e.PuestoID       = p.PuestoID
        JOIN RRHH.hr.Oficinas         o  ON e.OficinaID      = o.OficinaID
        LEFT JOIN RRHH.hr.Empleados   j  ON e.JefeDirectoID  = j.EmpleadoID
        LEFT JOIN RRHH.hr.Puestos     pj ON j.PuestoID       = pj.PuestoID
        WHERE e.Activo = 1
          AND NOT EXISTS (
              SELECT 1 FROM dim.Dim_Empleado de2
              WHERE de2.EmpleadoID_OLTP = e.EmpleadoID
                AND de2.EsVersionActual = 1
          );

        SET @Insertados = @@ROWCOUNT;

        -- ── PASO 2: Cerrar versiones CAMBIADAS ────────────────
        -- Detecta empleados cuya versión actual difiere en algún
        -- atributo tracked vs lo que hay en el OLTP hoy.

        UPDATE de
        SET
            de.FechaFinVig     = DATEADD(DAY, -1, @FechaCarga),
            de.EsVersionActual = 0
        FROM dim.Dim_Empleado de
        JOIN RRHH.hr.Empleados       e  ON de.EmpleadoID_OLTP = e.EmpleadoID
        JOIN RRHH.hr.Departamentos    d  ON e.DepartamentoID  = d.DepartamentoID
        JOIN RRHH.hr.Puestos          p  ON e.PuestoID        = p.PuestoID
        JOIN RRHH.hr.Oficinas         o  ON e.OficinaID       = o.OficinaID
        LEFT JOIN RRHH.hr.Empleados   j  ON e.JefeDirectoID   = j.EmpleadoID
        LEFT JOIN RRHH.hr.Puestos     pj ON j.PuestoID        = pj.PuestoID
        WHERE de.EsVersionActual = 1
          AND e.Activo = 1
          AND (
              de.Departamento   <> d.NombreDepartamento
           OR de.NombrePuesto   <> p.NombrePuesto
           OR de.NivelSalarial  <> p.NivelSalarial
           OR de.NombreJefe     <> ISNULL(j.Nombre + ' ' + j.Apellidos, 'Sin Jefe Directo')
           OR de.NombreOficina  <> o.Ciudad
          );

        SET @Actualizados = @@ROWCOUNT;

        -- ── PASO 3: Insertar versiones NUEVAS para los cambiados

        INSERT INTO dim.Dim_Empleado (
            EmpleadoID_OLTP, Identificacion, NombreCompleto, Genero,
            Departamento, NombrePuesto, NivelSalarial,
            NombreJefe, CargoJefe, NombreOficina, PaisOficina,
            AniosAntiguedad, FechaInicioVig, FechaFinVig, EsVersionActual
        )
        SELECT
            e.EmpleadoID,
            e.Identificacion,
            e.Nombre + ' ' + e.Apellidos,
            e.Genero,
            d.NombreDepartamento,
            p.NombrePuesto,
            p.NivelSalarial,
            ISNULL(j.Nombre + ' ' + j.Apellidos, 'Sin Jefe Directo'),
            ISNULL(pj.NombrePuesto, 'Alta Dirección'),
            o.Ciudad,
            o.Pais,
            CAST(DATEDIFF(MONTH, e.FechaContratacion, @FechaCarga) / 12.0
                 AS DECIMAL(4,1)),
            @FechaCarga,
            NULL,
            1
        FROM RRHH.hr.Empleados       e
        JOIN RRHH.hr.Departamentos    d  ON e.DepartamentoID = d.DepartamentoID
        JOIN RRHH.hr.Puestos          p  ON e.PuestoID       = p.PuestoID
        JOIN RRHH.hr.Oficinas         o  ON e.OficinaID      = o.OficinaID
        LEFT JOIN RRHH.hr.Empleados   j  ON e.JefeDirectoID  = j.EmpleadoID
        LEFT JOIN RRHH.hr.Puestos     pj ON j.PuestoID       = pj.PuestoID
        WHERE e.Activo = 1
          AND NOT EXISTS (
              SELECT 1 FROM dim.Dim_Empleado de2
              WHERE de2.EmpleadoID_OLTP = e.EmpleadoID
                AND de2.EsVersionActual = 1
          );

        -- Actualizar log ETL
        UPDATE ctrl.LogCargaETL
        SET FechaFin              = GETDATE(),
            RegistrosInsertados   = @Insertados,
            RegistrosActualizados = @Actualizados,
            RegistrosProcesados   = @Insertados + @Actualizados,
            Estado                = 'Completado'
        WHERE LogID = @LogID;

        PRINT '✓ Dim_Empleado: ' + CAST(@Insertados AS VARCHAR)
              + ' insertados, ' + CAST(@Actualizados AS VARCHAR) + ' versiones cerradas';

    END TRY
    BEGIN CATCH
        UPDATE ctrl.LogCargaETL
        SET FechaFin      = GETDATE(),
            Estado        = 'Error',
            MensajeError  = ERROR_MESSAGE()
        WHERE LogID = @LogID;

        THROW;
    END CATCH
END;
GO

PRINT '✓ Procedimiento ctrl.usp_CargarDimEmpleado creado';
GO

-- ============================================================
-- 2. PROCEDIMIENTO: Cargar Dim_Departamento con SCD Tipo 2
-- ============================================================

CREATE OR ALTER PROCEDURE ctrl.usp_CargarDimDepartamento
    @FechaCarga DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaCarga IS NULL SET @FechaCarga = CAST(GETDATE() AS DATE);

    DECLARE @LogID INT;
    DECLARE @Insertados INT = 0;
    DECLARE @Actualizados INT = 0;

    INSERT INTO ctrl.LogCargaETL (NombreProceso, TablaDestino, TipoCarga, FechaInicio)
    VALUES ('usp_CargarDimDepartamento', 'dim.Dim_Departamento', 'INCREMENTAL', GETDATE());
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        -- Insertar departamentos NUEVOS
        INSERT INTO dim.Dim_Departamento (
            DepartamentoID_OLTP, NombreDepartamento, Descripcion,
            CiudadOficina, PaisOficina,
            FechaInicioVig, FechaFinVig, EsVersionActual
        )
        SELECT
            d.DepartamentoID,
            d.NombreDepartamento,
            d.Descripcion,
            o.Ciudad,
            o.Pais,
            @FechaCarga, NULL, 1
        FROM RRHH.hr.Departamentos d
        JOIN RRHH.hr.Oficinas      o ON d.OficinaID = o.OficinaID
        WHERE d.Activo = 1
          AND NOT EXISTS (
              SELECT 1 FROM dim.Dim_Departamento dd
              WHERE dd.DepartamentoID_OLTP = d.DepartamentoID
                AND dd.EsVersionActual = 1
          );

        SET @Insertados = @@ROWCOUNT;

        -- Cerrar versiones cambiadas
        UPDATE dd
        SET FechaFinVig = DATEADD(DAY, -1, @FechaCarga), EsVersionActual = 0
        FROM dim.Dim_Departamento dd
        JOIN RRHH.hr.Departamentos d ON dd.DepartamentoID_OLTP = d.DepartamentoID
        JOIN RRHH.hr.Oficinas      o ON d.OficinaID = o.OficinaID
        WHERE dd.EsVersionActual = 1
          AND d.Activo = 1
          AND (
              dd.NombreDepartamento <> d.NombreDepartamento
           OR dd.CiudadOficina      <> o.Ciudad
           OR dd.PaisOficina        <> o.Pais
          );

        SET @Actualizados = @@ROWCOUNT;

        -- Insertar versiones nuevas para los cambiados
        INSERT INTO dim.Dim_Departamento (
            DepartamentoID_OLTP, NombreDepartamento, Descripcion,
            CiudadOficina, PaisOficina,
            FechaInicioVig, FechaFinVig, EsVersionActual
        )
        SELECT
            d.DepartamentoID, d.NombreDepartamento, d.Descripcion,
            o.Ciudad, o.Pais,
            @FechaCarga, NULL, 1
        FROM RRHH.hr.Departamentos d
        JOIN RRHH.hr.Oficinas      o ON d.OficinaID = o.OficinaID
        WHERE d.Activo = 1
          AND NOT EXISTS (
              SELECT 1 FROM dim.Dim_Departamento dd
              WHERE dd.DepartamentoID_OLTP = d.DepartamentoID
                AND dd.EsVersionActual = 1
          );

        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), RegistrosInsertados = @Insertados,
            RegistrosActualizados = @Actualizados,
            RegistrosProcesados = @Insertados + @Actualizados,
            Estado = 'Completado'
        WHERE LogID = @LogID;

        PRINT '✓ Dim_Departamento: ' + CAST(@Insertados AS VARCHAR)
              + ' insertados, ' + CAST(@Actualizados AS VARCHAR) + ' versiones cerradas';

    END TRY
    BEGIN CATCH
        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), Estado = 'Error', MensajeError = ERROR_MESSAGE()
        WHERE LogID = @LogID;
        THROW;
    END CATCH
END;


PRINT '✓ Procedimiento ctrl.usp_CargarDimDepartamento creado';
GO

-- ============================================================
-- 3. PROCEDIMIENTO: Cargar Dim_Puesto con SCD Tipo 2
-- ============================================================

CREATE OR ALTER PROCEDURE ctrl.usp_CargarDimPuesto
    @FechaCarga DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaCarga IS NULL SET @FechaCarga = CAST(GETDATE() AS DATE);

    DECLARE @LogID INT;
    DECLARE @Insertados INT = 0;
    DECLARE @Actualizados INT = 0;

    INSERT INTO ctrl.LogCargaETL (NombreProceso, TablaDestino, TipoCarga, FechaInicio)
    VALUES ('usp_CargarDimPuesto', 'dim.Dim_Puesto', 'INCREMENTAL', GETDATE());
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        -- Insertar puestos NUEVOS
        INSERT INTO dim.Dim_Puesto (
            PuestoID_OLTP, NombrePuesto, NivelSalarial,
            SalarioMinUSD, SalarioMaxUSD, RangoSalarial,
            FechaInicioVig, FechaFinVig, EsVersionActual
        )
        SELECT
            p.PuestoID,
            p.NombrePuesto,
            p.NivelSalarial,
            p.SalarioMinUSD,
            p.SalarioMaxUSD,
            'USD ' + FORMAT(p.SalarioMinUSD, 'N0')
                   + ' - ' + FORMAT(p.SalarioMaxUSD, 'N0'),
            @FechaCarga, NULL, 1
        FROM RRHH.hr.Puestos p
        WHERE p.Activo = 1
          AND NOT EXISTS (
              SELECT 1 FROM dim.Dim_Puesto dp
              WHERE dp.PuestoID_OLTP = p.PuestoID
                AND dp.EsVersionActual = 1
          );

        SET @Insertados = @@ROWCOUNT;

        -- Cerrar versiones cambiadas (cambio en bandas salariales)
        UPDATE dp
        SET FechaFinVig = DATEADD(DAY, -1, @FechaCarga), EsVersionActual = 0
        FROM dim.Dim_Puesto dp
        JOIN RRHH.hr.Puestos p ON dp.PuestoID_OLTP = p.PuestoID
        WHERE dp.EsVersionActual = 1
          AND p.Activo = 1
          AND (
              dp.NombrePuesto  <> p.NombrePuesto
           OR dp.NivelSalarial <> p.NivelSalarial
           OR dp.SalarioMinUSD <> p.SalarioMinUSD
           OR dp.SalarioMaxUSD <> p.SalarioMaxUSD
          );

        SET @Actualizados = @@ROWCOUNT;

        -- Insertar versiones nuevas
        INSERT INTO dim.Dim_Puesto (
            PuestoID_OLTP, NombrePuesto, NivelSalarial,
            SalarioMinUSD, SalarioMaxUSD, RangoSalarial,
            FechaInicioVig, FechaFinVig, EsVersionActual
        )
        SELECT
            p.PuestoID, p.NombrePuesto, p.NivelSalarial,
            p.SalarioMinUSD, p.SalarioMaxUSD,
            'USD ' + FORMAT(p.SalarioMinUSD, 'N0')
                   + ' - ' + FORMAT(p.SalarioMaxUSD, 'N0'),
            @FechaCarga, NULL, 1
        FROM RRHH.hr.Puestos p
        WHERE p.Activo = 1
          AND NOT EXISTS (
              SELECT 1 FROM dim.Dim_Puesto dp
              WHERE dp.PuestoID_OLTP = p.PuestoID
                AND dp.EsVersionActual = 1
          );

        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), RegistrosInsertados = @Insertados,
            RegistrosActualizados = @Actualizados,
            RegistrosProcesados = @Insertados + @Actualizados,
            Estado = 'Completado'
        WHERE LogID = @LogID;

        PRINT '✓ Dim_Puesto: ' + CAST(@Insertados AS VARCHAR)
              + ' insertados, ' + CAST(@Actualizados AS VARCHAR) + ' versiones cerradas';

    END TRY
    BEGIN CATCH
        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), Estado = 'Error', MensajeError = ERROR_MESSAGE()
        WHERE LogID = @LogID;
        THROW;
    END CATCH
END;
GO

PRINT '✓ Procedimiento ctrl.usp_CargarDimPuesto creado';
GO

-- ============================================================
-- 4. PROCEDIMIENTO: Cargar Dim_Capacitacion con SCD Tipo 2
-- ============================================================

CREATE OR ALTER PROCEDURE ctrl.usp_CargarDimCapacitacion
    @FechaCarga DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaCarga IS NULL SET @FechaCarga = CAST(GETDATE() AS DATE);

    DECLARE @LogID INT;
    DECLARE @Insertados INT = 0;
    DECLARE @Actualizados INT = 0;

    INSERT INTO ctrl.LogCargaETL (NombreProceso, TablaDestino, TipoCarga, FechaInicio)
    VALUES ('usp_CargarDimCapacitacion', 'dim.Dim_Capacitacion', 'INCREMENTAL', GETDATE());
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        -- Insertar capacitaciones NUEVAS
        INSERT INTO dim.Dim_Capacitacion (
            CapacitacionID_OLTP, NombreCapacitacion, Proveedor,
            CostoUSD, DuracionDias,
            FechaInicioVig, FechaFinVig, EsVersionActual
        )
        SELECT
            c.CapacitacionID,
            c.NombreCapacitacion,
            c.Proveedor,
            c.CostoUSD,
            c.DuracionDias,
            @FechaCarga, NULL, 1
        FROM RRHH.hr.Capacitaciones c
        WHERE c.Activa = 1
          AND NOT EXISTS (
              SELECT 1 FROM dim.Dim_Capacitacion dc
              WHERE dc.CapacitacionID_OLTP = c.CapacitacionID
                AND dc.EsVersionActual = 1
          );

        SET @Insertados = @@ROWCOUNT;

        -- Cerrar versiones cambiadas (cambio en proveedor o costo)
        UPDATE dc
        SET FechaFinVig = DATEADD(DAY, -1, @FechaCarga), EsVersionActual = 0
        FROM dim.Dim_Capacitacion dc
        JOIN RRHH.hr.Capacitaciones c ON dc.CapacitacionID_OLTP = c.CapacitacionID
        WHERE dc.EsVersionActual = 1
          AND c.Activa = 1
          AND (
              dc.NombreCapacitacion <> c.NombreCapacitacion
           OR dc.Proveedor          <> c.Proveedor
           OR dc.CostoUSD           <> c.CostoUSD
          );

        SET @Actualizados = @@ROWCOUNT;

        -- Insertar versiones nuevas
        INSERT INTO dim.Dim_Capacitacion (
            CapacitacionID_OLTP, NombreCapacitacion, Proveedor,
            CostoUSD, DuracionDias,
            FechaInicioVig, FechaFinVig, EsVersionActual
        )
        SELECT
            c.CapacitacionID, c.NombreCapacitacion, c.Proveedor,
            c.CostoUSD, c.DuracionDias,
            @FechaCarga, NULL, 1
        FROM RRHH.hr.Capacitaciones c
        WHERE c.Activa = 1
          AND NOT EXISTS (
              SELECT 1 FROM dim.Dim_Capacitacion dc
              WHERE dc.CapacitacionID_OLTP = c.CapacitacionID
                AND dc.EsVersionActual = 1
          );

        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), RegistrosInsertados = @Insertados,
            RegistrosActualizados = @Actualizados,
            RegistrosProcesados = @Insertados + @Actualizados,
            Estado = 'Completado'
        WHERE LogID = @LogID;

        PRINT '✓ Dim_Capacitacion: ' + CAST(@Insertados AS VARCHAR)
              + ' insertados, ' + CAST(@Actualizados AS VARCHAR) + ' versiones cerradas';

    END TRY
    BEGIN CATCH
        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), Estado = 'Error', MensajeError = ERROR_MESSAGE()
        WHERE LogID = @LogID;
        THROW;
    END CATCH
END;
GO

PRINT '✓ Procedimiento ctrl.usp_CargarDimCapacitacion creado';
GO

-- ============================================================
-- 5. PROCEDIMIENTO: Purgar historial antiguo — Data Lifecycle
-- ============================================================
-- Política de retención: Ley 1581/2012 Colombia.
-- Elimina versiones históricas (EsVersionActual = 0) con
-- FechaFinVig mayor a 5 años.
-- La versión actual (EsVersionActual = 1) NUNCA se elimina.
-- Se recomienda ejecutar una vez al año en enero.
-- ============================================================

CREATE OR ALTER PROCEDURE ctrl.usp_PurgarHistorialDimensiones
    @AniosRetencion INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FechaCorte DATE = DATEADD(YEAR, -@AniosRetencion, GETDATE());
    DECLARE @LogID      INT;
    DECLARE @TotalPurgado INT = 0;
    DECLARE @PurgadosPorTabla INT;

    INSERT INTO ctrl.LogCargaETL (NombreProceso, TablaDestino, TipoCarga, FechaInicio)
    VALUES ('usp_PurgarHistorialDimensiones', 'dim.*', 'FULL', GETDATE());
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        -- Purgar Dim_Empleado
        DELETE FROM dim.Dim_Empleado
        WHERE EsVersionActual = 0
          AND FechaFinVig     < @FechaCorte;
        SET @PurgadosPorTabla = @@ROWCOUNT;
        SET @TotalPurgado += @PurgadosPorTabla;
        PRINT '  Dim_Empleado:      ' + CAST(@PurgadosPorTabla AS VARCHAR) + ' versiones eliminadas';

        -- Purgar Dim_Departamento
        DELETE FROM dim.Dim_Departamento
        WHERE EsVersionActual = 0
          AND FechaFinVig     < @FechaCorte;
        SET @PurgadosPorTabla = @@ROWCOUNT;
        SET @TotalPurgado += @PurgadosPorTabla;
        PRINT '  Dim_Departamento:  ' + CAST(@PurgadosPorTabla AS VARCHAR) + ' versiones eliminadas';

        -- Purgar Dim_Puesto
        DELETE FROM dim.Dim_Puesto
        WHERE EsVersionActual = 0
          AND FechaFinVig     < @FechaCorte;
        SET @PurgadosPorTabla = @@ROWCOUNT;
        SET @TotalPurgado += @PurgadosPorTabla;
        PRINT '  Dim_Puesto:        ' + CAST(@PurgadosPorTabla AS VARCHAR) + ' versiones eliminadas';

        -- Purgar Dim_Capacitacion
        DELETE FROM dim.Dim_Capacitacion
        WHERE EsVersionActual = 0
          AND FechaFinVig     < @FechaCorte;
        SET @PurgadosPorTabla = @@ROWCOUNT;
        SET @TotalPurgado += @PurgadosPorTabla;
        PRINT '  Dim_Capacitacion:  ' + CAST(@PurgadosPorTabla AS VARCHAR) + ' versiones eliminadas';

        UPDATE ctrl.LogCargaETL
        SET FechaFin            = GETDATE(),
            RegistrosProcesados = @TotalPurgado,
            Estado              = 'Completado',
            MensajeError        = 'Retención: ' + CAST(@AniosRetencion AS VARCHAR)
                                  + ' años. Corte: ' + CAST(@FechaCorte AS VARCHAR)
        WHERE LogID = @LogID;

        PRINT '✓ Purga completada: ' + CAST(@TotalPurgado AS VARCHAR)
              + ' registros históricos eliminados (corte: '
              + CAST(@FechaCorte AS VARCHAR) + ')';

    END TRY
    BEGIN CATCH
        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), Estado = 'Error', MensajeError = ERROR_MESSAGE()
        WHERE LogID = @LogID;
        THROW;
    END CATCH
END;
GO

PRINT '✓ Procedimiento ctrl.usp_PurgarHistorialDimensiones creado';
GO

-- ============================================================
-- 6. VERIFICACIÓN FINAL
-- ============================================================

SELECT
    ROUTINE_SCHEMA  AS Esquema,
    ROUTINE_NAME    AS Procedimiento,
    CREATED         AS FechaCreacion
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE   = 'PROCEDURE'
  AND ROUTINE_SCHEMA = 'ctrl'
ORDER BY ROUTINE_NAME;
GO

PRINT '';
PRINT '============================================================';
PRINT '✅ SCRIPT 04 COMPLETADO — PROCEDIMIENTOS SCD TIPO 2';
PRINT '';
PRINT '  usp_CargarDimEmpleado       → SCD Tipo 2';
PRINT '  usp_CargarDimDepartamento   → SCD Tipo 2';
PRINT '  usp_CargarDimPuesto         → SCD Tipo 2';
PRINT '  usp_CargarDimCapacitacion   → SCD Tipo 2';
PRINT '  usp_PurgarHistorialDimensiones → retención 5 años';
PRINT '';
PRINT '  Siguiente paso: Ejecutar 05_Crear_Hechos.sql';
PRINT '============================================================';
GO