-- ============================================================
-- LAB: Paquetes y Disparadores
-- ALUMNO: AXEL ANDREE CUEVA ALCALA
-- CODIGO: 23200093
-- ============================================================

SET SERVEROUTPUT ON;
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';

-- ============================================================
-- 3.1  PAQUETE CRUD PARA EMPLOYEE + REPORTES SOLICITADOS
--      (usa HR.EMPLOYEES, JOBS, JOB_HISTORY, DEPARTMENTS,
--       LOCATIONS, COUNTRIES, REGIONS)
-- ============================================================

CREATE OR REPLACE PACKAGE emp_pkg AS
  -- CRUD básico
  PROCEDURE create_employee(
    p_employee_id   IN NUMBER,
    p_first_name    IN VARCHAR2,
    p_last_name     IN VARCHAR2,
    p_email         IN VARCHAR2,
    p_phone_number  IN VARCHAR2,
    p_hire_date     IN DATE,
    p_job_id        IN VARCHAR2,
    p_salary        IN NUMBER,
    p_commission    IN NUMBER DEFAULT NULL,
    p_manager_id    IN NUMBER DEFAULT NULL,
    p_department_id IN NUMBER
  );

  PROCEDURE get_employee(p_employee_id IN NUMBER, o_cur OUT SYS_REFCURSOR);

  PROCEDURE update_employee(
    p_employee_id   IN NUMBER,
    p_first_name    IN VARCHAR2 DEFAULT NULL,
    p_last_name     IN VARCHAR2 DEFAULT NULL,
    p_email         IN VARCHAR2 DEFAULT NULL,
    p_phone_number  IN VARCHAR2 DEFAULT NULL,
    p_job_id        IN VARCHAR2 DEFAULT NULL,
    p_salary        IN NUMBER   DEFAULT NULL,
    p_commission    IN NUMBER   DEFAULT NULL,
    p_manager_id    IN NUMBER   DEFAULT NULL,
    p_department_id IN NUMBER   DEFAULT NULL
  );

  PROCEDURE delete_employee(p_employee_id IN NUMBER);

  -- 3.1.1  Top 4 empleados que más han rotado de puesto
  PROCEDURE pr_top4_rotaciones(o_cur OUT SYS_REFCURSOR);

  -- 3.1.2  Resumen estadístico: promedio de contrataciones por MES (todas las anualidades)
  --         Devuelve un cursor (Mes, Promedio) y retorna #meses considerados (normalmente 12).
  FUNCTION fn_avg_hires_by_month(o_cur OUT SYS_REFCURSOR) RETURN NUMBER;

  -- 3.1.3  Gastos en salario y estadística por Región
  PROCEDURE pr_resumen_region(o_cur OUT SYS_REFCURSOR);

  -- 3.1.4  Tiempo de servicio y costo de vacaciones (1 año => 1 mes de vacaciones)
  --         Devuelve cursor con: emp_id, años_servicio, meses_vac, costo_vac
  --         y retorna el costo total (suma) como return de la función.
  FUNCTION fn_tiempo_servicio_y_vacaciones(o_cur OUT SYS_REFCURSOR) RETURN NUMBER;
END emp_pkg;
/

