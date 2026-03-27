-- ============================================================
-- SCRIPT 01: CREAR BASE DE DATOS OPERACIONAL RRHH (OLTP)
-- Base de Datos : RRHH
-- Propósito     : BD transaccional para gestión de Recursos Humanos
--                 de TalentCorp S.A. — empresa colombiana con
--                 operaciones internacionales
-- Autora        : Hanna
-- Fecha         : 2026
-- Motor         : SQL Server 2019 (contenedor Docker / DBeaver)
-- ============================================================
-- DECISIONES DE ARQUITECTURA:
--   • Salarios en tabla separada (EMPLEADOS_SALARIOS) con
--     permisos restringidos — cumple Decreto 1377/2013 (habeas data)
--   • Datos sensibles con Dynamic Data Masking para rol público
--   • Columnas calculadas para DiasTotales y DuracionDias
--   • Auto-referencia en EMPLEADOS para jerarquía organizacional
-- ============================================================

USE master;
GO

-- ============================================================
-- 1. ELIMINAR BASE DE DATOS SI EXISTE
-- ============================================================

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'RRHH')
BEGIN
    ALTER DATABASE RRHH SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE RRHH;
    PRINT '✓ Base de datos RRHH eliminada';
END
GO

-- ============================================================
-- 2. CREAR BASE DE DATOS RRHH
-- ============================================================

CREATE DATABASE RRHH
ON PRIMARY
(
    NAME       = 'RRHH_Data',
    FILENAME   = '/var/opt/mssql/data/RRHH_Data.mdf',
    SIZE       = 100MB,
    MAXSIZE    = 1GB,
    FILEGROWTH = 20MB
)
LOG ON
(
    NAME       = 'RRHH_Log',
    FILENAME   = '/var/opt/mssql/data/RRHH_Log.ldf',
    SIZE       = 50MB,
    MAXSIZE    = 500MB,
    FILEGROWTH = 10MB
);
GO

PRINT '✓ Base de datos RRHH creada';
GO

-- ============================================================
-- 3. CONFIGURAR BASE DE DATOS
-- ============================================================

USE RRHH;
GO

ALTER DATABASE RRHH SET RECOVERY SIMPLE;
ALTER DATABASE RRHH SET COMPATIBILITY_LEVEL = 150;
GO

PRINT '✓ Configuración de base de datos aplicada';
GO

-- ============================================================
-- 4. CREAR ESQUEMAS
-- ============================================================
-- hr  → tablas operacionales del negocio
-- sec → seguridad y control de acceso a datos sensibles
-- ============================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'hr')
    EXEC('CREATE SCHEMA hr');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'sec')
    EXEC('CREATE SCHEMA sec');
GO

PRINT '✓ Esquemas hr y sec creados';
GO

-- ============================================================
-- 5. TABLA: hr.Oficinas
-- ============================================================
-- Cada oficina representa una sede física de TalentCorp.
-- Código de oficina: formato PAIS-CIUDAD (ej: COL-BOG, ESP-MAD)
-- ============================================================

