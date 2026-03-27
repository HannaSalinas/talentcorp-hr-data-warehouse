-- ============================================================
-- SCRIPT 05: PROCEDIMIENTOS ETL — TABLAS DE HECHOS
-- Base de Datos : RRHH_DW
-- Propósito     : Stored procedures para cargar las 4 tablas
--                 de hechos desde el OLTP RRHH al DWH
-- Autora        : Hanna
-- Fecha         : 2026
-- ============================================================
-- CONCEPTO — CARGA DE HECHOS:
--   A diferencia de las dimensiones, los hechos NO tienen SCD.
--   Los hechos son eventos que ya ocurrieron — una ausencia,
--   una evaluación — y no cambian. Si un dato del OLTP se
--   corrige, el proceso detecta el cambio y actualiza el hecho.
--
--   La clave para unir OLTP → DWH es el surrogate key:
--   Nunca usamos el ID del OLTP como FK en los hechos.
--   Buscamos el SK del DWH que corresponde al ID del OLTP
--   en el momento en que ocurrió el evento (fecha del hecho).
--   Esto garantiza que el hecho quede ligado a la versión
--   correcta de cada dimensión — SCD Tipo 2 en acción.
-- ============================================================

USE RRHH_DW;
GO

-- ============================================================
-- 1. PROCEDIMIENTO: Cargar Fact_Ausencias
-- ============================================================
-- Une ausencias del OLTP con los surrogate keys del DWH
-- usando la fecha del evento para respetar SCD Tipo 2.
-- Detecta registros nuevos que no existen aún en el hecho.
-- ============================================================

CREATE OR ALTER PROCEDURE ctrl.usp_CargarFactAusencias
    @FechaCarga DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaCarga IS NULL SET @FechaCarga = CAST(GETDATE() AS DATE);

    DECLARE @LogID      INT;
    DECLARE @Insertados INT = 0;

    INSERT INTO ctrl.LogCargaETL (NombreProceso, TablaDestino, TipoCarga, FechaInicio)
    VALUES ('usp_CargarFactAusencias', 'fact.Fact_Ausencias', 'INCREMENTAL', GETDATE());
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        INSERT INTO fact.Fact_Ausencias (
            EmpleadoSK, DepartamentoSK, TipoAusenciaSK,
            FechaInicioID, FechaFinID,
            AusenciaID_OLTP, DiasTotales, EsJustificada
        )
        SELECT
            -- Buscar el SK del empleado vigente en la fecha de inicio
            -- de la ausencia — así respetamos SCD Tipo 2
            de.EmpleadoSK,
            dd.DepartamentoSK,
            ta.TipoAusenciaSK,
            -- TiempoID tiene formato YYYYMMDD (se genera en Script 06)
            ti_ini.TiempoID,
            ti_fin.TiempoID,
            a.AusenciaID,
            a.DiasTotales,
            CASE WHEN a.Justificada = 'Si' THEN 1 ELSE 0 END

        FROM RRHH.hr.Ausencias           a
        -- Empleado: versión vigente en la fecha de inicio de la ausencia
        JOIN dim.Dim_Empleado            de  ON de.EmpleadoID_OLTP = a.EmpleadoID
                                             AND a.FechaInicio >= de.FechaInicioVig
                                             AND (de.FechaFinVig IS NULL
                                                  OR a.FechaInicio <= de.FechaFinVig)
        -- Departamento: versión vigente en esa misma fecha
        JOIN dim.Dim_Departamento        dd  ON dd.NombreDepartamento = de.Departamento
                                             AND dd.EsVersionActual = 1
        -- Tipo de ausencia: dimensión estática
        JOIN dim.Dim_TipoAusencia        ta  ON ta.TipoAusencia = a.TipoAusencia
        -- Tiempo inicio y fin (deben existir en Dim_Tiempo)
        JOIN dim.Dim_Tiempo              ti_ini ON ti_ini.Fecha = a.FechaInicio
        JOIN dim.Dim_Tiempo              ti_fin ON ti_fin.Fecha = a.FechaFin
        -- Solo insertar registros que no existen aún en el hecho
        WHERE NOT EXISTS (
            SELECT 1 FROM fact.Fact_Ausencias fa
            WHERE fa.AusenciaID_OLTP = a.AusenciaID
        );

        SET @Insertados = @@ROWCOUNT;

        UPDATE ctrl.LogCargaETL
        SET FechaFin            = GETDATE(),
            RegistrosInsertados = @Insertados,
            RegistrosProcesados = @Insertados,
            Estado              = 'Completado'
        WHERE LogID = @LogID;

        PRINT '✓ Fact_Ausencias: ' + CAST(@Insertados AS VARCHAR) + ' registros insertados';

    END TRY
    BEGIN CATCH
        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), Estado = 'Error', MensajeError = ERROR_MESSAGE()
        WHERE LogID = @LogID;
        THROW;
    END CATCH
