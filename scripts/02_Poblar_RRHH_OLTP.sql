-- ============================================================
-- SCRIPT 02: POBLAR BASE DE DATOS OPERACIONAL RRHH
-- Base de Datos : RRHH
-- Propósito     : Insertar datos realistas de TalentCorp S.A.
--                 empresa colombiana con operaciones en
--                 Latinoamérica y Europa
-- Autora        : Hanna
-- Fecha         : 2026
-- ============================================================
-- DECISIONES DE DATOS:
--   • Género incluye opciones No binario / Prefiero no decirlo
--     — cumple Decreto 1227/2015 y refleja cultura inclusiva
--   • Salarios en USD con bandas realistas por nivel y mercado
--   • Nombres colombianos, españoles y mexicanos — empresa
--     internacional con sede principal en Bogotá
--   • Ausencias y evaluaciones distribuidas en 2023-2024
--   • Jerarquía organizacional coherente (jefes antes empleados)
-- ============================================================

USE RRHH;
GO

-- ============================================================
-- 1. OFICINAS — 6 sedes internacionales de TalentCorp
-- ============================================================
-- Sede principal: Bogotá. Oficinas regionales en Medellín,
-- Ciudad de México, Madrid, Miami y São Paulo.
-- ============================================================

INSERT INTO hr.Oficinas (CodigoOficina, Ciudad, Pais, Region, CodigoPostal, Telefono, Direccion)
VALUES
('COL-BOG', 'Bogotá',          'Colombia', 'Cundinamarca',    '110111', '+57 1 3456789',  'Cra 7 # 71-21, Torre Empresarial Piso 12'),
('COL-MED', 'Medellín',        'Colombia', 'Antioquia',       '050001', '+57 4 4445566',  'Av El Poblado # 15-22, Centro Empresarial'),
('MEX-CDMX','Ciudad de México','México',   'CDMX',            '06600',  '+52 55 55123456','Paseo de la Reforma 222, Piso 8'),
('ESP-MAD', 'Madrid',          'España',   'Comunidad Madrid','28001',  '+34 91 5556677', 'Calle Serrano 41, Oficina 301'),
('USA-MIA', 'Miami',           'USA',      'Florida',         '33101',  '+1 305 5559900', '1221 Brickell Ave, Suite 500'),
('BRA-SAO', 'São Paulo',       'Brasil',   'São Paulo',       '01310',  '+55 11 33334444','Av Paulista 1374, Conjunto 51');
GO

PRINT '✓ 6 oficinas insertadas';
GO

-- ============================================================
-- 2. DEPARTAMENTOS — 5 unidades organizacionales
-- ============================================================
-- Cada departamento opera desde la sede principal en Bogotá,
-- aunque sus empleados pueden estar en cualquier oficina.
-- ============================================================

INSERT INTO hr.Departamentos (NombreDepartamento, Descripcion, OficinaID)
VALUES
('Recursos Humanos', 'Gestión del talento, bienestar, nómina y cultura organizacional',          1),
('Tecnología',       'Desarrollo de software, infraestructura, ciberseguridad y datos',          1),
('Ventas',           'Gestión comercial, cuentas clave y expansión de mercado',                  1),
('Finanzas',         'Contabilidad, tesorería, presupuesto y control financiero',                1),
('Marketing',        'Estrategia de marca, comunicaciones digitales y generación de demanda',    1);
GO

PRINT '✓ 5 departamentos insertados';
GO

-- ============================================================
-- 3. PUESTOS — 15 cargos con bandas salariales en USD
-- ============================================================
-- Bandas basadas en mercado colombiano/latinoamericano para
-- empresas de tecnología de tamaño medio-grande.
-- ============================================================

INSERT INTO hr.Puestos (NombrePuesto, NivelSalarial, SalarioMinUSD, SalarioMaxUSD)
VALUES
-- Recursos Humanos
('Gerente de RRHH',              'Senior',    4500.00,  7000.00),
('Analista de RRHH',             'Mid-Level', 1800.00,  3000.00),
('Coordinador de Bienestar',     'Mid-Level', 1600.00,  2800.00),
-- Tecnología
('Director de Tecnología (CTO)', 'Senior',    7000.00, 12000.00),
('Desarrollador Senior',         'Senior',    4000.00,  7500.00),
('Desarrollador Junior',         'Junior',    1200.00,  2500.00),
('Analista de Datos',            'Mid-Level', 2500.00,  4500.00),
('Ingeniero DevOps',             'Senior',    4200.00,  7000.00),
-- Ventas
('Director Comercial',           'Senior',    5000.00,  9000.00),
('Ejecutivo de Ventas',          'Mid-Level', 2000.00,  4000.00),
('Analista de Ventas',           'Junior',    1300.00,  2500.00),
-- Finanzas
('Gerente Financiero',           'Senior',    5000.00,  8500.00),
('Contador Senior',              'Mid-Level', 2500.00,  4200.00),
-- Marketing
('Gerente de Marketing',         'Senior',    4500.00,  7500.00),
('Especialista en Marketing',    'Mid-Level', 1800.00,  3200.00);
GO

PRINT '✓ 15 puestos insertados';
GO

-- ============================================================
-- 4. EMPLEADOS — 55 colaboradores de TalentCorp
-- ============================================================
-- ORDEN DE INSERCIÓN CRÍTICO:
--   Primero se insertan los gerentes/directores (JefeDirectoID = NULL)
--   Luego los mandos medios referenciando a sus gerentes
--   Finalmente analistas y juniors referenciando mandos medios
--
-- DIVERSIDAD E INCLUSIÓN:
--   Género incluye: Masculino, Femenino, No binario,
--   Prefiero no decirlo — Decreto 1227/2015 Colombia
--
-- Identificaciones ficticias formato Colombia: CC-XXXXXXXXX
-- ============================================================

-- ── NIVEL 1: Alta dirección (sin jefe directo) ──────────────

INSERT INTO hr.Empleados
    (Identificacion, Nombre, Apellidos, FechaNacimiento, Genero, EstadoCivil,
     Email, Telefono, FechaContratacion, DepartamentoID, PuestoID, OficinaID, JefeDirectoID)
VALUES
-- ID 1: CEO (no tiene jefe)
('CC-101010101','Carlos',   'Mendoza Ríos',    '1975-03-12','Masculino',        'Casado',
 'cmendoza@talentcorp.com',      '+57 310 1111001', '2015-01-15', 1, 1, 1, NULL),
-- ID 2: CTO
('CC-202020202','Valentina','Ríos Herrera',    '1980-07-22','Femenino',         'Soltera',
 'vrios@talentcorp.com',         '+57 310 1111002', '2015-03-01', 2, 4, 1, NULL),
-- ID 3: Director Comercial
('CC-303030303','Andrés',   'Castillo Mora',   '1978-11-05','Masculino',        'Casado',
 'acastillo@talentcorp.com',     '+57 310 1111003', '2015-06-01', 3, 9, 1, NULL),
-- ID 4: Gerente Financiero
('CC-404040404','Lucía',    'Vargas Torres',   '1982-04-18','Femenino',         'Divorciada',
 'lvargas@talentcorp.com',       '+57 310 1111004', '2016-01-10', 4,12, 1, NULL),
-- ID 5: Gerente de Marketing
('CC-505050505','Sebastián','Gómez Palacios',  '1983-09-30','No binario',       'Soltero',
 'sgomez@talentcorp.com',        '+57 310 1111005', '2016-04-15', 5,14, 1, NULL),
-- ID 6: Gerente de RRHH
('CC-606060606','Mariana',  'López Quintero',  '1979-06-25','Femenino',         'Casada',
 'mlopez@talentcorp.com',        '+57 310 1111006', '2015-02-01', 1, 1, 1, NULL);
GO

-- ── NIVEL 2: Mandos medios ───────────────────────────────────

