# 🏢 Sistema de Business Intelligence para la Gestión Estratégica de Recursos Humanos
### TalentCorp S.A. — Evidencia de Aprendizaje 4 | Bases de Datos II

**Autora:** Hanna Jineth Contreras Salinas  
**Grupo:** 12  
**Docente:** Aharon Alexander Aguas  
**Institución:** Institución Universitaria Digital de Antioquia  
**Año:** 2026  

---

## 📋 Descripción del Proyecto

Sistema completo de Business Intelligence diseñado e implementado desde cero para TalentCorp S.A., empresa colombiana con operaciones en seis países. El proyecto abarca la totalidad de la cadena de valor de los datos: desde la base de datos operacional (OLTP) hasta el Data Warehouse dimensional (DWH), incluyendo procesos ETL, validaciones de calidad y consultas analíticas estratégicas.

### Arquitectura implementada
```
OLTP RRHH (SQL Server)
    └── ETL (Procedimientos almacenados)
            └── DWH RRHH_DW (Star Schema)
                    └── KPIs y Consultas Analíticas
```

---

## 🛠️ Tecnologías Utilizadas

| Tecnología | Versión | Uso |
|---|---|---|
| SQL Server | 2019 | Motor de base de datos |
| Docker | Latest | Contenedor SQL Server |
| DBeaver Community | 26.0 | Cliente SQL |
| Ubuntu Linux | 24.04 LTS | Sistema operativo |
| VS Code | Latest | Editor de scripts |

---

## 📁 Estructura del Repositorio
```
Ev4_BI_RRHH_TalentCorp/
├── README.md                          # Este archivo
├── scripts/                           # Scripts SQL en orden de ejecución
│   ├── 01_Crear_RRHH_OLTP.sql        # BD operacional: 9 tablas, esquemas hr/sec, DDM, roles
│   ├── 02_Poblar_RRHH_OLTP.sql       # 55 empleados, 6 oficinas, datos 2023-2024
│   ├── 03_Crear_RRHH_DWH.sql         # DWH: esquemas dim/fact/ctrl, RLS, 4 roles
│   ├── 04_Crear_Dimensiones.sql      # Procedimientos SCD Tipo 2 para 5 dimensiones
│   ├── 05_Crear_Hechos.sql           # Procedimientos ETL para 4 tablas de hechos
│   ├── 06_ETL_Poblar_DimTiempo.sql   # Calendario 2022-2026 con festivos colombianos
│   ├── 07_ETL_Cargar_Dimensiones.sql # Carga SCD Tipo 2 en orden correcto
│   ├── 07b_demo_scd_tipo2.sql        # Demo práctica: traslado empleado entre departamentos
│   ├── 08_ETL_Cargar_Hechos.sql      # 4 hechos + 24 snapshots headcount 2023-2024
│   ├── 09_Validaciones_DWH.sql       # 15 validaciones de calidad (6 críticas, 4 informativas, 5 métricas)
│   └── 10_Consultas_Analiticas.sql   # 15 KPIs estratégicos de RRHH
├── documentacion/
│   └── Ev4_BI_RRHH_TalentCorp_Final.pdf   # Documento completo normas APA 7
└── diagramas/
    ├── ER_OLTP_RRHH_TalentCorp.jpg         # Diagrama entidad-relación del OLTP
    └── Modelo_Estrella_Dimensiones_y_Hechos.jpg  # Star Schema del DWH
```

---

## 🚀 Orden de Ejecución

> ⚠️ Los scripts deben ejecutarse **en orden numérico estricto**. Cada script depende del anterior.
```sql
-- Paso 1: Crear y poblar el OLTP
01_Crear_RRHH_OLTP.sql
02_Poblar_RRHH_OLTP.sql

-- Paso 2: Crear el Data Warehouse
03_Crear_RRHH_DWH.sql
04_Crear_Dimensiones.sql
05_Crear_Hechos.sql

-- Paso 3: Ejecutar ETL
06_ETL_Poblar_DimTiempo.sql
07_ETL_Cargar_Dimensiones.sql
08_ETL_Cargar_Hechos.sql

-- Paso 4: Validar y analizar
09_Validaciones_DWH.sql
10_Consultas_Analiticas.sql
```

