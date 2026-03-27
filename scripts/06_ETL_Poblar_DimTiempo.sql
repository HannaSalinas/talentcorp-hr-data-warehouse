-- ============================================================
-- SCRIPT 06: ETL — POBLAR DIM_TIEMPO
-- Base de Datos : RRHH_DW
-- Propósito     : Generar un registro por cada día del período
--                 de análisis con todos sus atributos de fecha
--                 precalculados para consultas analíticas rápidas
-- Autora        : Hanna
-- Fecha         : 2026
-- ============================================================
-- CONCEPTO — ¿POR QUÉ PRECALCULAR FECHAS?
--   Sin Dim_Tiempo: SELECT YEAR(FechaInicio), MONTH(FechaInicio)...
--   → SQL calcula año/mes/trimestre en CADA fila, en CADA consulta
--
--   Con Dim_Tiempo: SELECT t.Anio, t.NombreMes, t.Trimestre...
--   → Los atributos ya están calculados, solo se hace un JOIN
--   → Las consultas analíticas son hasta 10x más rápidas
--   → Puedes filtrar fácil: WHERE t.EsFestivoCOL = 1
--
-- RANGO: 2022-01-01 al 2026-12-31
--   Cubre datos históricos del OLTP (2023-2024) con margen
--   para datos futuros del DWH.
--
-- TiempoID: formato YYYYMMDD (ej: 20230315)
--   Permite ordenar cronológicamente con solo ORDER BY TiempoID
-- ============================================================

USE RRHH_DW;
GO

-- ============================================================
-- 1. PROCEDIMIENTO: Generar Dim_Tiempo
-- ============================================================

CREATE OR ALTER PROCEDURE ctrl.usp_GenerarDimTiempo
    @FechaInicio DATE = '2022-01-01',
    @FechaFin    DATE = '2026-12-31'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID       INT;
    DECLARE @FechaActual DATE = @FechaInicio;
    DECLARE @Insertados  INT  = 0;

    INSERT INTO ctrl.LogCargaETL (NombreProceso, TablaDestino, TipoCarga, FechaInicio)
    VALUES ('usp_GenerarDimTiempo', 'dim.Dim_Tiempo', 'FULL', GETDATE());
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        -- ── Bucle: un INSERT por cada día del rango ───────────
        WHILE @FechaActual <= @FechaFin
        BEGIN
            INSERT INTO dim.Dim_Tiempo (
                TiempoID,
                Fecha,
                Anio,
                Semestre,
                Trimestre,
                Mes,
                NombreMes,
                Semana,
                DiaSemana,
                NombreDia,
                EsFinDeSemana,
                EsFestivoCOL,
                AnioMes,
                AnioTrimestre
            )
            VALUES (
                -- TiempoID: YYYYMMDD como entero
                CAST(FORMAT(@FechaActual, 'yyyyMMdd') AS INT),

                @FechaActual,

                YEAR(@FechaActual),

                -- Semestre: 1 si mes <= 6, sino 2
                CASE WHEN MONTH(@FechaActual) <= 6 THEN 1 ELSE 2 END,

                -- Trimestre: 1 a 4
                DATEPART(QUARTER, @FechaActual),

                MONTH(@FechaActual),

                -- Nombre del mes en español
                CASE MONTH(@FechaActual)
                    WHEN  1 THEN 'Enero'
                    WHEN  2 THEN 'Febrero'
                    WHEN  3 THEN 'Marzo'
                    WHEN  4 THEN 'Abril'
                    WHEN  5 THEN 'Mayo'
                    WHEN  6 THEN 'Junio'
                    WHEN  7 THEN 'Julio'
                    WHEN  8 THEN 'Agosto'
                    WHEN  9 THEN 'Septiembre'
                    WHEN 10 THEN 'Octubre'
                    WHEN 11 THEN 'Noviembre'
                    WHEN 12 THEN 'Diciembre'
                END,

                -- Semana ISO del año (1 a 53)
                DATEPART(ISO_WEEK, @FechaActual),

                -- Día de la semana: 1=Lunes ... 7=Domingo
                -- DATEPART(WEEKDAY) devuelve 1=Domingo en SQL Server
                -- lo transformamos a 1=Lunes para estándar ISO
                CASE DATEPART(WEEKDAY, @FechaActual)
                    WHEN 1 THEN 7  -- Domingo → 7
                    ELSE DATEPART(WEEKDAY, @FechaActual) - 1
                END,

                -- Nombre del día en español
                CASE DATEPART(WEEKDAY, @FechaActual)
                    WHEN 1 THEN 'Domingo'
                    WHEN 2 THEN 'Lunes'
                    WHEN 3 THEN 'Martes'
                    WHEN 4 THEN 'Miércoles'
                    WHEN 5 THEN 'Jueves'
                    WHEN 6 THEN 'Viernes'
                    WHEN 7 THEN 'Sábado'
                END,

                -- Es fin de semana: Sábado (7) o Domingo (1)
                CASE WHEN DATEPART(WEEKDAY, @FechaActual) IN (1, 7) THEN 1 ELSE 0 END,

                -- Festivos Colombia (fechas fijas más importantes)
                -- Festivos de fecha fija: aplican todos los años
                CASE
                    WHEN FORMAT(@FechaActual,'MM-dd') IN (
                        '01-01',  -- Año Nuevo
                        '05-01',  -- Día del Trabajo
                        '07-20',  -- Independencia Colombia
                        '08-07',  -- Batalla de Boyacá
                        '12-08',  -- Inmaculada Concepción
                        '12-25'   -- Navidad
                    ) THEN 1
                    -- Festivos de fecha variable (aprox. por año — Ley Emiliani)
                    -- Reyes Magos, San José, San Pedro, Asunción, Día de la Raza,
                    -- Todos los Santos, Independencia Cartagena
                    WHEN @FechaActual IN (
                        -- 2022
                        '2022-01-10','2022-03-21','2022-05-30','2022-06-27',
                        '2022-07-04','2022-08-15','2022-10-17','2022-11-07',
                        '2022-11-14','2022-06-06','2022-06-16',
                        -- 2023
                        '2023-01-09','2023-03-20','2023-06-12','2023-06-19',
                        '2023-07-03','2023-08-07','2023-10-16','2023-11-06',
                        '2023-11-13','2023-04-06','2023-04-07',
                        -- 2024
                        '2024-01-08','2024-03-25','2024-05-13','2024-05-20',
                        '2024-07-01','2024-08-19','2024-10-14','2024-11-04',
                        '2024-11-11','2024-03-28','2024-03-29',
                        -- 2025
                        '2025-01-06','2025-03-24','2025-06-02','2025-06-23',
                        '2025-06-30','2025-08-18','2025-10-13','2025-11-03',
                        '2025-11-17','2025-04-17','2025-04-18',
                        -- 2026
                        '2026-01-12','2026-03-23','2026-05-25','2026-06-15',
                        '2026-06-29','2026-08-17','2026-10-12','2026-11-02',
                        '2026-11-16','2026-04-02','2026-04-03'
                    ) THEN 1
                    ELSE 0
                END,

                -- AnioMes: formato 'YYYY-MM' para agrupar por mes fácilmente
                FORMAT(@FechaActual, 'yyyy-MM'),

                -- AnioTrimestre: formato 'YYYY-Q#'
                CAST(YEAR(@FechaActual) AS VARCHAR)
                + '-Q' + CAST(DATEPART(QUARTER, @FechaActual) AS VARCHAR)
            );

            SET @Insertados  = @Insertados + 1;
            SET @FechaActual = DATEADD(DAY, 1, @FechaActual);
        END

        UPDATE ctrl.LogCargaETL
        SET FechaFin            = GETDATE(),
            RegistrosInsertados = @Insertados,
            RegistrosProcesados = @Insertados,
            Estado              = 'Completado',
            MensajeError        = 'Rango: ' + CAST(@FechaInicio AS VARCHAR)
                                  + ' → ' + CAST(@FechaFin AS VARCHAR)
        WHERE LogID = @LogID;

        PRINT '✓ Dim_Tiempo generada: ' + CAST(@Insertados AS VARCHAR)
              + ' días (' + CAST(@FechaInicio AS VARCHAR)
              + ' → ' + CAST(@FechaFin AS VARCHAR) + ')';

    END TRY
    BEGIN CATCH
        UPDATE ctrl.LogCargaETL
        SET FechaFin = GETDATE(), Estado = 'Error', MensajeError = ERROR_MESSAGE()
        WHERE LogID = @LogID;
        THROW;
    END CATCH
