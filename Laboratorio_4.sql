-- ============================================================
-- LAB 04 - Procedimientos y Funciones
-- ============================================================

SET SERVEROUTPUT ON;

CREATE OR REPLACE PACKAGE lab04_api AS
  -- 4.1.1
  PROCEDURE pr_411_partes_color_ciudad_no_paris_peso_gt10(o_cur OUT SYS_REFCURSOR);

  -- 4.1.2
  PROCEDURE pr_412_partes_peso_gramos(o_cur OUT SYS_REFCURSOR);

  -- 4.1.3
  PROCEDURE pr_413_detalle_proveedores(o_cur OUT SYS_REFCURSOR);

  -- 4.1.4
  PROCEDURE pr_414_proveedor_parte_colocalizados(o_cur OUT SYS_REFCURSOR);

  -- 4.1.5
  PROCEDURE pr_415_pares_ciudades_prov_abastece_parte(o_cur OUT SYS_REFCURSOR);

  -- 4.1.6
  PROCEDURE pr_416_pares_proveedores_colocalizados(o_cur OUT SYS_REFCURSOR);

  -- 4.1.7
  FUNCTION  fn_417_total_proveedores RETURN NUMBER;

  -- 4.1.8
  PROCEDURE pr_418_min_max_qty_p2(o_min OUT NUMBER, o_max OUT NUMBER);

  -- 4.1.9
  PROCEDURE pr_419_total_despachado_por_parte(o_cur OUT SYS_REFCURSOR);

  -- 4.1.10
  PROCEDURE pr_4110_partes_con_mas_de_un_proveedor(o_cur OUT SYS_REFCURSOR);

  -- 4.1.11
  PROCEDURE pr_4111_proveedores_que_abastecen_p2(o_cur OUT SYS_REFCURSOR);

  -- 4.1.12
  PROCEDURE pr_4112_proveedores_que_abastecen_alguna_parte(o_cur OUT SYS_REFCURSOR);

  -- 4.1.13
  PROCEDURE pr_4113_proveedores_estado_menor_al_max(o_cur OUT SYS_REFCURSOR);

  -- 4.1.14 (usar EXISTS)
  PROCEDURE pr_4114_proveedores_que_abastecen_p2_exists(o_cur OUT SYS_REFCURSOR);

  -- 4.1.15
  PROCEDURE pr_4115_proveedores_que_no_abastecen_p2(o_cur OUT SYS_REFCURSOR);

  -- 4.1.16
  PROCEDURE pr_4116_proveedores_que_abastecen_todas_las_partes(o_cur OUT SYS_REFCURSOR);

  -- 4.1.17
  PROCEDURE pr_4117_partes_peso_gt16_o_abastecidas_por_s2(o_cur OUT SYS_REFCURSOR);
END lab04_api;
/