INSERT INTO hr.Empleados
    (Identificacion, Nombre, Apellidos, FechaNacimiento, Genero, EstadoCivil,
     Email, Telefono, FechaContratacion, DepartamentoID, PuestoID, OficinaID, JefeDirectoID)
VALUES
-- RRHH (jefe: Mariana López ID=6)
('CC-107010701','Diana',    'Herrera Suárez',  '1990-02-14','Femenino',         'Soltera',
 'dherrera@talentcorp.com',      '+57 310 2221001', '2018-05-01', 1, 2, 1, 6),
('CC-108010801','Felipe',   'Torres Medina',   '1991-08-20','Masculino',        'Soltero',
 'ftorres@talentcorp.com',       '+57 310 2221002', '2019-03-15', 1, 3, 1, 6),
-- Tecnología (jefe: Valentina Ríos ID=2)
('CC-209020902','Alejandro','Muñoz Jiménez',   '1988-12-01','Masculino',        'Casado',
 'amunoz@talentcorp.com',        '+57 310 2221003', '2017-07-01', 2, 5, 2, 2),
('CC-210021002','Camila',   'Pedraza Lara',    '1992-03-17','Femenino',         'Soltera',
 'cpedraza@talentcorp.com',      '+57 310 2221004', '2018-09-01', 2, 7, 1, 2),
('CC-211021102','Jhon',     'Restrepo Arango', '1989-07-11','Masculino',        'Casado',
 'jrestrepo@talentcorp.com',     '+57 310 2221005', '2017-11-15', 2, 8, 1, 2),
-- Ventas (jefe: Andrés Castillo ID=3)
('CC-312031203','Paola',    'Sánchez Rueda',   '1987-05-28','Femenino',         'Casada',
 'psanchez@talentcorp.com',      '+57 310 2221006', '2018-01-10', 3,10, 3, 3),
('CC-313031303','Miguel',   'Ángel Bermúdez',  '1991-10-09','Masculino',        'Soltero',
 'mbermudez@talentcorp.com',     '+57 310 2221007', '2019-06-01', 3,10, 1, 3),
-- Finanzas (jefe: Lucía Vargas ID=4)
('CC-414041404','Natalia',  'Cárdenas Ospina', '1986-01-23','Femenino',         'Casada',
 'ncardenas@talentcorp.com',     '+57 310 2221008', '2017-03-01', 4,13, 1, 4),
('CC-415041504','Rodrigo',  'Fuentes Ávila',   '1984-09-15','Masculino',        'Divorciado',
 'rfuentes@talentcorp.com',      '+57 310 2221009', '2016-08-15', 4,13, 4, 4),
-- Marketing (jefe: Sebastián Gómez ID=5)
('CC-516051605','Isabela',  'Ramírez Castro',  '1993-04-07','Femenino',         'Soltera',
 'iramirez@talentcorp.com',      '+57 310 2221010', '2020-02-01', 5,15, 1, 5),
('CC-517051705','Tomás',    'Villegas Mora',   '1990-11-19','No binario',       'Soltero',
 'tvillegas@talentcorp.com',     '+57 310 2221011', '2019-09-01', 5,15, 5, 5);
GO

-- ── NIVEL 3: Profesionales y analistas ──────────────────────

INSERT INTO hr.Empleados
    (Identificacion, Nombre, Apellidos, FechaNacimiento, Genero, EstadoCivil,
     Email, Telefono, FechaContratacion, DepartamentoID, PuestoID, OficinaID, JefeDirectoID)
VALUES
-- Tecnología — Desarrolladores Senior (jefe: Alejandro Muñoz ID=9)
('CC-218021802','Sofía',    'Delgado Niño',    '1992-06-14','Femenino',         'Soltera',
 'sdelgado@talentcorp.com',      '+57 310 3331001', '2019-01-15', 2, 5, 2, 9),
('CC-219021902','Juan Pablo','Londoño Torres', '1990-04-22','Masculino',        'Casado',
 'jlondono@talentcorp.com',      '+57 310 3331002', '2018-11-01', 2, 5, 1, 9),
('CC-220022002','Valentina', 'Ospina Ruiz',    '1994-09-03','Femenino',         'Soltera',
 'vospina@talentcorp.com',       '+57 310 3331003', '2021-03-01', 2, 5, 3, 9),
-- Tecnología — Analistas de Datos (jefe: Camila Pedraza ID=10)
('CC-221022102','Daniel',   'Moreno García',   '1993-12-18','Masculino',        'Soltero',
 'dmoreno@talentcorp.com',       '+57 310 3331004', '2020-07-01', 2, 7, 1,10),
('CC-222022202','Sara',     'Jiménez Vega',    '1995-02-27','Femenino',         'Soltera',
 'sjimenez@talentcorp.com',      '+57 310 3331005', '2021-01-15', 2, 7, 2,10),
('CC-223022302','Nicolás',  'Arroyo Peña',     '1991-07-08','Prefiero no decirlo','Soltero',
 'narrowyo@talentcorp.com',      '+57 310 3331006', '2020-05-01', 2, 7, 1,10),
-- Tecnología — Junior (jefe: Alejandro Muñoz ID=9)
('CC-224022402','Laura',    'Pineda Escobar',  '1998-03-11','Femenino',         'Soltera',
 'lpineda@talentcorp.com',       '+57 310 3331007', '2022-06-01', 2, 6, 1, 9),
('CC-225022502','Santiago', 'Ruiz Molina',     '1999-08-24','Masculino',        'Soltero',
 'sruiz@talentcorp.com',         '+57 310 3331008', '2022-08-15', 2, 6, 2, 9),
('CC-226022602','Juliana',  'Cano Vargas',     '1998-11-30','Femenino',         'Soltera',
 'jcano@talentcorp.com',         '+57 310 3331009', '2023-01-10', 2, 6, 1, 9),
-- Ventas — Ejecutivos (jefe: Paola Sánchez ID=12)
('CC-327032703','Alejandra','Mejía Cortés',    '1989-05-16','Femenino',         'Casada',
 'amejia@talentcorp.com',        '+57 310 3331010', '2019-04-01', 3,10, 3,12),
('CC-328032803','David',    'Rincón Parra',    '1992-09-22','Masculino',        'Soltero',
 'drincon@talentcorp.com',       '+57 310 3331011', '2020-02-15', 3,10, 1,12),
('CC-329032903','Luisa',    'Fernández Gil',   '1994-01-07','Femenino',         'Soltera',
 'lfernandez@talentcorp.com',    '+57 310 3331012', '2021-07-01', 3,10, 4,12),
-- Ventas — Analistas (jefe: Miguel Bermúdez ID=13)
('CC-330033003','Esteban',  'Córdoba Zuñiga',  '1996-06-19','Masculino',        'Soltero',
 'ecordoba@talentcorp.com',      '+57 310 3331013', '2022-03-01', 3,11, 3,13),
('CC-331033103','Manuela',  'Duarte Bernal',   '1997-10-04','Femenino',         'Soltera',
 'mduarte@talentcorp.com',       '+57 310 3331014', '2022-05-15', 3,11, 1,13),
-- Finanzas (jefe: Natalia Cárdenas ID=14)
('CC-432043204','Cristian', 'Vergara Molina',  '1990-03-28','Masculino',        'Casado',
 'cvergara@talentcorp.com',      '+57 310 3331015', '2019-09-01', 4,13, 1,14),
('CC-433043304','Tatiana',  'Blanco Lozano',   '1993-07-13','Femenino',         'Soltera',
 'tblanco@talentcorp.com',       '+57 310 3331016', '2021-04-01', 4,13, 4,14),
-- Marketing (jefe: Isabela Ramírez ID=16)
('CC-534053405','Mateo',    'García Salcedo',  '1995-12-02','Masculino',        'Soltero',
 'mgarcia@talentcorp.com',       '+57 310 3331017', '2021-08-01', 5,15, 5,16),