END;
GO

PRINT '✓ Procedimiento ctrl.usp_CargarFactAusencias creado';
GO

-- ============================================================
-- 2. PROCEDIMIENTO: Cargar Fact_Evaluaciones
-- ============================================================
-- Dos FKs a Dim_Empleado: evaluado y evaluador (role-playing).
-- Ambas buscan la versión vigente en la fecha de evaluación.
-- ============================================================

CREATE OR ALTER PROCEDURE ctrl.usp_CargarFactEvaluaciones
    @FechaCarga DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaCarga IS NULL SET @FechaCarga = CAST(GETDATE() AS DATE);

    DECLARE @LogID      INT;
    DECLARE @Insertados INT = 0;

    INSERT INTO ctrl.LogCargaETL (NombreProceso, TablaDestino, TipoCarga, FechaInicio)
    VALUES ('usp_CargarFactEvaluaciones', 'fact.Fact_Evaluaciones', 'INCREMENTAL', GETDATE());
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        INSERT INTO fact.Fact_Evaluaciones (
            EmpleadoEvaluadoSK, EvaluadorSK,
            DepartamentoSK, PuestoSK, FechaEvaluacionID,
            EvaluacionID_OLTP, Calificacion, Periodo
        )
        SELECT
            -- Versión del evaluado vigente en la fecha de evaluación
            de_eval.EmpleadoSK,
            -- Versión del evaluador vigente en esa misma fecha
            de_evador.EmpleadoSK,
            dd.DepartamentoSK,
            dp.PuestoSK,
            ti.TiempoID,
            ev.EvaluacionID,
            ev.Calificacion,
            ev.Periodo

        FROM RRHH.hr.Evaluaciones        ev
        -- Empleado evaluado: versión SCD vigente en fecha evaluación
        JOIN dim.Dim_Empleado            de_eval   ON de_eval.EmpleadoID_OLTP = ev.EmpleadoEvaluadoID
                                                   AND ev.FechaEvaluacion >= de_eval.FechaInicioVig
                                                   AND (de_eval.FechaFinVig IS NULL
                                                        OR ev.FechaEvaluacion <= de_eval.FechaFinVig)
        -- Evaluador: versión SCD vigente en fecha evaluación
        JOIN dim.Dim_Empleado            de_evador ON de_evador.EmpleadoID_OLTP = ev.EvaluadorID
                                                   AND ev.FechaEvaluacion >= de_evador.FechaInicioVig
                                                   AND (de_evador.FechaFinVig IS NULL
                                                        OR ev.FechaEvaluacion <= de_evador.FechaFinVig)
        -- Departamento del evaluado
        JOIN dim.Dim_Departamento        dd        ON dd.NombreDepartamento = de_eval.Departamento
                                                   AND dd.EsVersionActual = 1
        -- Puesto del evaluado
        JOIN dim.Dim_Puesto              dp        ON dp.NombrePuesto = de_eval.NombrePuesto
                                                   AND dp.EsVersionActual = 1
        -- Tiempo
        JOIN dim.Dim_Tiempo              ti        ON ti.Fecha = ev.FechaEvaluacion
        -- Solo nuevos
        WHERE NOT EXISTS (
            SELECT 1 FROM fact.Fact_Evaluaciones fe
            WHERE fe.EvaluacionID_OLTP = ev.EvaluacionID
        );

        SET @Insertados = @@ROWCOUNT;

        UPDATE ctrl.LogCargaETL
        SET FechaFin            = GETDATE(),
            RegistrosInsertados = @Insertados,
            RegistrosProcesados = @Insertados,
            Estado              = 'Completado'
        WHERE LogID = @LogID;

        PRINT '✓ Fact_Evaluaciones: ' + CAST(@Insertados AS VARCHAR) + ' registros insertados';

    END TRY
    BEGIN CATCH
        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), Estado = 'Error', MensajeError = ERROR_MESSAGE()
        WHERE LogID = @LogID;
        THROW;
    END CATCH
END;
GO

PRINT '✓ Procedimiento ctrl.usp_CargarFactEvaluaciones creado';
GO

