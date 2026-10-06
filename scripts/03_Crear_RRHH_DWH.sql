-- ============================================================
-- SCRIPT 03: CREAR DATA WAREHOUSE RRHH_DW
-- Base de Datos : RRHH_DW
-- Propósito     : Data Warehouse dimensional para análisis
--                 estratégico de Recursos Humanos en TalentCorp
-- Autora        : Hanna
-- Fecha         : 2026
-- Motor         : SQL Server 2019 (contenedor Docker / DBeaver)
-- ============================================================
-- ARQUITECTURA:
--   Modelo dimensional Star Schema con 5 dimensiones y 4 hechos.
--   El DWH es de SOLO LECTURA para analistas — nadie escribe
--   directamente aquí, solo los procesos ETL tienen permiso.
--
-- DECISIÓN DE SEGURIDAD:
--   El DWH tiene seguridad más estricta que el OLTP porque
--   los patrones agregados son más peligrosos que datos
--   individuales — permiten decisiones discriminatorias
--   disfrazadas de "análisis de datos".
--   → Row-Level Security: cada gerente ve solo su departamento.
--   → Solo DWH_Admin y DWH_ETL ven todo.
--
-- ESQUEMAS:
--   dim  → tablas de dimensiones (contexto del análisis)
--   fact → tablas de hechos (métricas del negocio)
--   ctrl → control de carga ETL y auditoría
-- ============================================================

USE master;
GO

-- ============================================================
-- 1. ELIMINAR BASE DE DATOS SI EXISTE
-- ============================================================

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'RRHH_DW')
BEGIN
    ALTER DATABASE RRHH_DW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE RRHH_DW;
    PRINT '✓ Base de datos RRHH_DW eliminada';
END
GO

-- ============================================================
-- 2. CREAR BASE DE DATOS RRHH_DW
-- ============================================================
-- Tamaño mayor que el OLTP — el DWH crece con cada carga ETL
-- y acumula historial indefinidamente (SCD Tipo 2).
-- ============================================================

CREATE DATABASE RRHH_DW
ON PRIMARY
(
    NAME       = 'RRHH_DW_Data',
    FILENAME   = '/var/opt/mssql/data/RRHH_DW_Data.mdf',
    SIZE       = 200MB,
    MAXSIZE    = 2GB,
    FILEGROWTH = 50MB
)
LOG ON
(
    NAME       = 'RRHH_DW_Log',
    FILENAME   = '/var/opt/mssql/data/RRHH_DW_Log.ldf',
    SIZE       = 50MB,
    MAXSIZE    = 500MB,
    FILEGROWTH = 10MB
);
GO

PRINT '✓ Base de datos RRHH_DW creada';
GO

-- ============================================================
-- 3. CONFIGURAR BASE DE DATOS
-- ============================================================

USE RRHH_DW;
GO

-- READ_COMMITTED_SNAPSHOT: permite lecturas sin bloquear el ETL
ALTER DATABASE RRHH_DW SET RECOVERY SIMPLE;
ALTER DATABASE RRHH_DW SET COMPATIBILITY_LEVEL = 150;
ALTER DATABASE RRHH_DW SET READ_COMMITTED_SNAPSHOT ON;
GO

PRINT '✓ Configuración de RRHH_DW aplicada';
GO

-- ============================================================
-- 4. CREAR ESQUEMAS
-- ============================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dim')
    EXEC('CREATE SCHEMA dim');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'fact')
    EXEC('CREATE SCHEMA fact');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'ctrl')
    EXEC('CREATE SCHEMA ctrl');
GO

PRINT '✓ Esquemas dim, fact y ctrl creados';
GO

-- ============================================================
-- 5. TABLAS DE CONTROL ETL — esquema ctrl
-- ============================================================

-- ── 5a. Log de cargas ETL ────────────────────────────────────
-- Registra cada ejecución del proceso ETL:
-- cuándo corrió, qué cargó, si falló y por qué.
-- ============================================================