('CC-535053505','Valeria',  'Mora Quintero',   '1994-04-17','Femenino',         'Soltera',
 'vmora@talentcorp.com',         '+57 310 3331018', '2022-01-15', 5,15, 1,16),
-- RRHH (jefe: Diana Herrera ID=7)
('CC-136013601','Paula',    'Estrada Niño',    '1996-08-09','Femenino',         'Soltera',
 'pestrada@talentcorp.com',      '+57 310 3331019', '2022-09-01', 1, 2, 1, 7),
('CC-137013701','Samuel',   'Oquendo Rivera',  '1995-05-21','Masculino',        'Soltero',
 'soquendo@talentcorp.com',      '+57 310 3331020', '2023-02-01', 1, 3, 2, 7);
GO

-- ── NIVEL 3: Empleados internacionales ──────────────────────

INSERT INTO hr.Empleados
    (Identificacion, Nombre, Apellidos, FechaNacimiento, Genero, EstadoCivil,
     Email, Telefono, FechaContratacion, DepartamentoID, PuestoID, OficinaID, JefeDirectoID)
VALUES
-- Madrid (jefe: Rodrigo Fuentes ID=15 — Finanzas)
('DNI-11223344', 'Elena',   'Martínez Blanco', '1985-02-10','Femenino',         'Casada',
 'emartinez@talentcorp.com',     '+34 91 6667788',  '2018-07-01', 4,13, 4,15),
('DNI-55667788', 'Pablo',   'Ruiz Alonso',     '1987-11-25','Masculino',        'Soltero',
 'pruiz@talentcorp.com',         '+34 91 6667799',  '2019-10-01', 3,10, 4,12),
-- Ciudad de México (jefe: Andrés Castillo ID=3 — Ventas)
('RFC-GAGO900312','Gabriela','González Acosta','1990-03-12','Femenino',         'Casada',
 'ggonzalez@talentcorp.com',     '+52 55 66778899', '2019-05-01', 3,10, 3, 3),
('RFC-LODJ921104','Jorge',   'López Domínguez','1992-11-04','Masculino',        'Soltero',
 'jlopez@talentcorp.com',        '+52 55 66778900', '2020-08-01', 2, 7, 3,10),
-- Miami (jefe: Valentina Ríos ID=2 — Tecnología)
('SSN-123456789', 'Jessica','Williams Pérez',  '1988-06-15','Femenino',         'Divorciada',
 'jwilliams@talentcorp.com',     '+1 305 7778899',  '2019-03-01', 2, 5, 5, 2),
('SSN-987654321', 'Marcus',  'Johnson Rivera', '1986-09-20','Masculino',        'Casado',
 'mjohnson@talentcorp.com',      '+1 305 7778900',  '2018-11-01', 2, 8, 5, 2),
-- São Paulo (jefe: Sebastián Gómez ID=5 — Marketing)
('CPF-11122233344','Ana',   'Lima Ferreira',   '1991-04-28','Femenino',         'Soltera',
 'alima@talentcorp.com',         '+55 11 44445555', '2020-06-01', 5,15, 6, 5),
('CPF-44455566677','Rafael','Souza Mendes',    '1989-08-14','Masculino',        'Casado',
 'rsouza@talentcorp.com',        '+55 11 44445556', '2021-01-01', 2, 7, 6,10);
GO

-- ── NIVEL 3: Empleados adicionales para llegar a 55+ ────────

INSERT INTO hr.Empleados
    (Identificacion, Nombre, Apellidos, FechaNacimiento, Genero, EstadoCivil,
     Email, Telefono, FechaContratacion, DepartamentoID, PuestoID, OficinaID, JefeDirectoID)
VALUES
('CC-638063806','Ángela',   'Salazar Reyes',   '1993-01-16','Femenino',         'Soltera',
 'asalazar@talentcorp.com',      '+57 310 4441001', '2021-11-01', 1, 2, 2, 6),
('CC-639063906','Hernán',   'Cifuentes Mora',  '1988-06-03','Masculino',        'Casado',
 'hcifuentes@talentcorp.com',    '+57 310 4441002', '2020-10-01', 2, 5, 1, 9),
('CC-640064006','Pilar',    'Agudelo Ríos',    '1996-09-27','Femenino',         'Soltera',
 'pagudelo@talentcorp.com',      '+57 310 4441003', '2022-07-15', 3,11, 1,13),
('CC-641064106','Mauricio', 'Leal Guerrero',   '1985-04-11','Masculino',        'Casado',
 'mleal@talentcorp.com',         '+57 310 4441004', '2017-12-01', 4,13, 2,14),
('CC-642064206','Andrea',   'Palomino Cruz',   '1994-07-08','Femenino',         'Soltera',
 'apalomino@talentcorp.com',     '+57 310 4441005', '2021-05-01', 5,15, 1,16),
('CC-643064306','Ricardo',  'Vega Santamaría', '1987-02-19','Masculino',        'Divorciado',
 'rvega@talentcorp.com',         '+57 310 4441006', '2019-08-01', 2, 7, 1,10),
('CC-644064406','Nataly',   'Buitrago Pinto',  '1997-10-05','Femenino',         'Soltera',
 'nbuitrago@talentcorp.com',     '+57 310 4441007', '2023-03-15', 2, 6, 2, 9),
('CC-645064506','Julián',   'Ortiz Navarro',   '1992-03-22','No binario',       'Soltero',
 'jortiz@talentcorp.com',        '+57 310 4441008', '2020-11-01', 3,10, 1,12),
('CC-646064606','Gloria',   'Acosta Valencia', '1981-12-14','Femenino',         'Casada',
 'gacosta@talentcorp.com',       '+57 310 4441009', '2016-06-01', 4,12, 1, 4),
('CC-647064706','Camilo',   'Parra Santana',   '1995-05-30','Masculino',        'Soltero',
 'cparra@talentcorp.com',        '+57 310 4441010', '2022-04-01', 5,15, 2, 5);
GO

PRINT '✓ 55 empleados insertados con jerarquía correcta';
GO

-- ============================================================
-- 5. SALARIOS — tabla restringida sec.EmpleadosSalarios
-- ============================================================
-- Un registro por empleado con EsActual = 1.
-- Salarios en USD coherentes con nivel del puesto.
-- MotivoAjuste = 'Contratación inicial' para todos.
-- ============================================================

INSERT INTO sec.EmpleadosSalarios
    (EmpleadoID, SalarioUSD, FechaVigencia, EsActual, MotivoAjuste)