CREATE OR REPLACE PACKAGE BODY emp_pkg AS
  PROCEDURE create_employee(
    p_employee_id   IN NUMBER,
    p_first_name    IN VARCHAR2,
    p_last_name     IN VARCHAR2,
    p_email         IN VARCHAR2,
    p_phone_number  IN VARCHAR2,
    p_hire_date     IN DATE,
    p_job_id        IN VARCHAR2,
    p_salary        IN NUMBER,
    p_commission    IN NUMBER,
    p_manager_id    IN NUMBER,
    p_department_id IN NUMBER
  ) IS
  BEGIN
    INSERT INTO employees(employee_id, first_name, last_name, email, phone_number,
                          hire_date, job_id, salary, commission_pct, manager_id, department_id)
    VALUES(p_employee_id, p_first_name, p_last_name, p_email, p_phone_number,
           p_hire_date, p_job_id, p_salary, p_commission, p_manager_id, p_department_id);
  END;

  PROCEDURE get_employee(p_employee_id IN NUMBER, o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT e.*, j.job_title
      FROM employees e JOIN jobs j ON j.job_id = e.job_id
      WHERE e.employee_id = p_employee_id;
  END;

  PROCEDURE update_employee(
    p_employee_id   IN NUMBER,
    p_first_name    IN VARCHAR2,
    p_last_name     IN VARCHAR2,
    p_email         IN VARCHAR2,
    p_phone_number  IN VARCHAR2,
    p_job_id        IN VARCHAR2,
    p_salary        IN NUMBER,
    p_commission    IN NUMBER,
    p_manager_id    IN NUMBER,
    p_department_id IN NUMBER
  ) IS
  BEGIN
    UPDATE employees
       SET first_name    = COALESCE(p_first_name, first_name),
           last_name     = COALESCE(p_last_name,  last_name),
           email         = COALESCE(p_email,      email),
           phone_number  = COALESCE(p_phone_number, phone_number),
           job_id        = COALESCE(p_job_id,     job_id),
           salary        = COALESCE(p_salary,     salary),
           commission_pct= COALESCE(p_commission, commission_pct),
           manager_id    = COALESCE(p_manager_id, manager_id),
           department_id = COALESCE(p_department_id, department_id)
     WHERE employee_id = p_employee_id;
  END;

  PROCEDURE delete_employee(p_employee_id IN NUMBER) IS
  BEGIN
    DELETE FROM employees WHERE employee_id = p_employee_id;
  END;

  -- 3.1.1
  PROCEDURE pr_top4_rotaciones(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT *
      FROM (
        SELECT e.employee_id,
               e.last_name || ', ' || e.first_name AS empleado,
               e.job_id AS job_actual,
               j.job_title AS puesto_actual,
               NVL((SELECT COUNT(*) FROM job_history h WHERE h.employee_id = e.employee_id),0) AS cambios_puesto
        FROM employees e
        JOIN jobs j ON j.job_id = e.job_id
        ORDER BY cambios_puesto DESC, e.employee_id
      ) WHERE ROWNUM <= 4;
  END;

  -- 3.1.2
  FUNCTION fn_avg_hires_by_month(o_cur OUT SYS_REFCURSOR) RETURN NUMBER IS
    v_meses NUMBER;
  BEGIN
    OPEN o_cur FOR
      WITH hires AS (
        SELECT EXTRACT(YEAR FROM hire_date) AS y,
               EXTRACT(MONTH FROM hire_date) AS m
        FROM employees
      ),
      hires_by_month_year AS (
        SELECT m, y, COUNT(*) cnt
        FROM hires
        GROUP BY m, y
      ),
      avg_by_month AS (
        SELECT m,
               ROUND(AVG(cnt), 2) AS promedio_contrataciones
        FROM hires_by_month_year
        GROUP BY m
      )
      SELECT TO_CHAR(TO_DATE(m,'MM'),'Month', 'NLS_DATE_LANGUAGE=English') AS mes,
             promedio_contrataciones
      FROM avg_by_month
      ORDER BY m;

    SELECT COUNT(*) INTO v_meses FROM (
      SELECT DISTINCT EXTRACT(MONTH FROM hire_date) m FROM employees
    );
    RETURN v_meses;
  END;

  -- 3.1.3
  PROCEDURE pr_resumen_region(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT r.region_name,
             SUM(e.salary)                AS suma_salarios,
             COUNT(e.employee_id)         AS cant_empleados,
             MIN(e.hire_date)             AS fecha_ingreso_mas_antiguo
      FROM employees e
      JOIN departments d ON d.department_id = e.department_id
      JOIN locations   l ON l.location_id   = d.location_id
      JOIN countries   c ON c.country_id    = l.country_id
      JOIN regions     r ON r.region_id     = c.region_id
      GROUP BY r.region_name
      ORDER BY r.region_name;
  END;

  -- 3.1.4
  FUNCTION fn_tiempo_servicio_y_vacaciones(o_cur OUT SYS_REFCURSOR) RETURN NUMBER IS
    v_total NUMBER := 0;
  BEGIN
    OPEN o_cur FOR
      WITH svc AS (
        SELECT e.employee_id,
               FLOOR(MONTHS_BETWEEN(SYSDATE, e.hire_date)/12) AS anhos_servicio,
               e.salary
        FROM employees e
      )
      SELECT employee_id,
             anhos_servicio,
             anhos_servicio AS meses_vacaciones,
             ROUND( (salary/12) * anhos_servicio, 2) AS costo_vacaciones
      FROM svc;

    SELECT ROUND(SUM((salary/12) * FLOOR(MONTHS_BETWEEN(SYSDATE, hire_date)/12)),2)
    INTO v_total
    FROM employees;
    RETURN v_total;
  END;

END emp_pkg;
/

-- ============================================================
-- Tablas solicitadas para Horarios y Asistencias + inserts
-- ============================================================

BEGIN EXECUTE IMMEDIATE 'DROP TABLE Empleado_Horario'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Horario'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Asistencia_Empleado'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Horario: día_semana ['LUN','MAR','MIE','JUE','VIE','SAB','DOM'], turno ['M','T','N']
CREATE TABLE Horario (
  dia_semana   VARCHAR2(3)    NOT NULL,
  turno        VARCHAR2(1)    NOT NULL,
  hora_inicio  DATE           NOT NULL, -- usar solo componente hora
  hora_fin     DATE           NOT NULL,
  CONSTRAINT pk_horario PRIMARY KEY (dia_semana, turno),
  CONSTRAINT ck_hora CHECK (hora_fin > hora_inicio)
);

-- Asignación de horario a empleados
CREATE TABLE Empleado_Horario (
  employee_id  NUMBER         NOT NULL,
  dia_semana   VARCHAR2(3)    NOT NULL,
  turno        VARCHAR2(1)    NOT NULL,
  CONSTRAINT pk_emp_horario PRIMARY KEY(employee_id, dia_semana, turno),
  CONSTRAINT fk_emp_horario_emp FOREIGN KEY(employee_id) REFERENCES employees(employee_id),
  CONSTRAINT fk_emp_horario_hor FOREIGN KEY(dia_semana, turno) REFERENCES Horario(dia_semana, turno)
);

-- Registro real de asistencia
CREATE TABLE Asistencia_Empleado (
  employee_id      NUMBER       NOT NULL,
  dia_semana       VARCHAR2(3)  NOT NULL,
  fecha_real       DATE         NOT NULL,
  hora_inicio_real DATE         NOT NULL,
  hora_fin_real    DATE         NOT NULL,
  estado           CHAR(1)      DEFAULT 'P' CHECK (estado IN ('P','F')), -- P=Presente, F=Falta (3.4)
  CONSTRAINT pk_asistencia PRIMARY KEY (employee_id, fecha_real),
  CONSTRAINT fk_asistencia_emp FOREIGN KEY(employee_id) REFERENCES employees(employee_id)
);

-- Datos base: horarios
INSERT INTO Horario VALUES('LUN','M', TO_DATE('08:00','HH24:MI'), TO_DATE('12:00','HH24:MI'));
INSERT INTO Horario VALUES('LUN','T', TO_DATE('14:00','HH24:MI'), TO_DATE('18:00','HH24:MI'));
INSERT INTO Horario VALUES('MAR','M', TO_DATE('08:00','HH24:MI'), TO_DATE('12:00','HH24:MI'));
INSERT INTO Horario VALUES('MAR','T', TO_DATE('14:00','HH24:MI'), TO_DATE('18:00','HH24:MI'));
INSERT INTO Horario VALUES('MIE','M', TO_DATE('08:00','HH24:MI'), TO_DATE('12:00','HH24:MI'));
INSERT INTO Horario VALUES('JUE','M', TO_DATE('08:00','HH24:MI'), TO_DATE('12:00','HH24:MI'));
INSERT INTO Horario VALUES('VIE','M', TO_DATE('08:00','HH24:MI'), TO_DATE('12:00','HH24:MI'));
INSERT INTO Horario VALUES('VIE','T', TO_DATE('14:00','HH24:MI'), TO_DATE('17:00','HH24:MI'));
INSERT INTO Horario VALUES('SAB','M', TO_DATE('09:00','HH24:MI'), TO_DATE('13:00','HH24:MI'));
INSERT INTO Horario VALUES('DOM','M', TO_DATE('00:00','HH24:MI'), TO_DATE('00:00','HH24:MI')); -- sin turno real (placeholder)

-- Asignar a 3 empleados de ejemplo (ajusta IDs que existan en tu HR)
INSERT INTO Empleado_Horario VALUES(100,'LUN','M');
INSERT INTO Empleado_Horario VALUES(100,'MAR','M');
INSERT INTO Empleado_Horario VALUES(100,'MIE','M');
INSERT INTO Empleado_Horario VALUES(100,'JUE','M');
INSERT INTO Empleado_Horario VALUES(100,'VIE','T');

INSERT INTO Empleado_Horario VALUES(101,'LUN','M');
INSERT INTO Empleado_Horario VALUES(101,'MAR','T');
INSERT INTO Empleado_Horario VALUES(101,'VIE','M');

INSERT INTO Empleado_Horario VALUES(102,'LUN','M');
INSERT INTO Empleado_Horario VALUES(102,'MAR','M');
INSERT INTO Empleado_Horario VALUES(102,'MIE','M');
INSERT INTO Empleado_Horario VALUES(102,'JUE','M');
INSERT INTO Empleado_Horario VALUES(102,'VIE','M');

-- Asistencias (10+ filas)
INSERT INTO Asistencia_Empleado VALUES(100,'LUN', DATE '2025-09-01', TO_DATE('08:02','HH24:MI'), TO_DATE('12:01','HH24:MI'),'P');
INSERT INTO Asistencia_Empleado VALUES(100,'MAR', DATE '2025-09-02', TO_DATE('08:05','HH24:MI'), TO_DATE('11:55','HH24:MI'),'P');
INSERT INTO Asistencia_Empleado VALUES(100,'MIE', DATE '2025-09-03', TO_DATE('08:10','HH24:MI'), TO_DATE('12:00','HH24:MI'),'P');
INSERT INTO Asistencia_Empleado VALUES(100,'JUE', DATE '2025-09-04', TO_DATE('09:00','HH24:MI'), TO_DATE('12:00','HH24:MI'),'P'); -- tarde
INSERT INTO Asistencia_Empleado VALUES(100,'VIE', DATE '2025-09-05', TO_DATE('14:05','HH24:MI'), TO_DATE('17:00','HH24:MI'),'P');

INSERT INTO Asistencia_Empleado VALUES(101,'LUN', DATE '2025-09-01', TO_DATE('08:00','HH24:MI'), TO_DATE('12:00','HH24:MI'),'P');
INSERT INTO Asistencia_Empleado VALUES(101,'MAR', DATE '2025-09-02', TO_DATE('14:20','HH24:MI'), TO_DATE('18:00','HH24:MI'),'P');
INSERT INTO Asistencia_Empleado VALUES(101,'VIE', DATE '2025-09-05', TO_DATE('08:40','HH24:MI'), TO_DATE('12:00','HH24:MI'),'P');

INSERT INTO Asistencia_Empleado VALUES(102,'LUN', DATE '2025-09-01', TO_DATE('08:00','HH24:MI'), TO_DATE('12:00','HH24:MI'),'P');
INSERT INTO Asistencia_Empleado VALUES(102,'MAR', DATE '2025-09-02', TO_DATE('08:00','HH24:MI'), TO_DATE('12:00','HH24:MI'),'P');
INSERT INTO Asistencia_Empleado VALUES(102,'MIE', DATE '2025-09-03', TO_DATE('08:00','HH24:MI'), TO_DATE('11:45','HH24:MI'),'P');
COMMIT;

-- ============================================================
-- 3.1.5  FUNCIÓN: horas que labora un empleado en (mes, año)
-- ============================================================

CREATE OR REPLACE FUNCTION fn_horas_laboradas(p_emp_id NUMBER, p_mes NUMBER, p_anho NUMBER)
RETURN NUMBER
IS
  v_horas NUMBER := 0;
BEGIN
  SELECT NVL(SUM( (hora_fin_real - hora_inicio_real) * 24 ), 0)
    INTO v_horas
  FROM Asistencia_Empleado
  WHERE employee_id = p_emp_id
    AND EXTRACT(MONTH FROM fecha_real) = p_mes
    AND EXTRACT(YEAR  FROM fecha_real) = p_anho
    AND estado = 'P';

  RETURN ROUND(v_horas, 2);
END;
/

-- ============================================================
-- 3.1.6  FUNCIÓN: horas de falta en (mes, año) usando horario
--          (programadas - trabajadas, no negativa)
-- ============================================================

CREATE OR REPLACE FUNCTION fn_horas_falta(p_emp_id NUMBER, p_mes NUMBER, p_anho NUMBER)
RETURN NUMBER
IS
  v_faltas NUMBER := 0;

  -- horas programadas de un día según horario
  FUNCTION horas_programadas(p_dia VARCHAR2, p_turno VARCHAR2) RETURN NUMBER IS
    v NUMBER;
  BEGIN
    SELECT (hora_fin - hora_inicio) * 24 INTO v
    FROM Horario
    WHERE dia_semana = p_dia AND turno = p_turno;
    RETURN v;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN 0;
  END;

BEGIN
  FOR eh IN (
    SELECT dia_semana, turno
    FROM Empleado_Horario
    WHERE employee_id = p_emp_id
  ) LOOP
    DECLARE
      v_fecha DATE := TRUNC(TO_DATE(p_anho||'-'||p_mes||'-01','YYYY-MM-DD'));
      v_fin   DATE := ADD_MONTHS(v_fecha,1);
      v_prog  NUMBER := horas_programadas(eh.dia_semana, eh.turno);
      v_dow   VARCHAR2(3);
      v_work  NUMBER;
    BEGIN
      WHILE v_fecha < v_fin LOOP
        v_dow := CASE TO_CHAR(v_fecha,'D','NLS_DATE_LANGUAGE=English')
                   WHEN '2' THEN 'LUN' WHEN '3' THEN 'MAR' WHEN '4' THEN 'MIE'
                   WHEN '5' THEN 'JUE' WHEN '6' THEN 'VIE' WHEN '7' THEN 'SAB'
                   ELSE 'DOM'
                 END;

        IF v_dow = eh.dia_semana THEN
          SELECT NVL( MAX( (hora_fin_real - hora_inicio_real) * 24 ), 0 )
            INTO v_work
          FROM Asistencia_Empleado
          WHERE employee_id = p_emp_id
            AND TRUNC(fecha_real) = v_fecha
            AND estado = 'P';

          v_faltas := v_faltas + GREATEST(v_prog - v_work, 0);
        END IF;

        v_fecha := v_fecha + 1;
      END LOOP;
    END;
  END LOOP;

  RETURN ROUND(v_faltas,2);
END;
/

-- ============================================================
-- 3.1.7  PROCEDIMIENTO: cálculo de sueldo a pagar por mes/año
-- ============================================================

CREATE OR REPLACE PROCEDURE pr_sueldo_mensual(p_mes NUMBER, p_anho NUMBER, o_cur OUT SYS_REFCURSOR)
AS
BEGIN
  OPEN o_cur FOR
    WITH prog AS (
      SELECT eh.employee_id,
             SUM( (h.hora_fin - h.hora_inicio) * 24 *
                  (SELECT COUNT(*)
                     FROM (
                       SELECT TRUNC(TO_DATE(p_anho||'-'||p_mes||'-01','YYYY-MM-DD')) + LEVEL - 1 AS d
                       FROM dual
                       CONNECT BY LEVEL <= TO_NUMBER(TO_CHAR(LAST_DAY(TO_DATE(p_anho||'-'||p_mes||'-01','YYYY-MM-DD')),'DD'))
                     )
                     WHERE CASE TO_CHAR(d,'D','NLS_DATE_LANGUAGE=English')
                             WHEN '2' THEN 'LUN' WHEN '3' THEN 'MAR' WHEN '4' THEN 'MIE'
                             WHEN '5' THEN 'JUE' WHEN '6' THEN 'VIE' WHEN '7' THEN 'SAB'
                             ELSE 'DOM'
                           END = eh.dia_semana
                  )
                ) AS horas_prog
      FROM Empleado_Horario eh
      JOIN Horario h ON h.dia_semana = eh.dia_semana AND h.turno = eh.turno
      GROUP BY eh.employee_id
    ),
    work AS (
      SELECT employee_id,
             SUM( (hora_fin_real - hora_inicio_real) * 24 ) AS horas_trab
      FROM Asistencia_Empleado
      WHERE EXTRACT(MONTH FROM fecha_real) = p_mes
        AND EXTRACT(YEAR  FROM fecha_real) = p_anho
        AND estado = 'P'
      GROUP BY employee_id
    )
    SELECT e.employee_id,
           e.first_name, e.last_name,
           e.salary,
           NVL(w.horas_trab,0) AS horas_trab,
           NVL(p.horas_prog,0) AS horas_prog,
           CASE
             WHEN NVL(p.horas_prog,0) = 0 THEN 0
             ELSE ROUND(e.salary * (NVL(w.horas_trab,0)/p.horas_prog),2)
           END AS sueldo_mes
    FROM employees e
    LEFT JOIN prog p ON p.employee_id = e.employee_id
    LEFT JOIN work w ON w.employee_id = e.employee_id
    ORDER BY sueldo_mes DESC, e.employee_id;
END;
/

-- ============================================================
-- Tablas de Capacitaciones + inserts
-- ============================================================

BEGIN EXECUTE IMMEDIATE 'DROP TABLE EmpleadoCapacitacion'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Capacitacion'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE TABLE Capacitacion (
  cap_id        NUMBER       PRIMARY KEY,
  nombre        VARCHAR2(100) NOT NULL,
  horas         NUMBER         NOT NULL CHECK (horas > 0),
  descripcion   VARCHAR2(4000)
);

CREATE TABLE EmpleadoCapacitacion (
  employee_id   NUMBER NOT NULL REFERENCES employees(employee_id),
  cap_id        NUMBER NOT NULL REFERENCES Capacitacion(cap_id),
  CONSTRAINT pk_emp_cap PRIMARY KEY(employee_id, cap_id)
);

INSERT INTO Capacitacion VALUES (1,'Oracle SQL Básico',16,'Introducción a SQL y DDL/DML');
INSERT INTO Capacitacion VALUES (2,'PL/SQL Procedural',24,'Paquetes, funciones y triggers');
INSERT INTO Capacitacion VALUES (3,'Modelado ER',12,'Modelado de datos conceptual y lógico');
INSERT INTO Capacitacion VALUES (4,'Tuning SQL',20,'Optimización de consultas');
INSERT INTO Capacitacion VALUES (5,'Seguridad DB',10,'Roles, privilegios y auditoría');
INSERT INTO Capacitacion VALUES (6,'Admin Oracle',18,'Instalación y administración básica');
INSERT INTO Capacitacion VALUES (7,'Data Warehousing',14,'DW y ETL');
INSERT INTO Capacitacion VALUES (8,'Indexación Avanzada',8,'Estrategias de índices');
INSERT INTO Capacitacion VALUES (9,'Backup & Recovery',16,'RMAN y recuperación');
INSERT INTO Capacitacion VALUES (10,'JSON en Oracle',6,'Funciones JSON y SQL/JSON');

-- asignaciones a empleados 100..103 (ajusta a tus IDs)
INSERT INTO EmpleadoCapacitacion VALUES(100,1);
INSERT INTO EmpleadoCapacitacion VALUES(100,2);
INSERT INTO EmpleadoCapacitacion VALUES(100,4);
INSERT INTO EmpleadoCapacitacion VALUES(101,1);
INSERT INTO EmpleadoCapacitacion VALUES(101,3);
INSERT INTO EmpleadoCapacitacion VALUES(102,2);
INSERT INTO EmpleadoCapacitacion VALUES(102,5);
INSERT INTO EmpleadoCapacitacion VALUES(102,6);
INSERT INTO EmpleadoCapacitacion VALUES(103,7);
INSERT INTO EmpleadoCapacitacion VALUES(103,8);
COMMIT;

-- ============================================================
-- 3.(cap)  FUNCIONES/PROCS DE CAPACITACIÓN
-- 3.1.1  (sección Capacitaciones): horas totales por empleado
-- 3.1.2  (sección Capacitaciones): listar capacitaciones y empleados con total horas
-- ============================================================

CREATE OR REPLACE FUNCTION fn_horas_capacitacion_emp(p_emp_id NUMBER)
RETURN NUMBER
IS
  v_total NUMBER := 0;
BEGIN
  SELECT NVL(SUM(c.horas),0)
    INTO v_total
  FROM EmpleadoCapacitacion ec
  JOIN Capacitacion c ON c.cap_id = ec.cap_id
  WHERE ec.employee_id = p_emp_id;
  RETURN v_total;
END;
/

CREATE OR REPLACE PROCEDURE pr_listado_capacitaciones(o_cur OUT SYS_REFCURSOR)
AS
BEGIN
  OPEN o_cur FOR
    SELECT c.cap_id, c.nombre AS capacitacion,
           e.employee_id, e.first_name||' '||e.last_name AS empleado,
           c.horas,
           (SELECT SUM(c2.horas)
              FROM EmpleadoCapacitacion ec2
              JOIN Capacitacion c2 ON c2.cap_id = ec2.cap_id
             WHERE ec2.employee_id = e.employee_id) AS horas_tot_emp
    FROM Capacitacion c
    LEFT JOIN EmpleadoCapacitacion ec ON ec.cap_id = c.cap_id
    LEFT JOIN employees e ON e.employee_id = ec.employee_id
    ORDER BY NVL(horas_tot_emp,0) DESC, capacitacion, empleado;
END;
/

-- ============================================================
-- 3.2  TRIGGER: validar inserción de Asistencia_Empleado
-- ============================================================

CREATE OR REPLACE TRIGGER trg_asistencia_valida
BEFORE INSERT ON Asistencia_Empleado
FOR EACH ROW
DECLARE
  v_turno   VARCHAR2(1);
  v_hini    DATE;
  v_hfin    DATE;
  v_dow     VARCHAR2(3);
  FUNCTION dow(p_fecha DATE) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE TO_CHAR(p_fecha,'D','NLS_DATE_LANGUAGE=English')
             WHEN '2' THEN 'LUN' WHEN '3' THEN 'MAR' WHEN '4' THEN 'MIE'
             WHEN '5' THEN 'JUE' WHEN '6' THEN 'VIE' WHEN '7' THEN 'SAB'
             ELSE 'DOM'
           END;
  END;
BEGIN
  v_dow := dow(:NEW.fecha_real);
  IF :NEW.dia_semana <> v_dow THEN
    RAISE_APPLICATION_ERROR(-20050,'Día de la semana no coincide con la fecha.');
  END IF;

  SELECT eh.turno, h.hora_inicio, h.hora_fin
    INTO v_turno, v_hini, v_hfin
  FROM Empleado_Horario eh
  JOIN Horario h ON h.dia_semana = eh.dia_semana AND h.turno = eh.turno
  WHERE eh.employee_id = :NEW.employee_id
    AND eh.dia_semana = :NEW.dia_semana;

  IF NOT (:NEW.hora_inicio_real >= v_hini - INTERVAL '0' MINUTE AND :NEW.hora_inicio_real <= v_hfin)
  THEN
    RAISE_APPLICATION_ERROR(-20051,'Hora de inicio real fuera del rango del turno asignado.');
  END IF;

  IF NOT (:NEW.hora_fin_real >= v_hini AND :NEW.hora_fin_real <= v_hfin + INTERVAL '0' MINUTE)
  THEN
    RAISE_APPLICATION_ERROR(-20052,'Hora de término real fuera del rango del turno asignado.');
  END IF;
END;
/

-- ============================================================
-- 3.3  TRIGGER: validar salario esté dentro del min/max del JOB
-- ============================================================

CREATE OR REPLACE TRIGGER trg_salary_job_range
BEFORE INSERT OR UPDATE OF salary, job_id ON employees
FOR EACH ROW
DECLARE
  v_min NUMBER;
  v_max NUMBER;
BEGIN
  SELECT min_salary, max_salary INTO v_min, v_max
  FROM jobs WHERE job_id = :NEW.job_id;

  IF :NEW.salary < v_min OR :NEW.salary > v_max THEN
    RAISE_APPLICATION_ERROR(-20060,
      'Salario '||:NEW.salary||' fuera de rango ['||v_min||','||v_max||'] para el puesto '||:NEW.job_id);
  END IF;
END;
/

-- ============================================================
-- 3.4  TRIGGER: restringir ingreso a ±30 min de la hora exacta
-- ============================================================

CREATE OR REPLACE TRIGGER trg_asistencia_ventana_ingreso
BEFORE INSERT ON Asistencia_Empleado
FOR EACH ROW
DECLARE
  v_hini DATE;
  v_hfin DATE;
BEGIN
  SELECT h.hora_inicio, h.hora_fin
    INTO v_hini, v_hfin
  FROM Empleado_Horario eh
  JOIN Horario h ON h.dia_semana = eh.dia_semana AND h.turno = eh.turno
  WHERE eh.employee_id = :NEW.employee_id
    AND eh.dia_semana  = :NEW.dia_semana;

  IF :NEW.hora_inicio_real < (v_hini - INTERVAL '30' MINUTE)
     OR :NEW.hora_inicio_real > (v_hini + INTERVAL '30' MINUTE) THEN
    :NEW.estado := 'F';
    :NEW.hora_inicio_real := v_hini;
    :NEW.hora_fin_real    := v_hfin;
  END IF;
END;
/