END;
GO

PRINT '✓ Procedimiento ctrl.usp_GenerarDimTiempo creado';
GO

-- ============================================================
-- 2. EJECUTAR — generar el calendario 2022-2026
-- ============================================================

EXEC ctrl.usp_GenerarDimTiempo
    @FechaInicio = '2022-01-01',
    @FechaFin    = '2026-12-31';
GO

-- ============================================================
-- 3. VERIFICACIÓN
-- ============================================================

-- Total de días generados
SELECT
    COUNT(*)                    AS TotalDias,
    MIN(Fecha)                  AS PrimerDia,
    MAX(Fecha)                  AS UltimoDia,
    SUM(CAST(EsFinDeSemana AS INT)) AS DiasFinDeSemana,
    SUM(CAST(EsFestivoCOL AS INT))  AS FestivosColombia
FROM dim.Dim_Tiempo;
GO

-- Distribución por año
SELECT
    Anio,
    COUNT(*)                         AS TotalDias,
    SUM(CAST(EsFestivoCOL AS INT))   AS Festivos,
    SUM(CAST(EsFinDeSemana AS INT))  AS FinsDeSemana
FROM dim.Dim_Tiempo
GROUP BY Anio
ORDER BY Anio;
GO

-- Muestra de registros para validar atributos
SELECT TOP 10
    TiempoID, Fecha, Anio, Semestre, Trimestre,
    NombreMes, NombreDia, EsFinDeSemana,
    EsFestivoCOL, AnioMes, AnioTrimestre
FROM dim.Dim_Tiempo
WHERE Anio = 2023
ORDER BY TiempoID;
GO

PRINT '';
PRINT '============================================================';
PRINT '✅ SCRIPT 06 COMPLETADO — DIM_TIEMPO GENERADA';
PRINT '';
PRINT '  Rango   : 2022-01-01 → 2026-12-31';
PRINT '  ~1826 días precalculados con atributos en español';
PRINT '  Festivos Colombia incluidos (Ley Emiliani)';
PRINT '';
PRINT '  Siguiente paso: Ejecutar 07_ETL_Cargar_Dimensiones.sql';
PRINT '============================================================';
GO