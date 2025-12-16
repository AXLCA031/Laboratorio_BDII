-- ============================================================
-- LAB: Paquetes y Disparadores
-- ALUMNO: AXEL ANDREE CUEVA ALCALA
-- CODIGO: 23200093
-- ============================================================


-- 1. Eliminación previa (Limpieza si se ejecuta varias veces)
-- Orden inverso a las dependencias (Hijas primero, luego padres)
DROP TABLE HISTORIAL_SALARIAL CASCADE CONSTRAINTS;
DROP TABLE HISTORIAL_LABORAL CASCADE CONSTRAINTS;
DROP TABLE ESTUDIOS CASCADE CONSTRAINTS;
DROP TABLE EMPLEADOS CASCADE CONSTRAINTS;
DROP TABLE TRABAJOS CASCADE CONSTRAINTS;
DROP TABLE DEPARTAMENTOS CASCADE CONSTRAINTS;
DROP TABLE UNIVERSIDADES CASCADE CONSTRAINTS;

-- ======================================================================
-- CREACIÓN DE TABLAS (Puntos 1, 2, 3, 4, 5 del enunciado)
-- ======================================================================

-- Tabla DEPARTAMENTOS
CREATE TABLE DEPARTAMENTOS (
    DPTO_COD NUMBER(5) PRIMARY KEY,
    NOMBRE_DPTO VARCHAR2(30) NOT NULL UNIQUE, -- Punto 3: No se llaman igual
    DPTO_PADRE NUMBER(5),
    PRESUPUESTO NUMBER NOT NULL, -- Punto 1: Obligatorio
    PRES_ACTUAL NUMBER,
    CONSTRAINT fk_dpto_padre FOREIGN KEY (DPTO_PADRE) REFERENCES DEPARTAMENTOS(DPTO_COD)
);

-- Tabla TRABAJOS
CREATE TABLE TRABAJOS (
    TRABAJO_COD NUMBER(5) PRIMARY KEY,
    NOMBRE_TRAB VARCHAR2(20) NOT NULL UNIQUE, -- Punto 3: No se llaman igual
    SALARIO_MIN NUMBER(8,2) NOT NULL, -- Punto 1: Obligatorio
    SALARIO_MAX NUMBER(8,2) NOT NULL
);

-- Tabla EMPLEADOS
CREATE TABLE EMPLEADOS (
    DNI NUMBER(8) PRIMARY KEY,
    NOMBRE VARCHAR2(10) NOT NULL,    -- Punto 1
    APELLIDO1 VARCHAR2(15) NOT NULL, -- Punto 1
    APELLIDO2 VARCHAR2(15),
    DIRECC1 VARCHAR2(25),
    DIRECC2 VARCHAR2(20),
    CIUDAD VARCHAR2(20),
    PROVINCIA VARCHAR2(20),
    COD_POSTAL VARCHAR2(5),
    SEXO VARCHAR2(1),
    FECHA_NAC DATE,
    -- Punto 2: Sexo solo H o M
    CONSTRAINT ck_sexo CHECK (SEXO IN ('H', 'M'))
);

-- Tabla UNIVERSIDADES
CREATE TABLE UNIVERSIDADES (
    UNIV_COD NUMBER(5) PRIMARY KEY,
    NOMBRE_UNIV VARCHAR2(25),
    CIUDAD VARCHAR2(20),
    MUNICIPIO VARCHAR2(2),
    COD_POSTAL VARCHAR2(5)
);

-- Tabla ESTUDIOS
CREATE TABLE ESTUDIOS (
    EMPLEADO_DNI NUMBER(8),
    UNIVERSIDAD NUMBER(5),
    ANO NUMBER,
    GRADO VARCHAR2(3),
    ESPECIALIDAD VARCHAR2(20),
    CONSTRAINT pk_estudios PRIMARY KEY (EMPLEADO_DNI, ESPECIALIDAD), -- PK compuesta supuesta
    CONSTRAINT fk_est_emp FOREIGN KEY (EMPLEADO_DNI) REFERENCES EMPLEADOS(DNI),
    CONSTRAINT fk_est_univ FOREIGN KEY (UNIVERSIDAD) REFERENCES UNIVERSIDADES(UNIV_COD)
);