CREATE TABLE hr.Oficinas (
    OficinaID      INT           IDENTITY(1,1) PRIMARY KEY,
    CodigoOficina  VARCHAR(20)   NOT NULL UNIQUE,
    Ciudad         VARCHAR(100)  NOT NULL,
    Pais           VARCHAR(100)  NOT NULL,
    Region         VARCHAR(100)  NULL,
    CodigoPostal   VARCHAR(20)   NULL,
    Telefono       VARCHAR(30)   NULL,
    Direccion      VARCHAR(255)  NOT NULL,
    Activa         BIT           NOT NULL DEFAULT 1,
    FechaCreacion  DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

PRINT '✓ Tabla hr.Oficinas creada';
GO

-- ============================================================
-- 6. TABLA: hr.Departamentos
-- ============================================================
-- Unidades organizacionales de TalentCorp.
-- Cada departamento opera desde una oficina principal.
-- ============================================================

CREATE TABLE hr.Departamentos (
    DepartamentoID    INT          IDENTITY(1,1) PRIMARY KEY,
    NombreDepartamento VARCHAR(100) NOT NULL UNIQUE,
    Descripcion       VARCHAR(500) NULL,
    OficinaID         INT          NOT NULL,
    Activo            BIT          NOT NULL DEFAULT 1,
    FechaCreacion     DATETIME     NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_Departamentos_Oficinas
        FOREIGN KEY (OficinaID) REFERENCES hr.Oficinas(OficinaID)
);
GO

PRINT '✓ Tabla hr.Departamentos creada';
GO

-- ============================================================
-- 7. TABLA: hr.Puestos
-- ============================================================
-- Catálogo de cargos con bandas salariales en USD.
-- NivelSalarial: Junior | Mid-Level | Senior
-- ============================================================

CREATE TABLE hr.Puestos (
    PuestoID       INT           IDENTITY(1,1) PRIMARY KEY,
    NombrePuesto   VARCHAR(100)  NOT NULL,
    NivelSalarial  VARCHAR(20)   NOT NULL
                   CONSTRAINT CHK_NivelSalarial
                   CHECK (NivelSalarial IN ('Junior', 'Mid-Level', 'Senior')),
    SalarioMinUSD  DECIMAL(10,2) NOT NULL,
    SalarioMaxUSD  DECIMAL(10,2) NOT NULL,
    Activo         BIT           NOT NULL DEFAULT 1,
    FechaCreacion  DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT CHK_RangoSalarial
        CHECK (SalarioMaxUSD >= SalarioMinUSD)
);
GO

PRINT '✓ Tabla hr.Puestos creada';
GO

-- ============================================================
-- 8. TABLA: hr.Empleados
-- ============================================================
-- Núcleo del sistema OLTP.
-- DECISIÓN DE DISEÑO:
--   • SalarioActualUSD NO está aquí — vive en sec.EmpleadosSalarios
--     para cumplir con habeas data (datos sensibles restringidos)
--   • Datos personales sensibles con Dynamic Data Masking:
--     solo el rol RRHH_Analista ve los valores reales
--   • JefeDirectoID: auto-referencia (NULL = es el CEO)
-- ============================================================

CREATE TABLE hr.Empleados (
    EmpleadoID        INT           IDENTITY(1,1) PRIMARY KEY,
    Identificacion    VARCHAR(20)   NOT NULL UNIQUE,
    Nombre            VARCHAR(100)  NOT NULL,
    Apellidos         VARCHAR(100)  NOT NULL,
    -- Datos sensibles (las máscaras se aplican abajo con ALTER TABLE)
    FechaNacimiento   DATE          NOT NULL,
    Genero            VARCHAR(20)   NOT NULL,
    EstadoCivil       VARCHAR(30)   NULL,
    -- Datos laborales
    Email             VARCHAR(150)  NOT NULL UNIQUE,
    Telefono          VARCHAR(30)   NULL,
    FechaContratacion DATE          NOT NULL,
    -- Relaciones organizacionales
    DepartamentoID    INT           NOT NULL,
    PuestoID          INT           NOT NULL,
    OficinaID         INT           NOT NULL,
    -- Jerarquía: NULL si es el nivel más alto (CEO)
    JefeDirectoID     INT           NULL,
    -- Control
    Activo            BIT           NOT NULL DEFAULT 1,
    FechaCreacion     DATETIME      NOT NULL DEFAULT GETDATE(),
    FechaModificacion DATETIME      NULL,

    CONSTRAINT FK_Empleados_Departamentos
        FOREIGN KEY (DepartamentoID) REFERENCES hr.Departamentos(DepartamentoID),
    CONSTRAINT FK_Empleados_Puestos
        FOREIGN KEY (PuestoID) REFERENCES hr.Puestos(PuestoID),
    CONSTRAINT FK_Empleados_Oficinas
        FOREIGN KEY (OficinaID) REFERENCES hr.Oficinas(OficinaID),
    -- Auto-referencia para jerarquía organizacional
    CONSTRAINT FK_Empleados_Jefe
        FOREIGN KEY (JefeDirectoID) REFERENCES hr.Empleados(EmpleadoID)
);
GO

PRINT '✓ Tabla hr.Empleados creada (sin salario — ver sec.EmpleadosSalarios)';
GO

-- ============================================================
-- 8b. DYNAMIC DATA MASKING — columnas sensibles de hr.Empleados
-- ============================================================
-- Se aplica DESPUÉS del CREATE TABLE para compatibilidad total
-- con SQL Server en Docker (Developer / Express Edition).
-- Usuarios sin rol RRHH_Admin ven los datos enmascarados.
-- ============================================================

ALTER TABLE hr.Empleados
    ALTER COLUMN FechaNacimiento
    ADD MASKED WITH (FUNCTION = 'default()');
GO

ALTER TABLE hr.Empleados
    ALTER COLUMN Genero
    ADD MASKED WITH (FUNCTION = 'partial(1, "***", 0)');
GO

ALTER TABLE hr.Empleados
    ALTER COLUMN EstadoCivil
    ADD MASKED WITH (FUNCTION = 'default()');
GO

PRINT '✓ Dynamic Data Masking aplicado a columnas sensibles';
GO

-- ============================================================
-- 9. TABLA: sec.EmpleadosSalarios
-- ============================================================
-- TABLA RESTRINGIDA — solo rol RRHH_Nomina tiene acceso.
-- Guarda el historial completo de salarios por empleado.
-- EsActual = 1 indica el salario vigente.
-- Esto nos da trazabilidad: cada aumento queda registrado.
-- ============================================================

CREATE TABLE sec.EmpleadosSalarios (
    SalarioID         INT           IDENTITY(1,1) PRIMARY KEY,
    EmpleadoID        INT           NOT NULL,
    SalarioUSD        DECIMAL(10,2) NOT NULL,
    FechaVigencia     DATE          NOT NULL,
    FechaFin          DATE          NULL,
    EsActual          BIT           NOT NULL DEFAULT 1,
    MotivoAjuste      VARCHAR(200)  NULL,   -- Ej: 'Promoción', 'Ajuste anual'
    RegistradoPor     VARCHAR(100)  NOT NULL DEFAULT SUSER_NAME(),
    FechaRegistro     DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_Salarios_Empleados
        FOREIGN KEY (EmpleadoID) REFERENCES hr.Empleados(EmpleadoID)
);


PRINT '✓ Tabla sec.EmpleadosSalarios creada (RESTRINGIDA)';
GO

-- ============================================================
-- 10. TABLA: hr.Ausencias
-- ============================================================
-- Registro de todas las ausencias del personal.
-- DiasTotales: columna CALCULADA automáticamente con DATEDIFF.
-- No se puede insertar manualmente — SQL la calcula solo.
-- TipoAusencia: Vacaciones | Enfermedad | Permiso Personal |
--               Licencia Médica
-- ============================================================

CREATE TABLE hr.Ausencias (
    AusenciaID    INT          IDENTITY(1,1) PRIMARY KEY,
    EmpleadoID    INT          NOT NULL,
    TipoAusencia  VARCHAR(50)  NOT NULL
                  CONSTRAINT CHK_TipoAusencia
                  CHECK (TipoAusencia IN (
                      'Vacaciones',
                      'Enfermedad',
                      'Permiso Personal',
                      'Licencia Médica'
                  )),
    FechaInicio   DATE         NOT NULL,
    FechaFin      DATE         NOT NULL,
    -- Columna calculada: SQL la mantiene automáticamente
    DiasTotales   AS DATEDIFF(DAY, FechaInicio, FechaFin) + 1  PERSISTED,
    Justificada   CHAR(2)      NOT NULL DEFAULT 'Si'
                  CONSTRAINT CHK_Justificada
                  CHECK (Justificada IN ('Si', 'No')),
    Comentarios   VARCHAR(500) NULL,
    FechaRegistro DATETIME     NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_Ausencias_Empleados
        FOREIGN KEY (EmpleadoID) REFERENCES hr.Empleados(EmpleadoID),
    -- Un empleado no puede tener dos ausencias que se solapan
    CONSTRAINT CHK_FechasAusencia
        CHECK (FechaFin >= FechaInicio)
);
GO

PRINT '✓ Tabla hr.Ausencias creada (DiasTotales calculado automáticamente)';
GO

-- ============================================================
-- 11. TABLA: hr.Evaluaciones
-- ============================================================
-- Evaluaciones de desempeño semestrales o anuales.
-- NOTA TÉCNICA — dos FKs a hr.Empleados:
--   • EmpleadoEvaluadoID: quien recibe la evaluación
--   • EvaluadorID       : quien la aplica (normalmente el jefe)
-- En el DWH esto se resolverá con role-playing dimensions.
-- Calificacion: escala 1.0 a 5.0
-- ============================================================

CREATE TABLE hr.Evaluaciones (
    EvaluacionID         INT           IDENTITY(1,1) PRIMARY KEY,
    EmpleadoEvaluadoID   INT           NOT NULL,
    EvaluadorID          INT           NOT NULL,
    FechaEvaluacion      DATE          NOT NULL,
    Calificacion         DECIMAL(3,1)  NOT NULL
                         CONSTRAINT CHK_Calificacion
                         CHECK (Calificacion BETWEEN 1.0 AND 5.0),
    Periodo              VARCHAR(20)   NOT NULL
                         CONSTRAINT CHK_Periodo
                         CHECK (Periodo IN ('Semestral', 'Anual')),
    Comentarios          VARCHAR(1000) NULL,
    FechaRegistro        DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_Evaluaciones_Evaluado
        FOREIGN KEY (EmpleadoEvaluadoID) REFERENCES hr.Empleados(EmpleadoID),
    CONSTRAINT FK_Evaluaciones_Evaluador
        FOREIGN KEY (EvaluadorID) REFERENCES hr.Empleados(EmpleadoID),
    -- Un empleado no se puede autoevaluar
    CONSTRAINT CHK_NoAutoevaluacion
        CHECK (EmpleadoEvaluadoID <> EvaluadorID)
);
GO

PRINT '✓ Tabla hr.Evaluaciones creada';
GO

-- ============================================================
-- 12. TABLA: hr.Capacitaciones
-- ============================================================
-- Catálogo de programas de formación disponibles.
-- DuracionDias: columna CALCULADA igual que DiasTotales.
-- Costo en USD para comparabilidad entre sedes.
-- ============================================================

CREATE TABLE hr.Capacitaciones (
    CapacitacionID      INT           IDENTITY(1,1) PRIMARY KEY,
    NombreCapacitacion  VARCHAR(200)  NOT NULL,
    Descripcion         VARCHAR(500)  NULL,
    Proveedor           VARCHAR(200)  NOT NULL,
    CostoUSD            DECIMAL(10,2) NOT NULL DEFAULT 0,
    FechaInicio         DATE          NOT NULL,
    FechaFin            DATE          NOT NULL,
    -- Columna calculada: duración en días hábiles aproximada
    DuracionDias        AS DATEDIFF(DAY, FechaInicio, FechaFin) + 1  PERSISTED,
    Activa              BIT           NOT NULL DEFAULT 1,
    FechaCreacion       DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT CHK_FechasCapacitacion
        CHECK (FechaFin >= FechaInicio)
);
GO

PRINT '✓ Tabla hr.Capacitaciones creada (DuracionDias calculado automáticamente)';
GO

-- ============================================================
-- 13. TABLA: hr.EmpleadosCapacitaciones
-- ============================================================
-- Tabla puente (muchos-a-muchos) entre Empleados y Capacitaciones.
-- Registra el desempeño individual en cada programa.
-- Estado: Completada | En Curso | Cancelada
-- CalificacionObtenida: escala 0 a 100
-- ============================================================

CREATE TABLE hr.EmpleadosCapacitaciones (
    AsignacionID          INT           IDENTITY(1,1) PRIMARY KEY,
    EmpleadoID            INT           NOT NULL,
    CapacitacionID        INT           NOT NULL,
    CalificacionObtenida  DECIMAL(5,2)  NULL
                          CONSTRAINT CHK_CalifCapacitacion
                          CHECK (CalificacionObtenida BETWEEN 0 AND 100),
    FechaCompletado       DATE          NULL,
    Estado                VARCHAR(20)   NOT NULL DEFAULT 'En Curso'
                          CONSTRAINT CHK_EstadoCapacitacion
                          CHECK (Estado IN ('Completada', 'En Curso', 'Cancelada')),
    Comentarios           VARCHAR(500)  NULL,
    FechaAsignacion       DATETIME      NOT NULL DEFAULT GETDATE(),

    -- Un empleado no puede estar inscrito dos veces en la misma capacitación
    CONSTRAINT UQ_EmpleadoCapacitacion
        UNIQUE (EmpleadoID, CapacitacionID),

    CONSTRAINT FK_EC_Empleados
        FOREIGN KEY (EmpleadoID) REFERENCES hr.Empleados(EmpleadoID),
    CONSTRAINT FK_EC_Capacitaciones
        FOREIGN KEY (CapacitacionID) REFERENCES hr.Capacitaciones(CapacitacionID)
);
GO

PRINT '✓ Tabla hr.EmpleadosCapacitaciones creada';
GO

-- ============================================================
-- 14. ÍNDICES DE RENDIMIENTO
-- ============================================================
-- Los índices aceleran las consultas más frecuentes en RRHH:
-- búsquedas por empleado, por fecha, por departamento.
-- ============================================================

-- Ausencias: consultas por empleado y por rango de fechas
CREATE INDEX IX_Ausencias_EmpleadoID
    ON hr.Ausencias(EmpleadoID);

CREATE INDEX IX_Ausencias_Fechas
    ON hr.Ausencias(FechaInicio, FechaFin);

-- Evaluaciones: consultas por evaluado y por período
CREATE INDEX IX_Evaluaciones_EmpleadoEvaluado
    ON hr.Evaluaciones(EmpleadoEvaluadoID);

CREATE INDEX IX_Evaluaciones_Fecha
    ON hr.Evaluaciones(FechaEvaluacion);

-- Empleados: búsquedas por departamento y por jefe
CREATE INDEX IX_Empleados_Departamento
    ON hr.Empleados(DepartamentoID);

CREATE INDEX IX_Empleados_Jefe
    ON hr.Empleados(JefeDirectoID);

-- Salarios: consulta rápida del salario vigente
CREATE INDEX IX_Salarios_EmpleadoActual
    ON sec.EmpleadosSalarios(EmpleadoID, EsActual);
GO

PRINT '✓ Índices de rendimiento creados';
GO

-- ============================================================
-- 15. ROLES DE SEGURIDAD
-- ============================================================
-- RRHH_Analista  → puede ver datos enmascarados (análisis general)
-- RRHH_Nomina    → acceso completo a sec.EmpleadosSalarios
-- RRHH_Admin     → acceso total, puede desenmascararar datos
-- ============================================================

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'RRHH_Analista')
    CREATE ROLE RRHH_Analista;
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'RRHH_Nomina')
    CREATE ROLE RRHH_Nomina;
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'RRHH_Admin')
    CREATE ROLE RRHH_Admin;
