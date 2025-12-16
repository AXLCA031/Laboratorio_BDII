-- ============================================================
-- LAB: Transacciones Relacional
-- ALUMNO: AXEL ANDREE CUEVA ALCALA
-- CODIGO: 23200093
-- ============================================================

-- Configuración para ver los mensajes de salida en la consola
SET SERVEROUTPUT ON;

-------------------------------------------------------------------------
-- 1. EJERCICIO 1 - Control Básico de Transacciones
[cite_start]-- Referencia: [cite: 154]
-------------------------------------------------------------------------
/*
   Instrucciones:
   - Aumentar 10% salario Dept 90.
   - Crear SAVEPOINT punto1.
   - Aumentar 5% salario Dept 60.
   - ROLLBACK a punto1.
   - COMMIT final.
*/

PROMPTEjecutando Ejercicio 1...;

BEGIN
    -- 1. Aumento del 10% al Dept 90
    UPDATE employees 
    SET salary = salary * 1.10 
    WHERE department_id = 90;
    
    DBMS_OUTPUT.PUT_LINE('-> Salarios del Dept 90 actualizados (+10%).');

    -- 2. Punto de guardado
    SAVEPOINT punto1;

    -- 3. Aumento del 5% al Dept 60
    UPDATE employees 
    SET salary = salary * 1.05 
    WHERE department_id = 60;
    
    DBMS_OUTPUT.PUT_LINE('-> Salarios del Dept 60 actualizados (+5%).');

    -- 4. Reversión parcial (deshace el cambio del Dept 60)
    ROLLBACK TO SAVEPOINT punto1;
    
    DBMS_OUTPUT.PUT_LINE('-> ROLLBACK ejecutado hacia punto1 (Cambios de Dept 60 deshechos).');

    -- 5. Confirmar transacción
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('-> Transacción confirmada (COMMIT).');
END;
/

/*
   RESPUESTAS EJERCICIO 1:
   -----------------------
   a. ¿Qué departamento mantuvo los cambios?
      R: El departamento 90. El COMMIT final guardó todo lo que estaba 
      [cite_start]vigente hasta el SAVEPOINT punto1[cite: 160].

   b. ¿Qué efecto tuvo el ROLLBACK parcial?
      R: Deshizo las operaciones realizadas después de definir el SAVEPOINT,
      [cite_start]es decir, canceló el aumento de salario del departamento 60[cite: 159].

   c. ¿Qué ocurriría si se ejecutara ROLLBACK sin especificar SAVEPOINT?
      R: Se desharían TODOS los cambios pendientes en la sesión actual 
      (tanto Dept 90 como Dept 60) [cite_start]y no se guardaría nada en la BD[cite: 164].
*/

-------------------------------------------------------------------------
-- 2. EJERCICIO 2 - Bloqueos entre Sesiones
[cite_start]-- Referencia: [cite: 165]
-------------------------------------------------------------------------
/*
   NOTA IMPORTANTE: 
   Este ejercicio requiere dos sesiones concurrentes. No se puede ejecutar
   automáticamente en un solo script lineal. A continuación se presentan 
   las instrucciones para replicarlo manualmente.
   
   --- SIMULACIÓN ---
   
   [SESIÓN 1]:
   UPDATE employees SET salary = salary + 500 WHERE employee_id = 103;
   -- (No hacer commit aún)

   [SESIÓN 2]:
   UPDATE employees SET salary = salary + 1000 WHERE employee_id = 103;
   -- (La sesión se quedará "colgada" o en espera)

   [SESIÓN 1]:
   ROLLBACK; 
   -- (Al ejecutar esto, la Sesión 2 se desbloquea y termina su tarea)
*/

/*
   RESPUESTAS EJERCICIO 2:
   -----------------------
   a. ¿Por qué la segunda sesión quedó bloqueada?
      R: Oracle usa bloqueos a nivel de fila (Row-Level Locking). La Sesión 1
      adquirió un bloqueo exclusivo (TX) sobre la fila del ID 103. La Sesión 2
      [cite_start]debe esperar a que la Sesión 1 libere ese recurso[cite: 172].

   b. ¿Qué comando libera los bloqueos?
      R: Los comandos COMMIT o ROLLBACK finalizan la transacción y liberan
      [cite_start]los recursos bloqueados[cite: 177].

   c. ¿Qué vistas del diccionario permiten verificar sesiones bloqueadas?
      [cite_start]R: V$LOCK, V$SESSION, V$SESSION_BLOCKERS, DBA_WAITERS[cite: 178].
*/

-------------------------------------------------------------------------
-- 3. EJERCICIO 3 - Transacción Controlada con Bloque PL/SQL
[cite_start]-- Referencia: [cite: 179]
-------------------------------------------------------------------------
/*
   Instrucciones:
   - Mover empleado 104 al Dept 110.
   - Insertar registro en JOB_HISTORY.
   - Usar manejo de excepciones para atomicidad.
*/