-- Tabla HISTORIAL_LABORAL
CREATE TABLE HISTORIAL_LABORAL (
    EMPLEADO_DNI NUMBER(8),
    TRABAJO_COD NUMBER(5),
    FECHA_INICIO DATE,
    FECHA_FIN DATE,
    DPTO_COD NUMBER(5),
    SUPERVISOR_DNI NUMBER(8),
    CONSTRAINT pk_hist_lab PRIMARY KEY (EMPLEADO_DNI, FECHA_INICIO),
    CONSTRAINT fk_hl_emp FOREIGN KEY (EMPLEADO_DNI) REFERENCES EMPLEADOS(DNI),
    CONSTRAINT fk_hl_trab FOREIGN KEY (TRABAJO_COD) REFERENCES TRABAJOS(TRABAJO_COD),
    CONSTRAINT fk_hl_dpto FOREIGN KEY (DPTO_COD) REFERENCES DEPARTAMENTOS(DPTO_COD),
    CONSTRAINT fk_hl_sup FOREIGN KEY (SUPERVISOR_DNI) REFERENCES EMPLEADOS(DNI)
);

-- Tabla HISTORIAL_SALARIAL
CREATE TABLE HISTORIAL_SALARIAL (
    EMPLEADO_DNI NUMBER(8),
    SALARIO NUMBER NOT NULL, -- Punto 1
    FECHA_COMIENZO DATE,
    FECHA_FIN DATE,
    CONSTRAINT pk_hist_sal PRIMARY KEY (EMPLEADO_DNI, FECHA_COMIENZO),
    CONSTRAINT fk_hs_emp FOREIGN KEY (EMPLEADO_DNI) REFERENCES EMPLEADOS(DNI)
);

-- ======================================================================
-- OPERACIONES SOLICITADAS
-- ======================================================================

-- 6. Agregar campos telefono y celular a empleados
ALTER TABLE EMPLEADOS ADD (TELEFONO VARCHAR2(15), CELULAR VARCHAR2(15));

-- 7. Insertar filas (Solo las obligatorias según enunciado para probar)
-- Insertar Empleados
INSERT INTO EMPLEADOS (NOMBRE, APELLIDO1, APELLIDO2, DNI, SEXO) 
VALUES ('Sergio', 'Palma', 'Entrena', 111222, 'H');

INSERT INTO EMPLEADOS (NOMBRE, APELLIDO1, APELLIDO2, DNI, SEXO) 
VALUES ('Lucia', 'Ortega', 'Plus', 222333, 'M');

-- Insertar Historial Laboral
-- Nota: Para insertar aqui, necesitamos data en DEPTOS y TRABAJOS primero si hay FKs activas.
-- Insertamos dummy data para que funcione la FK
INSERT INTO DEPARTAMENTOS VALUES (10, 'Sistemas', NULL, 10000, 5000);
INSERT INTO TRABAJOS VALUES (1, 'Programador', 1000, 5000);

INSERT INTO HISTORIAL_LABORAL (EMPLEADO_DNI, TRABAJO_COD, FECHA_INICIO, FECHA_FIN, DPTO_COD, SUPERVISOR_DNI)
VALUES (111222, 1, TO_DATE('16/06/96','DD/MM/YY'), NULL, 10, 222333);

COMMIT;

-- 8. ¿Qué ocurre si asignamos supervisor inexistente?
/*
   Intento: UPDATE HISTORIAL_LABORAL SET SUPERVISOR_DNI = 999999 WHERE EMPLEADO_DNI = 111222;
   Resultado: ORA-02291: integrity constraint (FK_HL_SUP) violated - parent key not found.
   Explicación: La integridad referencial impide asignar un ID que no existe en la tabla padre (EMPLEADOS).
*/

-- 9. Borrado de Universidad y Restricción FK
/*
   Si borras una universidad, fallará si hay estudios vinculados.
   Solución: Modificar la tabla para ON DELETE SET NULL o CASCADE.
*/
ALTER TABLE ESTUDIOS DROP CONSTRAINT fk_est_univ;
ALTER TABLE ESTUDIOS ADD CONSTRAINT fk_est_univ 
    FOREIGN KEY (UNIVERSIDAD) REFERENCES UNIVERSIDADES(UNIV_COD) ON DELETE SET NULL;

-- 10. Restricción condicional (Si hay ciudad, debe haber Cod Postal)
/*
   Las filas existentes que violen esto causarán error al crear el constraint con ENABLE VALIDATE.
   Se usa NOVALIDATE para aplicar solo a nuevos registros si hay data sucia.
*/
ALTER TABLE EMPLEADOS ADD CONSTRAINT ck_ciudad_cp 
CHECK ( (CIUDAD IS NULL) OR (CIUDAD IS NOT NULL AND COD_POSTAL IS NOT NULL) );

-- 11. Añadir atributo VALORACIÓN (Defecto 5)
ALTER TABLE EMPLEADOS ADD VALORACION NUMBER(2) DEFAULT 5;
ALTER TABLE EMPLEADOS ADD CONSTRAINT ck_valoracion CHECK (VALORACION BETWEEN 1 AND 10);

