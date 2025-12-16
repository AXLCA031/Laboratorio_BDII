-- ============================================================
-- LAB: Paquetes y Disparadores
-- ALUMNO: AXEL ANDREE CUEVA ALCALA
-- CODIGO: 23200093
-- ============================================================


-- Configuración de salida
SET SERVEROUTPUT ON;

-- ======================================================================
-- PARTE II: CREACIÓN DE TABLESPACES
-- ======================================================================

/* 1. Crear Tablespace de DATOS "Esquema":
   - 2 datafiles.
   - Autoextend (crecimiento automático).
   - Gestión de extensión local.
   - Gestión de espacio de segmento automática.
   
   NOTA: Cambiar la ruta 'C:\ORADATA\...' según la estructura de tu PC.
*/
CREATE TABLESPACE Esquema
    DATAFILE 'C:\ORADATA\esquema01.dbf' SIZE 100M AUTOEXTEND ON NEXT 10M MAXSIZE 500M,
             'C:\ORADATA\esquema02.dbf' SIZE 100M AUTOEXTEND ON NEXT 10M MAXSIZE 500M
    LOGGING
    EXTENT MANAGEMENT LOCAL AUTOALLOCATE
    SEGMENT SPACE MANAGEMENT AUTO;

/* 2. Crear Tablespace TEMPORAL "TempEsquema":
   - 1 datafile.
   - Tamaño fijo (sin autoextend).
*/
CREATE TEMPORARY TABLESPACE TempEsquema
    TEMPFILE 'C:\ORADATA\tempesquema01.dbf' SIZE 50M;

-- ======================================================================
-- PARTE III: CREACIÓN DE TABLAS (DDL)
-- ======================================================================
/*
   Escenario Universidad:
   Se modela una superclase "PERSONA" y subclases "PROFESOR", "ALUMNO", "PERSONAL".
   Además tablas de referencia: DEPARTAMENTO, CENTRO, TITULACION, UNIDAD.
*/

-- Tablas Maestras (Independientes)
CREATE TABLE CENTROS (
    id_centro NUMBER(5) PRIMARY KEY,
    nombre_centro VARCHAR2(50) NOT NULL
) TABLESPACE Esquema;

CREATE TABLE DEPARTAMENTOS (
    id_depto NUMBER(5) PRIMARY KEY,
    nombre_depto VARCHAR2(50) NOT NULL
) TABLESPACE Esquema;

CREATE TABLE TITULACIONES (
    id_titulacion NUMBER(5) PRIMARY KEY,
    nombre_titulacion VARCHAR2(50) NOT NULL
) TABLESPACE Esquema;

CREATE TABLE UNIDADES_ADMIN (
    id_unidad NUMBER(5) PRIMARY KEY,
    nombre_unidad VARCHAR2(50) NOT NULL
) TABLESPACE Esquema;

-- Tabla Padre: PERSONAS (Datos comunes)
CREATE TABLE PERSONAS (
    id_persona NUMBER(8) PRIMARY KEY,
    nombre VARCHAR2(50) NOT NULL,
    direccion VARCHAR2(100),
    telefono VARCHAR2(15),
    email VARCHAR2(50)
) TABLESPACE Esquema;

-- Tabla Hija: PROFESORES
CREATE TABLE PROFESORES (
    id_persona NUMBER(8) PRIMARY KEY,
    id_depto NUMBER(5) NOT NULL,
    dedicacion VARCHAR2(20),
    -- FK hacia la tabla padre (Herencia)
    CONSTRAINT fk_prof_persona FOREIGN KEY (id_persona) REFERENCES PERSONAS(id_persona),
    -- FK hacia departamento
    CONSTRAINT fk_prof_depto FOREIGN KEY (id_depto) REFERENCES DEPARTAMENTOS(id_depto)
) TABLESPACE Esquema;