CREATE TABLE ctrl.LogCargaETL (
    LogID              INT           IDENTITY(1,1) PRIMARY KEY,
    NombreProceso      VARCHAR(200)  NOT NULL,
    TablaDestino       VARCHAR(200)  NOT NULL,
    TipoCarga          VARCHAR(20)   NOT NULL
                       CONSTRAINT CHK_TipoCarga
                       CHECK (TipoCarga IN ('FULL', 'INCREMENTAL')),
    FechaInicio        DATETIME      NOT NULL DEFAULT GETDATE(),
    FechaFin           DATETIME      NULL,
    RegistrosProcesados INT          NULL DEFAULT 0,
    RegistrosInsertados INT          NULL DEFAULT 0,
    RegistrosActualizados INT        NULL DEFAULT 0,
    RegistrosRechazados INT          NULL DEFAULT 0,
    Estado             VARCHAR(20)   NOT NULL DEFAULT 'En Proceso'
                       CONSTRAINT CHK_EstadoETL
                       CHECK (Estado IN ('En Proceso', 'Completado', 'Error')),
    MensajeError       VARCHAR(1000) NULL,
    UsuarioETL         VARCHAR(100)  NOT NULL DEFAULT SUSER_NAME()
);
GO

-- ── 5b. Configuración del proceso ETL ───────────────────────