---

## 🗄️ Base de Datos OLTP — RRHH

- **Esquema hr:** 8 tablas operacionales
- **Esquema sec:** 1 tabla restringida (salarios — Decreto 1377/2013)
- **55 empleados** en 6 países: Colombia, México, España, USA, Brasil
- **Dynamic Data Masking** en datos personales sensibles
- **3 roles de seguridad:** RRHH_Admin, RRHH_Analista, RRHH_Nomina

---

## 🌟 Data Warehouse — RRHH_DW (Star Schema)

### Dimensiones

| Dimensión | Tipo | Descripción |
|---|---|---|
| Dim_Empleado | SCD Tipo 2 | Dimensión principal — historial de cambios organizacionales |
| Dim_Departamento | SCD Tipo 2 | Unidades organizacionales con sede |
| Dim_Puesto | SCD Tipo 2 | Cargos con bandas salariales en USD |
| Dim_Capacitacion | SCD Tipo 2 | Programas de formación con proveedor y costo |
| Dim_TipoAusencia | Estática | Tipos de ausencia y categorías |
| Dim_Tiempo | Estática | Calendario 2022-2026 con festivos colombianos (Ley Emiliani) |

### Tablas de Hechos

| Tabla | Granularidad | Registros |
|---|---|---|
| Fact_Ausencias | 1 ausencia | 84 |
| Fact_Evaluaciones | 1 evaluación | 80 |
| Fact_Capacitaciones | 1 asignación empleado-capacitación | 67 |
| Fact_Headcount | Snapshot mensual (55 × 24 meses) | 1.320 |

---

## 📊 KPIs Estratégicos Implementados

1. Headcount y masa salarial por departamento
2. Tasa de ausentismo por departamento y tipo
3. Desempeño promedio por departamento
4. Top 10 mejores desempeños acumulados
5. Inversión en capacitación por departamento
6. Evolución mensual del headcount 2023-2024
7. Top 10 empleados con más días de ausencia
8. Brecha salarial por género y nivel (Decreto 1227/2015)
9. Capacitación vs desempeño individual
10. Antigüedad promedio por departamento
11. Ausencias en días no laborables
12. Tendencia de desempeño semestral
13. Empleados sin capacitación reciente
14. Completitud de capacitaciones por departamento
15. **Dashboard ejecutivo** — 8 KPIs estratégicos consolidados

---

## ✅ Resultados del Sistema

| KPI | Resultado | Período |
|---|---|---|
| Headcount total | 55 empleados | Dic 2024 |
| Masa salarial mensual | USD 207.400 | Dic 2024 |
| Calificación promedio | 4.2 / 5.0 | 2023-2024 |
| Total días de ausencia | 652 días | 2023-2024 |
| Inversión en capacitación | USD 19.000 | 2023-2024 |
| Completitud capacitaciones | 92.5% | 2023-2024 |
| Ausencias no justificadas | 3 de 84 (3.6%) | 2023-2024 |

---

## 🔒 Gobernanza y Seguridad

- **Dynamic Data Masking** — datos personales sensibles (Decreto 1377/2013)
- **Row-Level Security** — acceso por departamento en el DWH
- **SCD Tipo 2** — historial de cambios organizacionales preservado
- **Política de retención 5 años** — Ley 1581/2012 de protección de datos
- **Género inclusivo** desde el diseño — Decreto 1227/2015

---

## 📚 Referencias

- Kimball, R., & Ross, M. (2013). *The data warehouse toolkit* (3.a ed.). Wiley.
- Inmon, W. H. (2005). *Building the data warehouse* (4.a ed.). Wiley.
- Microsoft Corporation. (2024). *SQL Server documentation*. https://docs.microsoft.com/en-us/sql/sql-server/
- Anthropic. (2026). *Claude* [Modelo de lenguaje de IA]. https://claude.ai

---

> 💡 **Nota:** El archivo `07b_demo_scd_tipo2.sql` es un script adicional que demuestra prácticamente el funcionamiento del SCD Tipo 2 simulando el traslado de un empleado entre departamentos y verificando que el DWH preserva el historial correctamente.