-- ============================================================
-- 3. PROCEDIMIENTO: Cargar Fact_Capacitaciones
-- ============================================================
-- FechaCompletadoID puede ser NULL si la capacitación está
-- En Curso — el hecho se inserta igual para monitorear
-- capacitaciones activas en el DWH.
-- ============================================================

CREATE OR ALTER PROCEDURE ctrl.usp_CargarFactCapacitaciones
    @FechaCarga DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaCarga IS NULL SET @FechaCarga = CAST(GETDATE() AS DATE);

    DECLARE @LogID      INT;
    DECLARE @Insertados INT = 0;

    INSERT INTO ctrl.LogCargaETL (NombreProceso, TablaDestino, TipoCarga, FechaInicio)
    VALUES ('usp_CargarFactCapacitaciones', 'fact.Fact_Capacitaciones', 'INCREMENTAL', GETDATE());
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        INSERT INTO fact.Fact_Capacitaciones (
            EmpleadoSK, CapacitacionSK, DepartamentoSK,
            FechaCompletadoID, AsignacionID_OLTP,
            CalificacionObtenida, CostoUSD, DuracionDias, Estado
        )
        SELECT
            de.EmpleadoSK,
            dc.CapacitacionSK,
            dd.DepartamentoSK,
            -- NULL si está En Curso, sino buscar TiempoID
            CASE
                WHEN ec.FechaCompletado IS NOT NULL
                THEN ti.TiempoID
                ELSE NULL
            END,
            ec.AsignacionID,
            ec.CalificacionObtenida,
            c.CostoUSD,
            c.DuracionDias,
            ec.Estado

        FROM RRHH.hr.EmpleadosCapacitaciones  ec
        JOIN RRHH.hr.Capacitaciones            c   ON ec.CapacitacionID = c.CapacitacionID
        -- Empleado: versión actual (la capacitación es reciente)
        JOIN dim.Dim_Empleado                  de  ON de.EmpleadoID_OLTP = ec.EmpleadoID
                                                   AND de.EsVersionActual = 1
        -- Capacitación: versión actual
        JOIN dim.Dim_Capacitacion              dc  ON dc.CapacitacionID_OLTP = ec.CapacitacionID
                                                   AND dc.EsVersionActual = 1
        -- Departamento actual del empleado
        JOIN dim.Dim_Departamento              dd  ON dd.NombreDepartamento = de.Departamento
                                                   AND dd.EsVersionActual = 1
        -- Fecha completado: solo si existe
        LEFT JOIN dim.Dim_Tiempo               ti  ON ti.Fecha = ec.FechaCompletado
        -- Solo nuevos
        WHERE NOT EXISTS (
            SELECT 1 FROM fact.Fact_Capacitaciones fc
            WHERE fc.AsignacionID_OLTP = ec.AsignacionID
        );

        SET @Insertados = @@ROWCOUNT;

        UPDATE ctrl.LogCargaETL
        SET FechaFin            = GETDATE(),
            RegistrosInsertados = @Insertados,
            RegistrosProcesados = @Insertados,
            Estado              = 'Completado'
        WHERE LogID = @LogID;

        PRINT '✓ Fact_Capacitaciones: ' + CAST(@Insertados AS VARCHAR) + ' registros insertados';

    END TRY
    BEGIN CATCH
        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), Estado = 'Error', MensajeError = ERROR_MESSAGE()
        WHERE LogID = @LogID;
        THROW;
    END CATCH
END;
GO

PRINT '✓ Procedimiento ctrl.usp_CargarFactCapacitaciones creado';
GO

-- ============================================================
-- 4. PROCEDIMIENTO: Cargar Fact_Headcount (snapshot mensual)
-- ============================================================
-- Genera una fotografía mensual del estado de la plantilla.
-- Se ejecuta el primer día de cada mes.
-- Toma el salario vigente de sec.EmpleadosSalarios en el OLTP.
-- Solo inserta si no existe ya un snapshot para ese mes.
-- ============================================================