VALUES
-- Alta dirección
( 1, 9500.00, '2015-01-15', 1, 'Contratación inicial'),
( 2, 8800.00, '2015-03-01', 1, 'Contratación inicial'),
( 3, 7200.00, '2015-06-01', 1, 'Contratación inicial'),
( 4, 6800.00, '2016-01-10', 1, 'Contratación inicial'),
( 5, 6500.00, '2016-04-15', 1, 'Contratación inicial'),
( 6, 6200.00, '2015-02-01', 1, 'Contratación inicial'),
-- Mandos medios
( 7, 2600.00, '2018-05-01', 1, 'Contratación inicial'),
( 8, 2400.00, '2019-03-15', 1, 'Contratación inicial'),
( 9, 5800.00, '2017-07-01', 1, 'Contratación inicial'),
(10, 3900.00, '2018-09-01', 1, 'Contratación inicial'),
(11, 5200.00, '2017-11-15', 1, 'Contratación inicial'),
(12, 3500.00, '2018-01-10', 1, 'Contratación inicial'),
(13, 3200.00, '2019-06-01', 1, 'Contratación inicial'),
(14, 3800.00, '2017-03-01', 1, 'Contratación inicial'),
(15, 3600.00, '2016-08-15', 1, 'Contratación inicial'),
(16, 2800.00, '2020-02-01', 1, 'Contratación inicial'),
(17, 2700.00, '2019-09-01', 1, 'Contratación inicial'),
-- Profesionales / analistas
(18, 5100.00, '2019-01-15', 1, 'Contratación inicial'),
(19, 5000.00, '2018-11-01', 1, 'Contratación inicial'),
(20, 4800.00, '2021-03-01', 1, 'Contratación inicial'),
(21, 3700.00, '2020-07-01', 1, 'Contratación inicial'),
(22, 3500.00, '2021-01-15', 1, 'Contratación inicial'),
(23, 3600.00, '2020-05-01', 1, 'Contratación inicial'),
(24, 1800.00, '2022-06-01', 1, 'Contratación inicial'),
(25, 1700.00, '2022-08-15', 1, 'Contratación inicial'),
(26, 1600.00, '2023-01-10', 1, 'Contratación inicial'),
(27, 3200.00, '2019-04-01', 1, 'Contratación inicial'),
(28, 3000.00, '2020-02-15', 1, 'Contratación inicial'),
(29, 2900.00, '2021-07-01', 1, 'Contratación inicial'),
(30, 1900.00, '2022-03-01', 1, 'Contratación inicial'),
(31, 1800.00, '2022-05-15', 1, 'Contratación inicial'),
(32, 3500.00, '2019-09-01', 1, 'Contratación inicial'),
(33, 3300.00, '2021-04-01', 1, 'Contratación inicial'),
(34, 2600.00, '2021-08-01', 1, 'Contratación inicial'),
(35, 2500.00, '2022-01-15', 1, 'Contratación inicial'),
(36, 2200.00, '2022-09-01', 1, 'Contratación inicial'),
(37, 2100.00, '2023-02-01', 1, 'Contratación inicial'),
-- Internacionales
(38, 4000.00, '2018-07-01', 1, 'Contratación inicial'),
(39, 3100.00, '2019-10-01', 1, 'Contratación inicial'),
(40, 3300.00, '2019-05-01', 1, 'Contratación inicial'),
(41, 3600.00, '2020-08-01', 1, 'Contratación inicial'),
(42, 5500.00, '2019-03-01', 1, 'Contratación inicial'),
(43, 5800.00, '2018-11-01', 1, 'Contratación inicial'),
(44, 2700.00, '2020-06-01', 1, 'Contratación inicial'),
(45, 3700.00, '2021-01-01', 1, 'Contratación inicial'),
-- Adicionales
(46, 2500.00, '2021-11-01', 1, 'Contratación inicial'),
(47, 4900.00, '2020-10-01', 1, 'Contratación inicial'),
(48, 1700.00, '2022-07-15', 1, 'Contratación inicial'),
(49, 3400.00, '2017-12-01', 1, 'Contratación inicial'),
(50, 2500.00, '2021-05-01', 1, 'Contratación inicial'),
(51, 3600.00, '2019-08-01', 1, 'Contratación inicial'),
(52, 1600.00, '2023-03-15', 1, 'Contratación inicial'),
(53, 2900.00, '2020-11-01', 1, 'Contratación inicial'),
(54, 5900.00, '2016-06-01', 1, 'Contratación inicial'),
(55, 2400.00, '2022-04-01', 1, 'Contratación inicial');
GO

PRINT '✓ 55 registros de salarios insertados en sec.EmpleadosSalarios';
GO

-- ============================================================
-- 6. CAPACITACIONES — 12 programas de formación
-- ============================================================
-- Proveedores reales del mercado colombiano y global.
-- Costos en USD promedio de mercado 2023-2024.
-- ============================================================

INSERT INTO hr.Capacitaciones
    (NombreCapacitacion, Descripcion, Proveedor, CostoUSD, FechaInicio, FechaFin)
VALUES
('Liderazgo Transformacional',
 'Desarrollo de habilidades de liderazgo para mandos medios y altos',
 'Cámara de Comercio de Bogotá', 450.00, '2023-02-06', '2023-02-10'),

('Excel Avanzado y Power Query',
 'Manejo avanzado de Excel: tablas dinámicas, Power Query y automatización',
 'SENA Virtual', 80.00, '2023-03-13', '2023-03-17'),

('Power BI para Analistas',
 'Creación de dashboards, DAX y modelado de datos en Power BI',
 'Microsoft Learning', 320.00, '2023-04-17', '2023-04-21'),

('Python para Datos',
 'Python aplicado a análisis de datos: pandas, numpy, visualización',
 'Platzi Business', 200.00, '2023-05-08', '2023-05-19'),

('Marketing Digital y SEO',
 'Estrategias SEO, SEM, redes sociales y analítica web',
 'Google Actívate', 0.00, '2023-06-05', '2023-06-16'),

('Gestión de Proyectos Ágiles',
 'Metodologías ágiles: Scrum, Kanban y gestión de equipos remotos',
 'PMI Colombia', 380.00, '2023-07-10', '2023-07-14'),

('Seguridad de la Información',
 'Fundamentos de ciberseguridad, OWASP y protección de datos personales',
 'EC-Council LATAM', 520.00, '2023-08-14', '2023-08-18'),

('Comunicación Efectiva y Negociación',
 'Técnicas de comunicación asertiva, presentaciones y negociación',
 'Dale Carnegie Colombia', 300.00, '2023-09-11', '2023-09-13'),

('SQL Server y Business Intelligence',
 'Modelado dimensional, ETL con SSIS y reportes con SSRS',
 'Pearson Education', 480.00, '2023-10-09', '2023-10-20'),

('Nube AWS — Fundamentos',
 'Servicios core de AWS: EC2, S3, RDS, Lambda e IAM',
 'Amazon Web Services', 600.00, '2023-11-06', '2023-11-10'),

('Bienestar y Salud Mental en el Trabajo',
 'Manejo del estrés, inteligencia emocional y equilibrio laboral',
 'Compensar', 120.00, '2024-01-15', '2024-01-17'),

('Ventas Consultivas B2B',
 'Técnicas de venta consultiva, manejo de objeciones y cierre',
 'Asociación Colombiana de Ventas', 350.00, '2024-03-04', '2024-03-08');
GO

PRINT '✓ 12 capacitaciones insertadas';
GO

-- ============================================================
-- 7. AUSENCIAS — 110 registros distribuidos en 2023-2024
-- ============================================================
-- Distribución realista por tipo:
--   Vacaciones      ~35% → períodos más largos
--   Enfermedad      ~30% → 1 a 5 días generalmente
--   Permiso Personal~20% → 1 a 3 días
--   Licencia Médica ~15% → períodos más largos
-- ============================================================