CREATE OR REPLACE PACKAGE BODY lab04_api AS

  -- 4.1.1: color y ciudad de partes NO París y peso > 10
  PROCEDURE pr_411_partes_color_ciudad_no_paris_peso_gt10(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT COLOR, CITY
      FROM P
      WHERE UPPER(CITY) <> 'PARIS'
        AND WEIGHT > 10;
  END;

  -- 4.1.2: número de parte y peso en gramos (1 lb = 453.59237 g)
  PROCEDURE pr_412_partes_peso_gramos(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT "P#" AS P_NUM,
             WEIGHT AS WEIGHT_LB,
             ROUND(WEIGHT * 453.59237, 2) AS WEIGHT_GR
      FROM P;
  END;

  -- 4.1.3: detalle completo de proveedores
  PROCEDURE pr_413_detalle_proveedores(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT "S#", SNAME, STATUS, CITY
      FROM S
      ORDER BY "S#";
  END;

  -- 4.1.4: combinaciones de proveedores y partes co-localizados
  PROCEDURE pr_414_proveedor_parte_colocalizados(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT s."S#", s.SNAME, p."P#", p.PNAME, s.CITY
      FROM S s
      JOIN P p ON UPPER(s.CITY) = UPPER(p.CITY)
      ORDER BY s."S#", p."P#";
  END;

  -- 4.1.5: pares de ciudades (ciudad proveedor, ciudad parte) donde proveedor abastece esa parte
  PROCEDURE pr_415_pares_ciudades_prov_abastece_parte(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT DISTINCT s.CITY AS CITY_SUPPLIER, p.CITY AS CITY_PART
      FROM SP sp
      JOIN S  s ON s."S#" = sp."S#"
      JOIN P  p ON p."P#" = sp."P#"
      ORDER BY s.CITY, p.CITY;
  END;

  -- 4.1.6: pares de números de proveedor co-localizados (sin duplicar pares)
  PROCEDURE pr_416_pares_proveedores_colocalizados(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT s1."S#" AS SUPPLIER1, s2."S#" AS SUPPLIER2, s1.CITY
      FROM S s1
      JOIN S s2
        ON UPPER(s1.CITY) = UPPER(s2.CITY)
       AND s1."S#" < s2."S#"
      ORDER BY s1.CITY, s1."S#", s2."S#";
  END;

  -- 4.1.7: número total de proveedores
  FUNCTION fn_417_total_proveedores RETURN NUMBER IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_cnt FROM S;
    RETURN v_cnt;
  END;

  -- 4.1.8: cantidad mínima y máxima para la parte P2
  PROCEDURE pr_418_min_max_qty_p2(o_min OUT NUMBER, o_max OUT NUMBER) IS
  BEGIN
    SELECT MIN(QTY), MAX(QTY) INTO o_min, o_max
    FROM SP
    WHERE "P#" = 'P2';
  END;

  -- 4.1.9: por cada parte abastecida, número de parte y total despachado
  PROCEDURE pr_419_total_despachado_por_parte(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT sp."P#" AS P_NUM, SUM(sp.QTY) AS TOTAL_QTY
      FROM SP sp
      GROUP BY sp."P#"
      ORDER BY sp."P#";
  END;

  -- 4.1.10: partes abastecidas por más de un proveedor
  PROCEDURE pr_4110_partes_con_mas_de_un_proveedor(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT sp."P#" AS P_NUM
      FROM SP sp
      GROUP BY sp."P#"
      HAVING COUNT(DISTINCT sp."S#") > 1
      ORDER BY sp."P#";
  END;

  -- 4.1.11: nombre de proveedores que abastecen la parte P2
  PROCEDURE pr_4111_proveedores_que_abastecen_p2(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT DISTINCT s.SNAME
      FROM S s
      JOIN SP sp ON sp."S#" = s."S#"
      WHERE sp."P#" = 'P2'
      ORDER BY s.SNAME;
  END;

  -- 4.1.12: nombre de proveedores que abastecen al menos una parte
  PROCEDURE pr_4112_proveedores_que_abastecen_alguna_parte(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT DISTINCT s.SNAME
      FROM S s
      WHERE EXISTS (
        SELECT 1 FROM SP sp WHERE sp."S#" = s."S#"
      )
      ORDER BY s.SNAME;
  END;

  -- 4.1.13: números de proveedor con STATUS menor al máximo STATUS
  PROCEDURE pr_4113_proveedores_estado_menor_al_max(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT "S#"
      FROM S
      WHERE STATUS < (SELECT MAX(STATUS) FROM S)
      ORDER BY "S#";
  END;

  -- 4.1.14: (EXISTS) nombre de proveedores que abastecen P2
  PROCEDURE pr_4114_proveedores_que_abastecen_p2_exists(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT s.SNAME
      FROM S s
      WHERE EXISTS (
        SELECT 1 FROM SP sp
        WHERE sp."S#" = s."S#" AND sp."P#" = 'P2'
      )
      ORDER BY s.SNAME;
  END;

  -- 4.1.15: nombre de proveedores que NO abastecen P2
  PROCEDURE pr_4115_proveedores_que_no_abastecen_p2(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT s.SNAME
      FROM S s
      WHERE NOT EXISTS (
        SELECT 1 FROM SP sp
        WHERE sp."S#" = s."S#" AND sp."P#" = 'P2'
      )
      ORDER BY s.SNAME;
  END;

  -- 4.1.16: proveedores que abastecen TODAS las partes (división relacional)
  PROCEDURE pr_4116_proveedores_que_abastecen_todas_las_partes(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT s.SNAME
      FROM S s
      WHERE NOT EXISTS (
        SELECT p."P#"
        FROM P p
        MINUS
        SELECT sp."P#"
        FROM SP sp
        WHERE sp."S#" = s."S#"
      )
      ORDER BY s.SNAME;
  END;

  -- 4.1.17: P# de partes con peso > 16 lbs OR abastecidas por S2 (o ambos)
  PROCEDURE pr_4117_partes_peso_gt16_o_abastecidas_por_s2(o_cur OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN o_cur FOR
      SELECT DISTINCT p."P#"
      FROM P p
      LEFT JOIN SP sp ON sp."P#" = p."P#"
      WHERE p.WEIGHT > 16
         OR (sp."S#" = 'S2')
      ORDER BY p."P#";
  END;

END lab04_api;
/