CREATE OR ALTER PROCEDURE ctrl.usp_CargarFactHeadcount
    @FechaSnapshot DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaSnapshot IS NULL
        SET @FechaSnapshot = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    ELSE
        SET @FechaSnapshot = DATEFROMPARTS(YEAR(@FechaSnapshot), MONTH(@FechaSnapshot), 1);

    DECLARE @LogID       INT;
    DECLARE @Insertados  INT = 0;
    -- Convertir a VARCHAR para usar en RAISERROR
    DECLARE @FechaStr    VARCHAR(20) = CAST(@FechaSnapshot AS VARCHAR(20));

    INSERT INTO ctrl.LogCargaETL (NombreProceso, TablaDestino, TipoCarga, FechaInicio)
    VALUES ('usp_CargarFactHeadcount', 'fact.Fact_Headcount', 'INCREMENTAL', GETDATE());
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        IF NOT EXISTS (SELECT 1 FROM dim.Dim_Tiempo WHERE Fecha = @FechaSnapshot)
        BEGIN
            RAISERROR('Fecha %s no existe en Dim_Tiempo. Ejecutar Script 06 primero.',
                      16, 1, @FechaStr);
            RETURN;
        END

        INSERT INTO fact.Fact_Headcount (
            EmpleadoSK, DepartamentoSK, PuestoSK,
            FechaSnapshotID, EmpleadoID_OLTP,
            SalarioMesUSD, AntiguedadMeses, EsActivo
        )
        SELECT
            de.EmpleadoSK,
            dd.DepartamentoSK,
            dp.PuestoSK,
            ti.TiempoID,
            e.EmpleadoID,
            ISNULL(s.SalarioUSD, 0),
            DATEDIFF(MONTH, e.FechaContratacion, @FechaSnapshot),
            e.Activo
        FROM RRHH.hr.Empleados               e
        JOIN dim.Dim_Empleado                 de ON de.EmpleadoID_OLTP = e.EmpleadoID
                                                AND @FechaSnapshot >= de.FechaInicioVig
                                                AND (de.FechaFinVig IS NULL
                                                     OR @FechaSnapshot <= de.FechaFinVig)
        JOIN dim.Dim_Departamento             dd ON dd.NombreDepartamento = de.Departamento
                                                AND dd.EsVersionActual = 1
        JOIN dim.Dim_Puesto                   dp ON dp.NombrePuesto = de.NombrePuesto
                                                AND dp.EsVersionActual = 1
        JOIN dim.Dim_Tiempo                   ti ON ti.Fecha = @FechaSnapshot
        LEFT JOIN RRHH.sec.EmpleadosSalarios  s  ON s.EmpleadoID = e.EmpleadoID
                                                AND s.EsActual = 1
        WHERE NOT EXISTS (
            SELECT 1 FROM fact.Fact_Headcount fh
            JOIN dim.Dim_Tiempo ti2 ON fh.FechaSnapshotID = ti2.TiempoID
            WHERE fh.EmpleadoSK = de.EmpleadoSK
              AND ti2.AnioMes   = FORMAT(@FechaSnapshot, 'yyyy-MM')
        );

        SET @Insertados = @@ROWCOUNT;

        UPDATE ctrl.LogCargaETL
        SET FechaFin            = GETDATE(),
            RegistrosInsertados = @Insertados,
            RegistrosProcesados = @Insertados,
            Estado              = 'Completado',
            MensajeError        = 'Snapshot: ' + @FechaStr
        WHERE LogID = @LogID;

        PRINT '✓ Fact_Headcount snapshot ' + @FechaStr
              + ': ' + CAST(@Insertados AS VARCHAR) + ' registros insertados';

    END TRY
    BEGIN CATCH
        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), Estado = 'Error', MensajeError = ERROR_MESSAGE()
        WHERE LogID = @LogID;
        THROW;
    END CATCH
END;
GO

PRINT '✓ Procedimiento ctrl.usp_CargarFactHeadcount creado';
GO

-- ============================================================
-- 5. VERIFICACIÓN FINAL
-- ============================================================

SELECT
    ROUTINE_SCHEMA AS Esquema,
    ROUTINE_NAME   AS Procedimiento,
    CREATED        AS FechaCreacion
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE   = 'PROCEDURE'
  AND ROUTINE_SCHEMA = 'ctrl'
ORDER BY ROUTINE_NAME;
GO

PRINT '';
PRINT '============================================================';
PRINT '✅ SCRIPT 05 COMPLETADO — PROCEDIMIENTOS ETL HECHOS';
PRINT '';
PRINT '  usp_CargarFactAusencias      → carga incremental';
PRINT '  usp_CargarFactEvaluaciones   → role-playing SCD';
PRINT '  usp_CargarFactCapacitaciones → maneja En Curso';
PRINT '  usp_CargarFactHeadcount      → snapshot mensual';
PRINT '';
PRINT '  ORDEN DE EJECUCIÓN ETL:';
PRINT '  06 Dim_Tiempo → 07 Dimensiones → 08 Hechos';
PRINT '============================================================';
GO