PROMPT Ejecutando Ejercicio 3...;

DECLARE
    v_emp_id    NUMBER := 104;
    v_new_dept  NUMBER := 110;
    -- Variables para obtener datos actuales antes de mover
    v_job_id    employees.job_id%TYPE;
    v_dept_id   employees.department_id%TYPE;
    v_hire_date employees.hire_date%TYPE;
BEGIN
    -- Obtener datos actuales
    SELECT job_id, department_id, hire_date 
    INTO v_job_id, v_dept_id, v_hire_date
    FROM employees 
    WHERE employee_id = v_emp_id;

    -- 1. Actualizar Departamento
    UPDATE employees 
    SET department_id = v_new_dept 
    WHERE employee_id = v_emp_id;

    -- 2. Insertar Historial (Simulando fin de periodo anterior hoy)
    INSERT INTO job_history (employee_id, start_date, end_date, job_id, department_id)
    VALUES (v_emp_id, v_hire_date, SYSDATE, v_job_id, v_dept_id);

    -- Confirmar si ambas operaciones tuvieron éxito
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('-> Transferencia y e historial registrados exitosamente.');

EXCEPTION
    WHEN OTHERS THEN
        -- Si falla algo (ej. Dept no existe), deshacer TODO
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('-> Error en la transacción: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('-> Se ejecutó ROLLBACK automático.');
END;
/

/*
   RESPUESTAS EJERCICIO 3:
   -----------------------
   a. ¿Por qué se debe garantizar la atomicidad entre las dos operaciones?
      R: Para mantener la integridad de los datos. No debe existir un cambio
      de departamento sin su rastro histórico. [cite_start]O suceden ambos, o ninguno[cite: 191].

   b. ¿Qué pasaría si se produce un error antes del COMMIT?
      R: El flujo salta al bloque EXCEPTION, donde el ROLLBACK deshace cualquier
      [cite_start]UPDATE o INSERT parcial realizado dentro del bloque PL/SQL[cite: 192].

   c. ¿Cómo se asegura la integridad entre EMPLOYEES y JOB_HISTORY?
      R: Mediante restricciones de clave foránea (Foreign Keys) en la BD y 
      mediante el control transaccional en el código que asegura que los datos
      [cite_start]no queden huérfanos[cite: 193].
*/

-------------------------------------------------------------------------
-- 4. EJERCICIO 4 - SAVEPOINT y Reversión Parcial
[cite_start]-- Referencia: [cite: 194]
-------------------------------------------------------------------------
/*
   Instrucciones:
   - Aumento 8% Dept 100 -> Savepoint A
   - Aumento 5% Dept 80  -> Savepoint B
   - Eliminar Dept 50
   - Rollback a Savepoint B
   - Commit
*/

PROMPT Ejecutando Ejercicio 4...;

BEGIN
    -- 1. Operación A
    UPDATE employees SET salary = salary * 1.08 WHERE department_id = 100;
    SAVEPOINT A;
    
    -- 2. Operación B
    UPDATE employees SET salary = salary * 1.05 WHERE department_id = 80;
    SAVEPOINT B;
    
    -- 3. Operación destructiva (Eliminar)
    DELETE FROM employees WHERE department_id = 50;
    DBMS_OUTPUT.PUT_LINE('-> Empleados del Dept 50 eliminados temporalmente.');
    
    -- 4. Revertir cambios hasta B (deshace el DELETE, mantiene updates)
    ROLLBACK TO SAVEPOINT B;
    DBMS_OUTPUT.PUT_LINE('-> Rollback a SAVEPOINT B ejecutado (Delete deshecho).');
    
    -- 5. Confirmar
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('-> Transacción final confirmada.');
END;
/

/*
   RESPUESTAS EJERCICIO 4:
   -----------------------
   a. ¿Qué cambios quedan persistentes?
      R: Quedan persistentes los aumentos de salario de los departamentos 100 y 80.
      [cite_start]El Delete fue revertido[cite: 202].

   b. ¿Qué sucede con las filas eliminadas?
      R: Son restauradas. Al hacer ROLLBACK TO SAVEPOINT B, la base de datos
      [cite_start]revierte la acción de borrado ocurrida después de ese punto[cite: 203].

   c. ¿Cómo puedes verificar los cambios antes y después del COMMIT?
      R: Antes del COMMIT, solo la sesión actual ve los cambios (lectura sucia no permitida
      a otros). [cite_start]Después del COMMIT, todas las sesiones ven los nuevos datos[cite: 204].
*/

PROMPT Fin del Laboratorio 06.;