CREATE TABLE ctrl.ConfiguracionETL (
    ConfigID           INT           IDENTITY(1,1) PRIMARY KEY,
    Parametro          VARCHAR(100)  NOT NULL UNIQUE,
    Valor              VARCHAR(500)  NOT NULL,
    Descripcion        VARCHAR(500)  NULL,
    FechaActualizacion DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

INSERT INTO ctrl.ConfiguracionETL (Parametro, Valor, Descripcion)
VALUES
('DB_Origen',              'RRHH',      'Base de datos OLTP origen'),
('Servidor_Origen',        'localhost',  'Servidor origen'),
('UltimaCargaCompleta',    '1900-01-01','Fecha de última carga FULL'),
('UltimaCargaIncremental', '1900-01-01','Fecha de última carga incremental'),
('TipoCarga',              'FULL',       'FULL o INCREMENTAL'),
('Version_DWH',            '1.0',        'Versión del modelo dimensional');
GO

PRINT '✓ Tablas de control ETL creadas';
GO

-- ============================================================
-- 6. DIMENSIÓN TIEMPO — dim.Dim_Tiempo
-- ============================================================
-- La dimensión más importante del DWH. Se genera con un
-- procedimiento ETL que crea un registro por CADA DÍA del
-- período de análisis (Script 06).
--
-- CONCEPTO CLAVE — ¿Por qué una dimensión tiempo?
-- En lugar de guardar fechas como DATE en las tablas de hechos
-- y calcular "¿en qué trimestre cayó esto?" cada vez que
-- consultas, precalculas TODOS los atributos de cada fecha
-- una sola vez aquí. Las consultas analíticas son 10x más
-- rápidas porque no calculan, solo filtran.
-- ============================================================

CREATE TABLE dim.Dim_Tiempo (
    TiempoID       INT          NOT NULL PRIMARY KEY,  -- formato YYYYMMDD: 20230115
    Fecha          DATE         NOT NULL UNIQUE,
    Anio           SMALLINT     NOT NULL,
    Semestre       TINYINT      NOT NULL,               -- 1 o 2
    Trimestre      TINYINT      NOT NULL,               -- 1 a 4
    Mes            TINYINT      NOT NULL,               -- 1 a 12
    NombreMes      VARCHAR(20)  NOT NULL,               -- 'Enero', 'Febrero'...
    Semana         TINYINT      NOT NULL,               -- 1 a 53
    DiaSemana      TINYINT      NOT NULL,               -- 1=Lunes, 7=Domingo
    NombreDia      VARCHAR(20)  NOT NULL,               -- 'Lunes', 'Martes'...
    EsFinDeSemana  BIT          NOT NULL DEFAULT 0,
    EsFestivoCOL   BIT          NOT NULL DEFAULT 0,    -- festivos Colombia
    AnioMes        CHAR(7)      NOT NULL,               -- '2023-01' para agrupar
    AnioTrimestre  CHAR(7)      NOT NULL                -- '2023-Q1'
);
GO

PRINT '✓ Tabla dim.Dim_Tiempo creada (se poblará en Script 06)';
GO

-- ============================================================
-- 7. DIMENSIÓN EMPLEADO — dim.Dim_Empleado
-- ============================================================
-- CONCEPTO CLAVE — SCD TIPO 2 (Slowly Changing Dimension):
--
-- Problema: Un empleado cambia de departamento en marzo 2024.
-- ¿Qué pasa con sus ausencias de 2023? ¿Las ausencias de 2023
-- deben mostrar el departamento VIEJO o el nuevo?
-- → Deben mostrar el departamento que tenía EN ESE MOMENTO.
--
-- Solución SCD Tipo 2: no actualizamos la fila, creamos una
-- nueva. La fila vieja queda con FechaFinVigencia = ayer y
-- EsVersionActual = 0. La nueva tiene EsVersionActual = 1.
--
-- Así puedes preguntar: "dame las ausencias de 2023 del depto
-- de Tecnología" y obtienes solo empleados que ESTABAN en
-- Tecnología en 2023, no los que están ahí hoy.
--
-- Columnas SCD Tipo 2:
--   SurrogateKey     → PK del DWH (no viene del OLTP)
--   EmpleadoID_OLTP  → FK al sistema origen (para el ETL)
--   FechaInicioVig   → desde cuándo aplica esta versión
--   FechaFinVig      → hasta cuándo aplica (NULL = vigente hoy)
--   EsVersionActual  → 1 = fila vigente, 0 = histórico
-- ============================================================

CREATE TABLE dim.Dim_Empleado (
    -- Clave surrogate del DWH (no usar EmpleadoID del OLTP como PK)
    EmpleadoSK          INT           IDENTITY(1,1) PRIMARY KEY,
    -- Referencia al sistema origen (para el ETL)
    EmpleadoID_OLTP     INT           NOT NULL,
    -- Datos personales
    Identificacion      VARCHAR(20)   NOT NULL,
    NombreCompleto      VARCHAR(200)  NOT NULL,
    Genero              VARCHAR(30)   NOT NULL,
    -- Datos organizacionales (estos cambian → activan SCD Tipo 2)
    Departamento        VARCHAR(100)  NOT NULL,
    NombrePuesto        VARCHAR(100)  NOT NULL,
    NivelSalarial       VARCHAR(20)   NOT NULL,
    NombreJefe          VARCHAR(200)  NOT NULL,
    CargoJefe           VARCHAR(100)  NOT NULL,
    NombreOficina       VARCHAR(100)  NOT NULL,
    PaisOficina         VARCHAR(100)  NOT NULL,
    -- Datos laborales calculados
    AniosAntiguedad     DECIMAL(4,1)  NULL,
    -- Control SCD Tipo 2
    FechaInicioVig      DATE          NOT NULL,
    FechaFinVig         DATE          NULL,        -- NULL = versión activa
    EsVersionActual     BIT           NOT NULL DEFAULT 1,
    FechaCargaETL       DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- Índice para el ETL: buscar versión actual por EmpleadoID
CREATE INDEX IX_DimEmpleado_OLTP_Actual
    ON dim.Dim_Empleado(EmpleadoID_OLTP, EsVersionActual);
GO

PRINT '✓ Tabla dim.Dim_Empleado creada (SCD Tipo 2)';
GO

-- ============================================================
-- 8. DIMENSIÓN DEPARTAMENTO — dim.Dim_Departamento
-- ============================================================
-- SCD Tipo 2: si un departamento cambia de oficina o de nombre
-- el historial queda intacto para análisis retrospectivos.
-- ============================================================

CREATE TABLE dim.Dim_Departamento (
    DepartamentoSK      INT           IDENTITY(1,1) PRIMARY KEY,
    DepartamentoID_OLTP INT           NOT NULL,
    NombreDepartamento  VARCHAR(100)  NOT NULL,
    Descripcion         VARCHAR(500)  NULL,
    CiudadOficina       VARCHAR(100)  NOT NULL,
    PaisOficina         VARCHAR(100)  NOT NULL,
    -- Control SCD Tipo 2
    FechaInicioVig      DATE          NOT NULL,
    FechaFinVig         DATE          NULL,
    EsVersionActual     BIT           NOT NULL DEFAULT 1,
    FechaCargaETL       DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

CREATE INDEX IX_DimDepto_OLTP_Actual
    ON dim.Dim_Departamento(DepartamentoID_OLTP, EsVersionActual);
GO

PRINT '✓ Tabla dim.Dim_Departamento creada (SCD Tipo 2)';
GO

-- ============================================================
-- 9. DIMENSIÓN PUESTO — dim.Dim_Puesto
-- ============================================================
-- SCD Tipo 2: si cambian las bandas salariales de un puesto
-- el historial de evaluaciones y hechos queda coherente.
-- ============================================================

CREATE TABLE dim.Dim_Puesto (
    PuestoSK            INT           IDENTITY(1,1) PRIMARY KEY,
    PuestoID_OLTP       INT           NOT NULL,
    NombrePuesto        VARCHAR(100)  NOT NULL,
    NivelSalarial       VARCHAR(20)   NOT NULL,
    SalarioMinUSD       DECIMAL(10,2) NOT NULL,
    SalarioMaxUSD       DECIMAL(10,2) NOT NULL,
    RangoSalarial       VARCHAR(50)   NOT NULL, -- 'USD 1,200 - 2,500'
    -- Control SCD Tipo 2
    FechaInicioVig      DATE          NOT NULL,
    FechaFinVig         DATE          NULL,
    EsVersionActual     BIT           NOT NULL DEFAULT 1,
    FechaCargaETL       DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

CREATE INDEX IX_DimPuesto_OLTP_Actual
    ON dim.Dim_Puesto(PuestoID_OLTP, EsVersionActual);
GO

PRINT '✓ Tabla dim.Dim_Puesto creada (SCD Tipo 2)';
GO

-- ============================================================
-- 10. DIMENSIÓN CAPACITACIÓN — dim.Dim_Capacitacion
-- ============================================================
-- SCD Tipo 2: si una capacitación cambia de proveedor o costo
-- los registros históricos de asignaciones quedan coherentes.
-- ============================================================

CREATE TABLE dim.Dim_Capacitacion (
    CapacitacionSK      INT           IDENTITY(1,1) PRIMARY KEY,
    CapacitacionID_OLTP INT           NOT NULL,
    NombreCapacitacion  VARCHAR(200)  NOT NULL,
    Proveedor           VARCHAR(200)  NOT NULL,
    CostoUSD            DECIMAL(10,2) NOT NULL,
    DuracionDias        INT           NOT NULL,
    -- Control SCD Tipo 2
    FechaInicioVig      DATE          NOT NULL,
    FechaFinVig         DATE          NULL,
    EsVersionActual     BIT           NOT NULL DEFAULT 1,
    FechaCargaETL       DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

CREATE INDEX IX_DimCapacitacion_OLTP_Actual
    ON dim.Dim_Capacitacion(CapacitacionID_OLTP, EsVersionActual);
GO

PRINT '✓ Tabla dim.Dim_Capacitacion creada (SCD Tipo 2)';
GO

-- ============================================================
-- 11. DIMENSIÓN TIPO AUSENCIA — dim.Dim_TipoAusencia
-- ============================================================
-- Dimensión pequeña y estática — los tipos de ausencia
-- raramente cambian, pero la mantenemos como dimensión
-- para poder filtrar y agrupar fácilmente en consultas.
-- No necesita SCD Tipo 2 — se pobla directamente aquí.
-- ============================================================

CREATE TABLE dim.Dim_TipoAusencia (
    TipoAusenciaSK   INT          IDENTITY(1,1) PRIMARY KEY,
    TipoAusencia     VARCHAR(50)  NOT NULL UNIQUE,
    Categoria        VARCHAR(50)  NOT NULL, -- 'Planificada' o 'No Planificada'
    AfectaProductividad BIT       NOT NULL DEFAULT 1,
    FechaCargaETL    DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

-- Poblar directamente — dimensión estática
INSERT INTO dim.Dim_TipoAusencia (TipoAusencia, Categoria, AfectaProductividad)
VALUES
('Vacaciones',       'Planificada',     0),  -- No afecta: es derecho laboral
('Enfermedad',       'No Planificada',  1),
('Permiso Personal', 'Planificada',     1),
('Licencia Médica',  'No Planificada',  1);
GO

PRINT '✓ Tabla dim.Dim_TipoAusencia creada y poblada';
GO

-- ============================================================
-- 12. TABLA DE HECHOS: AUSENCIAS — fact.Fact_Ausencias
-- ============================================================
-- GRANULARIDAD: una fila = una ausencia de un empleado.
-- Métricas: días de ausencia, si está justificada.
-- Dimensiones: empleado, departamento, tiempo (inicio y fin),
--              tipo de ausencia.
--
-- NOTA TÉCNICA — role-playing dimension en tiempo:
-- Usamos DOS FKs a Dim_Tiempo: FechaInicioID y FechaFinID.
-- La misma dimensión juega dos roles distintos.
-- Esto es más eficiente que crear dos tablas de tiempo.
-- ============================================================

CREATE TABLE fact.Fact_Ausencias (
    AusenciaSK          INT           IDENTITY(1,1) PRIMARY KEY,
    -- Claves foráneas a dimensiones (surrogate keys del DWH)
    EmpleadoSK          INT           NOT NULL,
    DepartamentoSK      INT           NOT NULL,
    TipoAusenciaSK      INT           NOT NULL,
    FechaInicioID       INT           NOT NULL,  -- FK a Dim_Tiempo
    FechaFinID          INT           NOT NULL,  -- FK a Dim_Tiempo (role-playing)
    -- Referencia al sistema origen
    AusenciaID_OLTP     INT           NOT NULL,
    -- Métricas
    DiasTotales         INT           NOT NULL,
    EsJustificada       BIT           NOT NULL,
    -- Control ETL
    FechaCargaETL       DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_FactAus_Empleado
        FOREIGN KEY (EmpleadoSK)     REFERENCES dim.Dim_Empleado(EmpleadoSK),
    CONSTRAINT FK_FactAus_Depto
        FOREIGN KEY (DepartamentoSK) REFERENCES dim.Dim_Departamento(DepartamentoSK),
    CONSTRAINT FK_FactAus_TipoAus
        FOREIGN KEY (TipoAusenciaSK) REFERENCES dim.Dim_TipoAusencia(TipoAusenciaSK),
    CONSTRAINT FK_FactAus_FechaInicio
        FOREIGN KEY (FechaInicioID)  REFERENCES dim.Dim_Tiempo(TiempoID),
    CONSTRAINT FK_FactAus_FechaFin
        FOREIGN KEY (FechaFinID)     REFERENCES dim.Dim_Tiempo(TiempoID)
);
GO

CREATE INDEX IX_FactAus_Empleado   ON fact.Fact_Ausencias(EmpleadoSK);
CREATE INDEX IX_FactAus_Depto      ON fact.Fact_Ausencias(DepartamentoSK);
CREATE INDEX IX_FactAus_FechaIn    ON fact.Fact_Ausencias(FechaInicioID);
GO

PRINT '✓ Tabla fact.Fact_Ausencias creada';
GO

-- ============================================================
-- 13. TABLA DE HECHOS: EVALUACIONES — fact.Fact_Evaluaciones
-- ============================================================
-- GRANULARIDAD: una fila = una evaluación de un empleado.
-- Métricas: calificación obtenida.
-- Dimensiones: empleado evaluado, empleado evaluador
--              (role-playing), departamento, tiempo.
--
-- NOTA TÉCNICA — dos FKs a Dim_Empleado:
-- EmpleadoEvaluadoSK  → quien recibe la evaluación
-- EmpleadorSK         → quien la aplica
-- Ambas apuntan a la misma dimensión en roles distintos.
-- ============================================================

CREATE TABLE fact.Fact_Evaluaciones (
    EvaluacionSK          INT           IDENTITY(1,1) PRIMARY KEY,
    -- Role-playing en Dim_Empleado
    EmpleadoEvaluadoSK    INT           NOT NULL,
    EvaluadorSK           INT           NOT NULL,
    DepartamentoSK        INT           NOT NULL,
    PuestoSK              INT           NOT NULL,
    FechaEvaluacionID     INT           NOT NULL,
    -- Referencia origen
    EvaluacionID_OLTP     INT           NOT NULL,
    -- Métricas
    Calificacion          DECIMAL(3,1)  NOT NULL,
    Periodo               VARCHAR(20)   NOT NULL,
    -- Control ETL
    FechaCargaETL         DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_FactEval_Evaluado
        FOREIGN KEY (EmpleadoEvaluadoSK) REFERENCES dim.Dim_Empleado(EmpleadoSK),
    CONSTRAINT FK_FactEval_Evaluador
        FOREIGN KEY (EvaluadorSK)        REFERENCES dim.Dim_Empleado(EmpleadoSK),
    CONSTRAINT FK_FactEval_Depto
        FOREIGN KEY (DepartamentoSK)     REFERENCES dim.Dim_Departamento(DepartamentoSK),
    CONSTRAINT FK_FactEval_Puesto
        FOREIGN KEY (PuestoSK)           REFERENCES dim.Dim_Puesto(PuestoSK),
    CONSTRAINT FK_FactEval_Fecha
        FOREIGN KEY (FechaEvaluacionID)  REFERENCES dim.Dim_Tiempo(TiempoID)
);
GO

CREATE INDEX IX_FactEval_Evaluado  ON fact.Fact_Evaluaciones(EmpleadoEvaluadoSK);
CREATE INDEX IX_FactEval_Depto     ON fact.Fact_Evaluaciones(DepartamentoSK);
CREATE INDEX IX_FactEval_Fecha     ON fact.Fact_Evaluaciones(FechaEvaluacionID);
GO

PRINT '✓ Tabla fact.Fact_Evaluaciones creada';
GO

-- ============================================================
-- 14. TABLA DE HECHOS: CAPACITACIONES — fact.Fact_Capacitaciones
-- ============================================================
-- GRANULARIDAD: una fila = un empleado en una capacitación.
-- Métricas: calificación obtenida, costo de la capacitación,
--           días de duración.
-- ============================================================

CREATE TABLE fact.Fact_Capacitaciones (
    CapacitacionSK_Fact   INT           IDENTITY(1,1) PRIMARY KEY,
    EmpleadoSK            INT           NOT NULL,
    CapacitacionSK        INT           NOT NULL,
    DepartamentoSK        INT           NOT NULL,
    FechaCompletadoID     INT           NULL,       -- NULL si está En Curso
    -- Referencia origen
    AsignacionID_OLTP     INT           NOT NULL,
    -- Métricas
    CalificacionObtenida  DECIMAL(5,2)  NULL,
    CostoUSD              DECIMAL(10,2) NOT NULL,
    DuracionDias          INT           NOT NULL,
    Estado                VARCHAR(20)   NOT NULL,
    -- Control ETL
    FechaCargaETL         DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_FactCap_Empleado
        FOREIGN KEY (EmpleadoSK)      REFERENCES dim.Dim_Empleado(EmpleadoSK),
    CONSTRAINT FK_FactCap_Capacitacion
        FOREIGN KEY (CapacitacionSK)  REFERENCES dim.Dim_Capacitacion(CapacitacionSK),
    CONSTRAINT FK_FactCap_Depto
        FOREIGN KEY (DepartamentoSK)  REFERENCES dim.Dim_Departamento(DepartamentoSK),
    CONSTRAINT FK_FactCap_Fecha
        FOREIGN KEY (FechaCompletadoID) REFERENCES dim.Dim_Tiempo(TiempoID)
);
GO

CREATE INDEX IX_FactCap_Empleado   ON fact.Fact_Capacitaciones(EmpleadoSK);
CREATE INDEX IX_FactCap_Depto      ON fact.Fact_Capacitaciones(DepartamentoSK);
GO

PRINT '✓ Tabla fact.Fact_Capacitaciones creada';
GO

-- ============================================================
-- 15. TABLA DE HECHOS: HEADCOUNT — fact.Fact_Headcount
-- ============================================================
-- GRANULARIDAD: una fila = un empleado activo en un mes dado.
-- Esta es una tabla de hechos SNAPSHOT — fotografía mensual
-- del estado de la plantilla de TalentCorp.
--
-- ¿Para qué sirve? Para responder:
--   "¿Cuántos empleados teníamos en Tecnología en marzo 2023?"
--   "¿Cómo ha evolucionado el headcount por departamento?"
-- Sin esta tabla tendrías que reconstruir el estado histórico
-- a partir de fechas de contratación y desvinculación,
-- lo cual es costoso y propenso a errores.
--
-- Métricas: salario del empleado ese mes (snapshot del valor
-- vigente), antigüedad en meses.
-- ============================================================

CREATE TABLE fact.Fact_Headcount (
    HeadcountSK         INT           IDENTITY(1,1) PRIMARY KEY,
    EmpleadoSK          INT           NOT NULL,
    DepartamentoSK      INT           NOT NULL,
    PuestoSK            INT           NOT NULL,
    FechaSnapshotID     INT           NOT NULL,   -- primer día del mes
    -- Referencia origen
    EmpleadoID_OLTP     INT           NOT NULL,
    -- Métricas del snapshot
    SalarioMesUSD       DECIMAL(10,2) NOT NULL,
    AntiguedadMeses     INT           NOT NULL,
    EsActivo            BIT           NOT NULL DEFAULT 1,
    -- Control ETL
    FechaCargaETL       DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_FactHC_Empleado
        FOREIGN KEY (EmpleadoSK)      REFERENCES dim.Dim_Empleado(EmpleadoSK),
    CONSTRAINT FK_FactHC_Depto
        FOREIGN KEY (DepartamentoSK)  REFERENCES dim.Dim_Departamento(DepartamentoSK),
    CONSTRAINT FK_FactHC_Puesto
        FOREIGN KEY (PuestoSK)        REFERENCES dim.Dim_Puesto(PuestoSK),
    CONSTRAINT FK_FactHC_Fecha
        FOREIGN KEY (FechaSnapshotID) REFERENCES dim.Dim_Tiempo(TiempoID),

    -- Un empleado solo puede tener un snapshot por mes
    CONSTRAINT UQ_Headcount_EmpleadoMes
        UNIQUE (EmpleadoSK, FechaSnapshotID)
);
GO

CREATE INDEX IX_FactHC_Depto    ON fact.Fact_Headcount(DepartamentoSK);
CREATE INDEX IX_FactHC_Fecha    ON fact.Fact_Headcount(FechaSnapshotID);
GO

PRINT '✓ Tabla fact.Fact_Headcount creada';
GO

-- ============================================================
-- 16. ROLES DE SEGURIDAD DEL DWH
-- ============================================================
-- Seguridad más estricta que el OLTP porque los patrones
-- agregados son más peligrosos que datos individuales.
--
-- DWH_Viewer  → lectura de dimensiones y hechos (solo su depto)
-- DWH_Analyst → lectura total del DWH (todos los deptos)
-- DWH_ETL     → escritura — solo para procesos ETL
-- DWH_Admin   → control total
-- ============================================================

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'DWH_Viewer')
    CREATE ROLE DWH_Viewer;
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'DWH_Analyst')
    CREATE ROLE DWH_Analyst;
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'DWH_ETL')
    CREATE ROLE DWH_ETL;
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'DWH_Admin')
    CREATE ROLE DWH_Admin;
GO

-- DWH_Viewer: solo lectura en dim y fact (RLS filtra por depto)
GRANT SELECT ON SCHEMA::dim  TO DWH_Viewer;
GRANT SELECT ON SCHEMA::fact TO DWH_Viewer;

-- DWH_Analyst: lectura total sin restricción por departamento
GRANT SELECT ON SCHEMA::dim  TO DWH_Analyst;
GRANT SELECT ON SCHEMA::fact TO DWH_Analyst;
GRANT SELECT ON SCHEMA::ctrl TO DWH_Analyst;

-- DWH_ETL: escritura para los procesos de carga
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dim  TO DWH_ETL;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::fact TO DWH_ETL;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::ctrl TO DWH_ETL;

-- DWH_Admin: control total
GRANT CONTROL ON SCHEMA::dim  TO DWH_Admin;
GRANT CONTROL ON SCHEMA::fact TO DWH_Admin;
GRANT CONTROL ON SCHEMA::ctrl TO DWH_Admin;
GO

PRINT '✓ Roles DWH_Viewer, DWH_Analyst, DWH_ETL, DWH_Admin creados';
GO

-- ============================================================
-- 17. ROW-LEVEL SECURITY — DWH_Viewer ve solo su departamento
-- ============================================================
-- Función que evalúa si el usuario actual puede ver una fila.
-- El predicado se aplica automáticamente a cada SELECT —
-- el analista no necesita escribir WHERE, SQL lo hace solo.
-- ============================================================

-- Función de predicado de seguridad
CREATE FUNCTION ctrl.fn_RLS_Departamento
    (@Departamento VARCHAR(100))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS RLS_Result
    WHERE
        -- DWH_Admin y DWH_Analyst ven todo
        IS_ROLEMEMBER('DWH_Admin')   = 1
        OR IS_ROLEMEMBER('DWH_Analyst') = 1
        OR IS_ROLEMEMBER('DWH_ETL')  = 1
        -- dbo (propietario de la BD) ejecuta el ETL: si la política lo
        -- filtrara, el SCD Tipo 2 no vería las versiones vigentes y las
        -- duplicaría. No se puede agregar dbo a un rol (error 15405).
        OR USER_NAME() = 'dbo'
        -- DWH_Viewer solo ve su departamento (nombre = login del usuario)
        OR @Departamento = USER_NAME();
GO

-- Aplicar política RLS a Dim_Empleado
CREATE SECURITY POLICY ctrl.RLS_Empleados
    ADD FILTER PREDICATE ctrl.fn_RLS_Departamento(Departamento)
    ON dim.Dim_Empleado
    WITH (STATE = ON);
GO

PRINT '✓ Row-Level Security aplicado a dim.Dim_Empleado';
GO

-- ============================================================
-- 18. VERIFICACIÓN FINAL
-- ============================================================

SELECT
    s.name                                    AS Esquema,
    t.name                                    AS Tabla,
    COUNT(c.column_id)                        AS NumColumnas,
    t.create_date                             AS FechaCreacion
FROM sys.tables  t
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.columns c ON t.object_id = c.object_id
WHERE s.name IN ('dim', 'fact', 'ctrl')
GROUP BY s.name, t.name, t.create_date
ORDER BY s.name, t.name;
GO

PRINT '';
PRINT '============================================================';
PRINT '✅ SCRIPT 03 COMPLETADO — RRHH_DW';
PRINT '';
PRINT '  Esquema dim  → 6 dimensiones (5 SCD Tipo 2 + 1 estática)';
PRINT '  Esquema fact → 4 tablas de hechos';
PRINT '  Esquema ctrl → log ETL + configuración';
PRINT '  Seguridad    → 4 roles + Row-Level Security';
PRINT '';
PRINT '  Siguiente paso: Ejecutar 04_Crear_Dimensiones.sql';
PRINT '============================================================';
GO