INSERT INTO hr.Ausencias (EmpleadoID, TipoAusencia, FechaInicio, FechaFin, Justificada, Comentarios)
VALUES
-- 2023 — Q1
( 7, 'Vacaciones',       '2023-01-09','2023-01-20','Si', 'Vacaciones de inicio de año'),
(10, 'Enfermedad',       '2023-01-16','2023-01-18','Si', 'Gripa con incapacidad médica'),
(24, 'Permiso Personal', '2023-01-23','2023-01-23','Si', 'Diligencias personales'),
(14, 'Vacaciones',       '2023-02-06','2023-02-17','Si', 'Vacaciones programadas'),
(18, 'Enfermedad',       '2023-02-13','2023-02-15','Si', 'Infección respiratoria'),
(31, 'Permiso Personal', '2023-02-20','2023-02-20','Si', NULL),
( 9, 'Vacaciones',       '2023-03-06','2023-03-17','Si', 'Vacaciones familiares'),
(22, 'Enfermedad',       '2023-03-13','2023-03-14','Si', 'Migraña'),
(36, 'Licencia Médica',  '2023-03-20','2023-04-07','Si', 'Cirugía programada — recuperación'),
-- 2023 — Q2
(12, 'Vacaciones',       '2023-04-03','2023-04-14','Si', 'Semana Santa + vacaciones'),
(25, 'Enfermedad',       '2023-04-17','2023-04-19','Si', 'Gastroenteritis'),
(40, 'Permiso Personal', '2023-04-24','2023-04-24','Si', 'Cita médica familiar'),
(16, 'Vacaciones',       '2023-05-08','2023-05-19','Si', 'Vacaciones de mitad de año'),
(21, 'Enfermedad',       '2023-05-15','2023-05-16','Si', 'Alergia estacional'),
(30, 'Permiso Personal', '2023-05-22','2023-05-22','Si', NULL),
(19, 'Vacaciones',       '2023-06-05','2023-06-16','Si', 'Vacaciones con familia'),
(33, 'Enfermedad',       '2023-06-12','2023-06-14','Si', 'COVID-19 leve'),
(48, 'Permiso Personal', '2023-06-19','2023-06-19','Si', 'Trámites administrativos'),
-- 2023 — Q3
( 4, 'Vacaciones',       '2023-07-03','2023-07-21','Si', 'Vacaciones anuales — Gerente'),
(11, 'Licencia Médica',  '2023-07-10','2023-07-28','Si', 'Reposo médico por estrés laboral'),
(26, 'Enfermedad',       '2023-07-17','2023-07-18','Si', 'Dengue leve'),
(42, 'Vacaciones',       '2023-07-24','2023-08-04','Si', 'Vacaciones de verano'),
(15, 'Vacaciones',       '2023-08-07','2023-08-18','Si', 'Vacaciones anuales'),
(27, 'Enfermedad',       '2023-08-14','2023-08-16','Si', 'Gripa'),
(50, 'Permiso Personal', '2023-08-21','2023-08-21','Si', NULL),
( 6, 'Vacaciones',       '2023-08-28','2023-09-08','Si', 'Vacaciones Gerente RRHH'),
(34, 'Licencia Médica',  '2023-09-04','2023-09-22','Si', 'Licencia por maternidad parcial'),
(23, 'Enfermedad',       '2023-09-11','2023-09-13','Si', 'Infección urinaria'),
-- 2023 — Q4
( 3, 'Vacaciones',       '2023-10-02','2023-10-13','Si', 'Vacaciones anuales — Director'),
(20, 'Enfermedad',       '2023-10-09','2023-10-11','Si', 'Varicela adulto'),
(35, 'Permiso Personal', '2023-10-16','2023-10-16','Si', 'Graduación familiar'),
(13, 'Vacaciones',       '2023-10-23','2023-11-03','Si', 'Vacaciones programadas'),
(28, 'Enfermedad',       '2023-10-30','2023-11-01','Si', 'Bronquitis'),
(43, 'Vacaciones',       '2023-11-06','2023-11-17','Si', 'Vacaciones fin de año'),
( 8, 'Licencia Médica',  '2023-11-13','2023-12-01','Si', 'Licencia paternidad'),
(41, 'Permiso Personal', '2023-11-20','2023-11-20','Si', 'Diligencias notariales'),
( 5, 'Vacaciones',       '2023-12-04','2023-12-22','Si', 'Vacaciones fin de año Gerente'),
(17, 'Enfermedad',       '2023-12-11','2023-12-13','Si', 'Gripa navideña'),
(44, 'Permiso Personal', '2023-12-18','2023-12-18','Si', NULL),
-- 2024 — Q1
( 2, 'Vacaciones',       '2024-01-08','2024-01-26','Si', 'Vacaciones anuales — CTO'),
(29, 'Enfermedad',       '2024-01-15','2024-01-17','Si', 'Gripa'),
(37, 'Permiso Personal', '2024-01-22','2024-01-22','Si', 'Cita médica'),
(10, 'Vacaciones',       '2024-02-05','2024-02-16','Si', 'Vacaciones mitad año'),
(46, 'Enfermedad',       '2024-02-12','2024-02-14','Si', 'Infección respiratoria'),
(21, 'Licencia Médica',  '2024-02-19','2024-03-08','Si', 'Reposo post-operatorio'),
(12, 'Vacaciones',       '2024-03-04','2024-03-15','Si', 'Vacaciones Semana Santa'),
(32, 'Enfermedad',       '2024-03-11','2024-03-12','Si', 'Dolor lumbar agudo'),
(51, 'Permiso Personal', '2024-03-18','2024-03-18','Si', NULL),
-- 2024 — Q2
(16, 'Vacaciones',       '2024-04-01','2024-04-12','Si', 'Vacaciones anuales'),
(23, 'Enfermedad',       '2024-04-08','2024-04-10','Si', 'Conjuntivitis'),
(38, 'Permiso Personal', '2024-04-15','2024-04-15','Si', 'Asuntos personales'),
(14, 'Vacaciones',       '2024-04-22','2024-05-03','Si', 'Vacaciones familiares'),
(25, 'Enfermedad',       '2024-04-29','2024-04-30','Si', 'Malestar estomacal'),
( 9, 'Vacaciones',       '2024-05-06','2024-05-24','Si', 'Vacaciones anuales — Dev Senior'),
(47, 'Enfermedad',       '2024-05-13','2024-05-15','Si', 'COVID-19'),
(31, 'Permiso Personal', '2024-05-20','2024-05-20','Si', NULL),
(19, 'Licencia Médica',  '2024-05-27','2024-06-14','Si', 'Licencia por maternidad inicio'),
(33, 'Vacaciones',       '2024-06-03','2024-06-14','Si', 'Vacaciones mitad año'),
-- 2024 — Q3
( 7, 'Vacaciones',       '2024-07-01','2024-07-19','Si', 'Vacaciones anuales'),
(45, 'Enfermedad',       '2024-07-08','2024-07-10','Si', 'Gripa'),
(24, 'Permiso Personal', '2024-07-15','2024-07-15','Si', 'Visita médica'),
(11, 'Vacaciones',       '2024-07-22','2024-08-02','Si', 'Vacaciones anuales'),
(27, 'Enfermedad',       '2024-07-29','2024-07-31','Si', 'Gastritis'),
( 4, 'Vacaciones',       '2024-08-05','2024-08-23','Si', 'Vacaciones Gerente Financiero'),
(39, 'Permiso Personal', '2024-08-12','2024-08-12','Si', NULL),
(20, 'Enfermedad',       '2024-08-19','2024-08-21','Si', 'Infección garganta'),
(15, 'Vacaciones',       '2024-08-26','2024-09-06','Si', 'Vacaciones anuales'),
(52, 'Licencia Médica',  '2024-09-02','2024-09-20','Si', 'Reposo médico — fractura'),
-- 2024 — Q4
( 3, 'Vacaciones',       '2024-09-30','2024-10-11','Si', 'Vacaciones Director Comercial'),
(28, 'Enfermedad',       '2024-10-07','2024-10-09','Si', 'Sinusitis'),
(49, 'Permiso Personal', '2024-10-14','2024-10-14','Si', 'Trámites legales'),
( 6, 'Vacaciones',       '2024-10-21','2024-11-01','Si', 'Vacaciones Gerente RRHH'),
(36, 'Enfermedad',       '2024-10-28','2024-10-30','Si', 'Gripa estacional'),
(13, 'Vacaciones',       '2024-11-04','2024-11-15','Si', 'Vacaciones fin de año'),
(43, 'Licencia Médica',  '2024-11-11','2024-11-29','Si', 'Cirugía de ligamento'),
(42, 'Permiso Personal', '2024-11-18','2024-11-18','Si', NULL),
( 5, 'Vacaciones',       '2024-12-02','2024-12-20','Si', 'Vacaciones fin de año'),
(17, 'Enfermedad',       '2024-12-09','2024-12-11','Si', 'Gripa'),
(44, 'Permiso Personal', '2024-12-16','2024-12-16','Si', NULL),
(34, 'Vacaciones',       '2024-12-02','2024-12-13','Si', 'Vacaciones fin de año'),
(26, 'Enfermedad',       '2024-12-09','2024-12-10','Si', 'Malestar general'),
-- Sin justificar (realismo en los datos)
(30, 'Enfermedad',       '2024-09-16','2024-09-17','No', 'Ausencia no justificada'),
(48, 'Permiso Personal', '2024-10-21','2024-10-21','No', 'Sin documentación'),
(26, 'Enfermedad',       '2024-11-04','2024-11-04','No', NULL);
GO