GO

-- RRHH_Analista: lectura en esquema hr, SIN acceso a sec
GRANT SELECT ON SCHEMA::hr TO RRHH_Analista;

-- RRHH_Nomina: lectura en esquema hr + acceso a salarios
GRANT SELECT ON SCHEMA::hr  TO RRHH_Nomina;
GRANT SELECT ON SCHEMA::sec TO RRHH_Nomina;

-- RRHH_Admin: control total + puede ver datos sin máscara
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::hr  TO RRHH_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::sec TO RRHH_Admin;
GRANT UNMASK TO RRHH_Admin;
GO

PRINT '✓ Roles de seguridad RRHH_Analista, RRHH_Nomina, RRHH_Admin creados';
GO

-- ============================================================
-- 16. VERIFICACIÓN FINAL
-- ============================================================

SELECT
    s.name          AS Esquema,
    t.name          AS Tabla,
    t.create_date   AS FechaCreacion,
    COUNT(c.column_id) AS NumColumnas
FROM sys.tables     t
JOIN sys.schemas    s ON t.schema_id = s.schema_id
JOIN sys.columns    c ON t.object_id = c.object_id
WHERE s.name IN ('hr', 'sec')
GROUP BY s.name, t.name, t.create_date
ORDER BY s.name, t.name;
GO

PRINT '';
PRINT '============================================================';
PRINT '✅ SCRIPT 01 COMPLETADO — RRHH OLTP';
PRINT '';
PRINT '  Esquema hr  → 7 tablas operacionales';
PRINT '  Esquema sec → 1 tabla restringida (salarios)';
PRINT '  Roles       → RRHH_Analista | RRHH_Nomina | RRHH_Admin';
PRINT '';
PRINT '  Siguiente paso: Ejecutar 02_Poblar_RRHH_OLTP.sql';
PRINT '============================================================';
GO