-- 12. Eliminar NOT NULL de NOMBRE en EMPLEADOS
ALTER TABLE EMPLEADOS MODIFY (NOMBRE NULL);

-- 13. Modificar tipo de DIREC1 a VARCHAR(40)
ALTER TABLE EMPLEADOS MODIFY (DIRECC1 VARCHAR2(40));

-- 14. Modificar tipo de FECHA_NAC a Cadena
/*
   ALTER TABLE EMPLEADOS MODIFY (FECHA_NAC VARCHAR2(20));
   R: Esto fallará si la columna tiene datos y no está vacía, a menos que se borren los datos 
   o se use una columna temporal para conversión. Oracle no permite cambio directo de tipo incompatible con data.
*/

-- 15. Cambiar Clave Primaria de EMPLEADOS a (NOMBRE, APELLIDOS)
/* Primero hay que borrar las FK que apuntan a DNI en las otras tablas (Historial, Estudios, etc).
   Este es un proceso destructivo para el modelo. Aquí se muestra el código teórico DDL.
*/
ALTER TABLE EMPLEADOS DROP PRIMARY KEY CASCADE; -- Cascade borra las FKs hijas automáticamente
ALTER TABLE EMPLEADOS ADD CONSTRAINT pk_emp_nombre 
PRIMARY KEY (NOMBRE, APELLIDO1, APELLIDO2);

-- 16. Tabla INFORMACION_UNIVERSITARIA
CREATE TABLE INFORMACION_UNIVERSITARIA AS
SELECT 
    e.NOMBRE || ' ' || e.APELLIDO1 || ' ' || e.APELLIDO2 AS NOMBRE_COMPLETO,
    u.NOMBRE_UNIV
FROM EMPLEADOS e
JOIN ESTUDIOS s ON e.DNI = s.EMPLEADO_DNI -- Nota: Esto fallará si ya ejecutaste el paso 15 y DNI no es PK
JOIN UNIVERSIDADES u ON s.UNIVERSIDAD = u.UNIV_COD;

-- 17. Vista NOMBRE_EMPLEADOS (Málaga)
CREATE OR REPLACE VIEW NOMBRE_EMPLEADOS AS
SELECT NOMBRE || ' ' || APELLIDO1 || ' ' || APELLIDO2 AS NOMBRE_COMPLETO
FROM EMPLEADOS
WHERE CIUDAD = 'MALAGA';

-- 18. Vista INFORMACION_EMPLEADOS (Con Edad)
CREATE OR REPLACE VIEW INFORMACION_EMPLEADOS AS
SELECT 
    NOMBRE || ' ' || APELLIDO1 || ' ' || APELLIDO2 AS NOMBRE_COMPLETO,
    TRUNC(MONTHS_BETWEEN(SYSDATE, FECHA_NAC)/12) AS EDAD
FROM EMPLEADOS;

-- 19. Vista INFORMACION_ACTUAL (Info + Salario actual)
/* Asumimos que el salario actual es aquel cuya FECHA_FIN es NULL en historial salarial.
   Como cambiamos la PK en el paso 15, el JOIN original por DNI fallaría. 
   Escribo el query asumiendo el modelo original por DNI.
*/
CREATE OR REPLACE VIEW INFORMACION_ACTUAL AS
SELECT 
    ie.NOMBRE_COMPLETO,
    ie.EDAD,
    hs.SALARIO
FROM INFORMACION_EMPLEADOS ie
-- Nota: Para hacer este join correctamente, la vista anterior debió incluir el ID (DNI), 
-- pero el enunciado pedía solo nombre y edad.
-- Aquí hacemos un join teórico asumiendo que tenemos cómo cruzar.
JOIN EMPLEADOS e ON (ie.NOMBRE_COMPLETO = e.NOMBRE || ' ' || e.APELLIDO1 || ' ' || e.APELLIDO2)
LEFT JOIN HISTORIAL_SALARIAL hs ON e.DNI = hs.EMPLEADO_DNI
WHERE hs.FECHA_FIN IS NULL;

-- 20. Borrar todas las tablas
/* ¿Hay que tener en cuenta las claves ajenas?
   R: SÍ. No se puede borrar una tabla padre si existen tablas hijas con FK apuntando a ella.
   Se debe usar DROP TABLE nombre CASCADE CONSTRAINTS o borrar en orden inverso (Hijos -> Padres).
*/
DROP TABLE INFORMACION_UNIVERSITARIA;
DROP VIEW INFORMACION_ACTUAL;
DROP VIEW INFORMACION_EMPLEADOS;
DROP VIEW NOMBRE_EMPLEADOS;
-- El resto de drops está al inicio del script.