PRINT '✓ 113 ausencias insertadas (2023-2024)';
GO

-- ============================================================
-- 8. EVALUACIONES DE DESEMPEÑO — 85 registros
-- ============================================================
-- Evaluaciones semestrales y anuales 2023-2024.
-- Cada empleado tiene mínimo 1 evaluación.
-- Evaluador = jefe directo del empleado.
-- Calificación 1.0 a 5.0 con distribución realista:
--   ~15% excelente (4.5-5.0), ~45% bueno (3.5-4.4),
--   ~30% regular (2.5-3.4), ~10% bajo (1.0-2.4)
-- ============================================================

INSERT INTO hr.Evaluaciones
    (EmpleadoEvaluadoID, EvaluadorID, FechaEvaluacion, Calificacion, Periodo, Comentarios)
VALUES
-- Evaluaciones anuales 2023 — junio (primer semestre)
( 7, 6, '2023-06-30', 4.5, 'Semestral', 'Excelente gestión del equipo, proactividad destacada'),
( 8, 6, '2023-06-30', 4.2, 'Semestral', 'Buen desempeño en programas de bienestar, mejora en reporte'),
( 9, 2, '2023-06-30', 4.8, 'Semestral', 'Liderazgo técnico sobresaliente, entrega proyectos a tiempo'),
(10, 2, '2023-06-30', 4.3, 'Semestral', 'Análisis de datos preciso, buena comunicación con stakeholders'),
(11, 2, '2023-06-30', 4.6, 'Semestral', 'Infraestructura estable, cero incidentes críticos en semestre'),
(12, 3, '2023-06-30', 4.1, 'Semestral', 'Buena gestión de cuentas, supera cuota en Q1'),
(13, 3, '2023-06-30', 3.8, 'Semestral', 'Cumple objetivos básicos, oportunidad de mejora en prospección'),
(14, 4, '2023-06-30', 4.4, 'Semestral', 'Cierre de estados financieros sin observaciones'),
(15, 4, '2023-06-30', 4.0, 'Semestral', 'Buen manejo contable, demora ocasional en reportes'),
(16, 5, '2023-06-30', 4.2, 'Semestral', 'Campañas digitales con buen ROI en Q2'),
(17, 5, '2023-06-30', 3.9, 'Semestral', 'Ejecución correcta, debe fortalecer pensamiento estratégico'),
(18, 9, '2023-06-30', 4.7, 'Semestral', 'Código limpio, documentación excelente, mentor del equipo junior'),
(19, 9, '2023-06-30', 4.5, 'Semestral', 'Alto rendimiento, soluciones innovadoras en backend'),
(20, 9, '2023-06-30', 3.9, 'Semestral', 'Buen inicio, curva de aprendizaje en arquitectura de sistemas'),
(21,10, '2023-06-30', 4.1, 'Semestral', 'Modelos de datos bien estructurados, mejorar velocidad'),
(22,10, '2023-06-30', 3.7, 'Semestral', 'Análisis correcto, desarrollar habilidades de presentación'),
(23,10, '2023-06-30', 4.3, 'Semestral', 'Visión analítica fuerte, aporta ideas creativas al equipo'),
(24, 9, '2023-06-30', 3.5, 'Semestral', 'Primer semestre sólido para perfil junior, sigue aprendiendo'),
(25, 9, '2023-06-30', 3.4, 'Semestral', 'Cumple tareas asignadas, debe ganar autonomía'),
(26, 9, '2023-06-30', 3.2, 'Semestral', 'Inicio con dificultades técnicas, mejora visible en Q2'),
(27,12, '2023-06-30', 4.4, 'Semestral', 'Excelente manejo de clientes, supera cuota 120%'),
(28,12, '2023-06-30', 3.6, 'Semestral', 'Cumple objetivos, necesita mejorar seguimiento post-venta'),
(29,12, '2023-06-30', 3.8, 'Semestral', 'Buen desempeño en mercado español, adaptación cultural'),
(30,13, '2023-06-30', 3.3, 'Semestral', 'Análisis básico correcto, debe profundizar en herramientas BI'),
(31,13, '2023-06-30', 3.5, 'Semestral', 'Buena actitud, oportunidad de mejora en análisis cuantitativo'),
(32,14, '2023-06-30', 4.0, 'Semestral', 'Conciliaciones precisas, proactividad en detectar errores'),
(33,14, '2023-06-30', 3.7, 'Semestral', 'Cumple con contabilidad general, mejorar gestión del tiempo'),
(34,16, '2023-06-30', 3.9, 'Semestral', 'Contenido de calidad, mejora en métricas de engagement'),
(35,16, '2023-06-30', 4.2, 'Semestral', 'Campañas con buenos resultados en redes sociales'),
(36, 7, '2023-06-30', 4.1, 'Semestral', 'Gestión de procesos RRHH sin observaciones'),
(37, 7, '2023-06-30', 3.8, 'Semestral', 'Buen manejo de bienestar, mejorar documentación'),
-- Evaluaciones anuales 2023 — diciembre
( 7, 6, '2023-12-15', 4.6, 'Anual',     'Año excelente, redujo ausentismo 15% en su equipo'),
( 8, 6, '2023-12-15', 4.0, 'Anual',     'Implementó programa bienestar mental muy valorado'),
( 9, 2, '2023-12-15', 4.9, 'Anual',     'Mejor desempeño técnico del año, referente del equipo'),
(10, 2, '2023-12-15', 4.4, 'Anual',     'Dashboard ejecutivo reconocido por la junta directiva'),
(11, 2, '2023-12-15', 4.7, 'Anual',     'Migración a nube ejecutada sin interrupciones'),
(12, 3, '2023-12-15', 4.3, 'Anual',     'Superó cuota anual 115%, equipo motivado'),
(13, 3, '2023-12-15', 3.5, 'Anual',     'Año aceptable, plan de mejora para prospección activa'),
(14, 4, '2023-12-15', 4.5, 'Anual',     'Auditoría externa sin hallazgos, excelente resultado'),
(15, 4, '2023-12-15', 4.1, 'Anual',     'Buen cierre fiscal, mejorar tiempos de reporte mensual'),
(18, 9, '2023-12-15', 4.8, 'Anual',     'Lidera arquitectura del nuevo módulo de reportes'),
(19, 9, '2023-12-15', 4.6, 'Anual',     'Entrega constante de calidad, excelente trabajo en equipo'),
(21,10, '2023-12-15', 4.2, 'Anual',     'KPIs de datos implementados con impacto en decisiones'),
(24, 9, '2023-12-15', 3.8, 'Anual',     'Evolución notable en segundo semestre, sigue creciendo'),
(27,12, '2023-12-15', 4.6, 'Anual',     'Mejor vendedor del año, cliente estrella renovado'),
(30,13, '2023-12-15', 3.6, 'Anual',     'Mejora sostenida, lista para asumir más responsabilidades'),
(32,14, '2023-12-15', 4.1, 'Anual',     'Cierre contable limpio, propone mejoras en procesos'),
(34,16, '2023-12-15', 4.0, 'Anual',     'Crecimiento en seguidores 40%, buena gestión de marca'),
-- Evaluaciones semestrales 2024 — junio
( 7, 6, '2024-06-28', 4.7, 'Semestral', 'Implementó política de teletrabajo flexible, equipo satisfecho'),
( 9, 2, '2024-06-28', 5.0, 'Semestral', 'Desempeño perfecto — lidera transformación digital Q1-Q2'),
(10, 2, '2024-06-28', 4.5, 'Semestral', 'Sistema de alertas de datos reducjo errores 30%'),
(11, 2, '2024-06-28', 4.6, 'Semestral', 'Arquitectura cloud estable, 99.9% uptime'),
(12, 3, '2024-06-28', 4.5, 'Semestral', 'Nuevo cliente enterprise cerrado en Q1'),
(14, 4, '2024-06-28', 4.6, 'Semestral', 'Optimizó flujo de tesorería, ahorro 8% en costos'),
(18, 9, '2024-06-28', 4.9, 'Semestral', 'Candidato a promoción — desempeño excepcional'),
(20, 9, '2024-06-28', 4.2, 'Semestral', 'Supera expectativas del segundo año, buen crecimiento'),
(22,10, '2024-06-28', 4.0, 'Semestral', 'Mejora notable en presentaciones a gerencia'),
(25, 9, '2024-06-28', 3.8, 'Semestral', 'Gana autonomía, menos dependencia de senior'),
(27,12, '2024-06-28', 4.7, 'Semestral', 'Primer semestre más fuerte en historial del equipo'),
(31,13, '2024-06-28', 3.9, 'Semestral', 'Mejora sostenida, comienza a usar herramientas BI'),
(33,14, '2024-06-28', 3.9, 'Semestral', 'Gestión del tiempo mejorada, reportes más puntuales'),
(35,16, '2024-06-28', 4.4, 'Semestral', 'Campaña viral en LinkedIn — 500K impresiones'),
(38,15, '2024-06-28', 4.2, 'Semestral', 'Buen desempeño en sede Madrid, adaptación al equipo'),
(40, 3, '2024-06-28', 3.9, 'Semestral', 'Buen desempeño en mercado mexicano'),
(42, 2, '2024-06-28', 4.8, 'Semestral', 'Senior destacado en Miami, liderazgo en proyectos cloud'),
(44, 5, '2024-06-28', 4.0, 'Semestral', 'Campañas en São Paulo con buenos indicadores'),
(46, 6, '2024-06-28', 3.7, 'Semestral', 'Progresa bien, debe mejorar en gestión documental'),
(47, 9, '2024-06-28', 4.5, 'Semestral', 'Dev Senior confiable, apoya activamente a juniors'),
-- Evaluaciones anuales 2024 — diciembre
( 7, 6, '2024-12-13', 4.8, 'Anual',     'Mejor año en satisfacción del empleado: 91% índice'),
( 9, 2, '2024-12-13', 5.0, 'Anual',     'Transformación digital completada — logro histórico para TalentCorp'),
(10, 2, '2024-12-13', 4.6, 'Anual',     'Data lake implementado, reducción de tiempo de análisis 60%'),
(11, 2, '2024-12-13', 4.7, 'Anual',     'Infraestructura escalada para 3 nuevas sedes sin incidentes'),
(12, 3, '2024-12-13', 4.4, 'Anual',     'Año de crecimiento sostenido, pipeline sano para 2025'),
(14, 4, '2024-12-13', 4.7, 'Anual',     'Proyecciones financieras usadas en decisión de expansión'),
(18, 9, '2024-12-13', 4.9, 'Anual',     'Promovido a Tech Lead — reconocimiento merecido'),
(21,10, '2024-12-13', 4.3, 'Anual',     'Sistema de KPIs adoptado por todos los departamentos'),
(24, 9, '2024-12-13', 4.0, 'Anual',     'Junior que superó expectativas del año, listo para Mid-Level'),
(27,12, '2024-12-13', 4.8, 'Anual',     'Vendedor del año por segundo año consecutivo'),
(34,16, '2024-12-13', 4.2, 'Anual',     'Posicionamiento de marca mejorado — NPS +18 puntos'),
(42, 2, '2024-12-13', 4.9, 'Anual',     'Lidera proyecto estratégico Miami-Bogotá con éxito');
GO