-- Tabla intermedia: PROFESORES imparten clase en CENTROS (Relación N:M)
CREATE TABLE DOCENCIA_CENTROS (
    id_persona NUMBER(8),
    id_centro NUMBER(5),
    CONSTRAINT pk_docencia PRIMARY KEY (id_persona, id_centro),
    CONSTRAINT fk_doc_prof FOREIGN KEY (id_persona) REFERENCES PROFESORES(id_persona),
    CONSTRAINT fk_doc_centro FOREIGN KEY (id_centro) REFERENCES CENTROS(id_centro)
) TABLESPACE Esquema;

-- Tabla Hija: ALUMNOS
CREATE TABLE ALUMNOS (
    id_persona NUMBER(8) PRIMARY KEY,
    id_centro NUMBER(5) NOT NULL, -- Matriculado en un único centro
    id_titulacion NUMBER(5) NOT NULL,
    num_expediente VARCHAR2(20) UNIQUE,
    -- FK hacia persona
    CONSTRAINT fk_alum_persona FOREIGN KEY (id_persona) REFERENCES PERSONAS(id_persona),
    CONSTRAINT fk_alum_centro FOREIGN KEY (id_centro) REFERENCES CENTROS(id_centro),
    CONSTRAINT fk_alum_titul FOREIGN KEY (id_titulacion) REFERENCES TITULACIONES(id_titulacion)
) TABLESPACE Esquema;

-- Tabla Hija: PERSONAL
CREATE TABLE PERSONAL (
    id_persona NUMBER(8) PRIMARY KEY,
    id_unidad NUMBER(5) NOT NULL,
    categoria_profesional VARCHAR2(30),
    -- FK hacia persona
    CONSTRAINT fk_pers_persona FOREIGN KEY (id_persona) REFERENCES PERSONAS(id_persona),
    CONSTRAINT fk_pers_unidad FOREIGN KEY (id_unidad) REFERENCES UNIDADES_ADMIN(id_unidad)
) TABLESPACE Esquema;

-- ======================================================================
-- PARTE IV: VISTA Y ÍNDICES
-- ======================================================================

/*
   Crear vista que liste alfabéticamente a todos los vinculados con la universidad.
   Usamos LEFT JOIN para traer datos específicos si existen.
*/
CREATE OR REPLACE VIEW V_COMUNIDAD_UNIVERSITARIA AS
SELECT 
    p.nombre, 
    p.email, 
    'PROFESOR' AS TIPO, 
    d.nombre_depto AS DETALLE_UBICACION
FROM PERSONAS p
JOIN PROFESORES pr ON p.id_persona = pr.id_persona
JOIN DEPARTAMENTOS d ON pr.id_depto = d.id_depto
UNION ALL
SELECT 
    p.nombre, 
    p.email, 
    'ALUMNO' AS TIPO, 
    t.nombre_titulacion AS DETALLE_UBICACION
FROM PERSONAS p
JOIN ALUMNOS a ON p.id_persona = a.id_persona
JOIN TITULACIONES t ON a.id_titulacion = t.id_titulacion
UNION ALL
SELECT 
    p.nombre, 
    p.email, 
    'PERSONAL' AS TIPO, 
    u.nombre_unidad AS DETALLE_UBICACION
FROM PERSONAS p
JOIN PERSONAL pe ON p.id_persona = pe.id_persona
JOIN UNIDADES_ADMIN u ON pe.id_unidad = u.id_unidad
ORDER BY 1; -- Ordenar por nombre

/*
   Crear índices para buscar por nombre a cada tipo de persona.
   (En realidad, como el nombre está en PERSONAS, basta un índice allí, 
    pero crearemos índices en las FK de las hijas para mejorar joins).
*/
-- Índice principal de búsqueda por nombre
CREATE INDEX idx_personas_nombre ON PERSONAS(nombre);

-- Índices de FK para optimizar el modelo
CREATE INDEX idx_prof_depto ON PROFESORES(id_depto);
CREATE INDEX idx_alum_centro ON ALUMNOS(id_centro);
CREATE INDEX idx_pers_unidad ON PERSONAL(id_unidad);