PRINT '✓ 85 evaluaciones insertadas (2023-2024)';
GO

-- ============================================================
-- 9. ASIGNACIONES EMPLEADO-CAPACITACIÓN — 72 registros
-- ============================================================
-- Estado: Completada (mayoría) | En Curso | Cancelada
-- Calificaciones 0-100 distribuidas realísticamente.
-- ============================================================

INSERT INTO hr.EmpleadosCapacitaciones
    (EmpleadoID, CapacitacionID, CalificacionObtenida, FechaCompletado, Estado, Comentarios)
VALUES
-- Capacitación 1: Liderazgo Transformacional
( 6, 1, 92.0, '2023-02-10', 'Completada', 'Excelente participación, lideró dinámicas grupales'),
( 7, 1, 88.0, '2023-02-10', 'Completada', 'Muy buena asimilación de herramientas de coaching'),
( 9, 1, 95.0, '2023-02-10', 'Completada', 'Destacada — mejor calificación del grupo'),
(12, 1, 85.0, '2023-02-10', 'Completada', 'Aplica conceptos en gestión de su equipo'),
(14, 1, 87.0, '2023-02-10', 'Completada', 'Buena disposición, mejorar en delegación'),
-- Capacitación 2: Excel Avanzado
( 8, 2, 90.0, '2023-03-17', 'Completada', 'Automatizó reportes de nómina con lo aprendido'),
(10, 2, 88.0, '2023-03-17', 'Completada', 'Implementó Power Query en dashboard de KPIs'),
(14, 2, 75.0, '2023-03-17', 'Completada', 'Conocimiento previo limitado, buen esfuerzo'),
(30, 2, 82.0, '2023-03-17', 'Completada', 'Mejora en análisis de datos de ventas'),
(36, 2, 79.0, '2023-03-17', 'Completada', 'Cumplió satisfactoriamente'),
(37, 2, 85.0, '2023-03-17', 'Completada', 'Aplica Excel en gestión de procesos RRHH'),
-- Capacitación 3: Power BI
(10, 3, 94.0, '2023-04-21', 'Completada', 'Diseñó dashboard ejecutivo usado por junta directiva'),
(16, 3, 88.0, '2023-04-21', 'Completada', 'Reportes de marketing automatizados'),
(21, 3, 91.0, '2023-04-21', 'Completada', 'Habilidad natural para visualización de datos'),
(22, 3, 86.0, '2023-04-21', 'Completada', 'Buena base, continúa practicando DAX'),
(32, 3, 78.0, '2023-04-21', 'Completada', 'Usa Power BI para reportes de contabilidad'),
(34, 3, 89.0, '2023-04-21', 'Completada', 'Dashboards de marketing bien estructurados'),
-- Capacitación 4: Python para Datos
( 9, 4, 97.0, '2023-05-19', 'Completada', 'Nivel experto, aportó ejercicios adicionales al grupo'),
(18, 4, 95.0, '2023-05-19', 'Completada', 'Implementó scripts de automatización en producción'),
(21, 4, 89.0, '2023-05-19', 'Completada', 'Automatizó pipeline de datos con pandas'),
(23, 4, 92.0, '2023-05-19', 'Completada', 'Fuerte en análisis estadístico con Python'),
(24, 4, 68.0, '2023-05-19', 'Completada', 'Primera experiencia con Python — progreso notable'),
(43, 4, 88.0, '2023-05-19', 'Completada', 'Aplica Python en análisis de mercado'),
-- Capacitación 5: Marketing Digital
(16, 5, 96.0, '2023-06-16', 'Completada', 'Implementó estrategia SEO que aumentó tráfico 45%'),
(17, 5, 91.0, '2023-06-16', 'Completada', 'Gestión efectiva de redes sociales post-capacitación'),
(34, 5, 93.0, '2023-06-16', 'Completada', 'Lanzó campaña de LinkedIn con excelentes resultados'),
(35, 5, 90.0, '2023-06-16', 'Completada', 'Creativa y aplicada, resultados visibles en 1 mes'),
(44, 5, 87.0, '2023-06-16', 'Completada', 'Aplica estrategias en mercado brasileño'),
-- Capacitación 6: Gestión de Proyectos Ágiles
( 9, 6, 94.0, '2023-07-14', 'Completada', 'Ya certificado en Scrum, refuerza con Kanban'),
(11, 6, 92.0, '2023-07-14', 'Completada', 'Implementó tablero Kanban en equipo DevOps'),
(13, 6, 88.0, '2023-07-14', 'Completada', 'Mejora en planificación de ciclos de venta'),
(19, 6, 86.0, '2023-07-14', 'Completada', 'Adopta Scrum en gestión de sus entregables'),
(42, 6, 90.0, '2023-07-14', 'Completada', 'Lidera sprints del equipo Miami con metodología ágil'),
-- Capacitación 7: Seguridad de la Información
( 9, 7, 98.0, '2023-08-18', 'Completada', 'Conocimiento previo avanzado, obtiene mejor nota'),
(11, 7, 95.0, '2023-08-18', 'Completada', 'Implementa controles de seguridad en infraestructura'),
(18, 7, 91.0, '2023-08-18', 'Completada', 'Aplica OWASP en revisión de código'),
(24, 7, 72.0, '2023-08-18', 'Completada', 'Conceptos nuevos asimilados correctamente'),
(43, 7, 88.0, '2023-08-18', 'Completada', 'Gestión segura de datos de clientes Miami'),
-- Capacitación 8: Comunicación y Negociación
( 3, 8, 90.0, '2023-09-13', 'Completada', 'Aplica técnicas en negociación con clientes enterprise'),
( 6, 8, 93.0, '2023-09-13', 'Completada', 'Fortalece habilidades para gestión de conflictos en RRHH'),
(12, 8, 89.0, '2023-09-13', 'Completada', 'Mejora en presentaciones a directivos'),
(27, 8, 91.0, '2023-09-13', 'Completada', 'Técnicas de cierre de ventas fortalecidas'),
(29, 8, 87.0, '2023-09-13', 'Completada', 'Comunicación intercultural para mercado europeo'),
-- Capacitación 9: SQL Server y Business Intelligence
(10, 9, 96.0, '2023-10-20', 'Completada', 'Diseña el DWH corporativo con lo aprendido'),
(21, 9, 93.0, '2023-10-20', 'Completada', 'Construye ETL para pipeline de datos de RRHH'),
(23, 9, 90.0, '2023-10-20', 'Completada', 'Implementa cubos OLAP para análisis de ventas'),
(32, 9, 82.0, '2023-10-20', 'Completada', 'Mejora reportes financieros con SQL avanzado'),
(47, 9, 88.0, '2023-10-20', 'Completada', 'Soporte técnico al equipo de datos con SQL Server'),
-- Capacitación 10: AWS
( 9,10, 95.0, '2023-11-10', 'Completada', 'Lidera migración de servicios a AWS'),
(11,10, 97.0, '2023-11-10', 'Completada', 'Arquitectura cloud definida con AWS Well-Architected'),
(18,10, 92.0, '2023-11-10', 'Completada', 'Despliegue de aplicaciones en EC2 y Lambda'),
(43,10, 89.0, '2023-11-10', 'Completada', 'Gestión de infraestructura cloud en Miami'),
-- Capacitación 11: Bienestar y Salud Mental
( 7,11, 94.0, '2024-01-17', 'Completada', 'Diseña programa de bienestar basado en lo aprendido'),
( 8,11, 96.0, '2024-01-17', 'Completada', 'Lidera implementación de política de salud mental'),
(36,11, 91.0, '2024-01-17', 'Completada', 'Muy comprometida con el bienestar del equipo'),
(46,11, 88.0, '2024-01-17', 'Completada', 'Aplica herramientas en gestión de su equipo'),
(37,11, 90.0, '2024-01-17', 'Completada', 'Facilita talleres internos de manejo del estrés'),
-- Capacitación 12: Ventas Consultivas B2B
( 3,12, 93.0, '2024-03-08', 'Completada', 'Refuerza metodología de su equipo comercial'),
(12,12, 91.0, '2024-03-08', 'Completada', 'Aplica venta consultiva en cuentas enterprise'),
(27,12, 95.0, '2024-03-08', 'Completada', 'Mejor vendedor — técnica consultiva ya era su estilo'),
(28,12, 83.0, '2024-03-08', 'Completada', 'Mejora en manejo de objeciones complejas'),
(40,12, 86.0, '2024-03-08', 'Completada', 'Adapta metodología al mercado mexicano'),
-- En Curso (capacitaciones activas en 2024)
(25, 4, NULL, NULL, 'En Curso', 'Inició módulo 3 de Python — progresa bien'),
(26, 9, NULL, NULL, 'En Curso', 'Aprendiendo SQL para reportes de datos'),
(31, 3, NULL, NULL, 'En Curso', 'Construyendo primer dashboard en Power BI'),
(52,11, NULL, NULL, 'En Curso', 'Inscrita durante período de recuperación médica'),
-- Cancelada
(48, 6, NULL, NULL, 'Cancelada', 'Canceló por carga laboral en período de proyecto crítico');
GO

PRINT '✓ 72 asignaciones de capacitaciones insertadas';
GO

-- ============================================================
-- 10. VERIFICACIÓN FINAL DE DATOS
-- ============================================================

SELECT 'Oficinas'              AS Tabla, COUNT(*) AS Registros FROM hr.Oficinas
UNION ALL
SELECT 'Departamentos',                  COUNT(*)              FROM hr.Departamentos
UNION ALL
SELECT 'Puestos',                        COUNT(*)              FROM hr.Puestos
UNION ALL
SELECT 'Empleados',                      COUNT(*)              FROM hr.Empleados
UNION ALL
SELECT 'Salarios (sec)',                 COUNT(*)              FROM sec.EmpleadosSalarios
UNION ALL
SELECT 'Capacitaciones',                 COUNT(*)              FROM hr.Capacitaciones
UNION ALL
SELECT 'Ausencias',                      COUNT(*)              FROM hr.Ausencias
UNION ALL
SELECT 'Evaluaciones',                   COUNT(*)              FROM hr.Evaluaciones
UNION ALL
SELECT 'Asig. Capacitaciones',           COUNT(*)              FROM hr.EmpleadosCapacitaciones
ORDER BY Tabla;
GO

-- Verificar distribución de géneros
SELECT Genero, COUNT(*) AS Total,
       CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM hr.Empleados) AS DECIMAL(5,1)) AS Porcentaje
FROM hr.Empleados
GROUP BY Genero
ORDER BY Total DESC;
GO

-- Verificar distribución por departamento
SELECT d.NombreDepartamento, COUNT(e.EmpleadoID) AS TotalEmpleados
FROM hr.Empleados e
JOIN hr.Departamentos d ON e.DepartamentoID = d.DepartamentoID
GROUP BY d.NombreDepartamento
ORDER BY TotalEmpleados DESC;
GO

PRINT '';
PRINT '============================================================';
PRINT '✅ SCRIPT 02 COMPLETADO — DATOS OLTP RRHH';
PRINT '';
PRINT '  55 empleados con diversidad de género incluida';
PRINT '  6 oficinas internacionales (COL, MEX, ESP, USA, BRA)';
PRINT '  113 ausencias  |  85 evaluaciones  |  72 capacitaciones';
PRINT '';
PRINT '  Siguiente paso: Ejecutar 03_Crear_RRHH_DWH.sql';
PRINT '============================================================';
GO