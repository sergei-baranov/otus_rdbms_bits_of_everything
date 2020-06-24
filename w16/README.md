ДЗ OTUS-RDBMS-2019-10 по занятию 16 - MySql: Оптимизация производительности. Профилирование. Мониторинг.
---------------------------------------------------------
Задача: Анализ и профилирование запроса. Проанализировать план выполнения запроса, оценить на чем теряется время. Попробовать оптимизировать запрос.
---------------------------------------------------------

# Table of Contents

1. [Запрос для резерча](#commondescr)
2. [Как я пытался добиться стратегии MERGE для LATERAL DERIVED TABLES](#try_merge)
3. [Почему это не получилось](#constructs_that_prevent_merging)
4. [Но что-то я выдумал побочно и что это дало](#json_table)
5. [Просто попробовать - OPTIMIZER_TRACE](#optimizer_trace)

## 1. Запрос для резерча <a name="commondescr"></a>

Вот тут - https://www.notion.so/38753f1d19724f12b66a0b5a8a70539a?v=4d42c9ac71014e31b80cae658e51ccac&p=f49be92b02f640878cec38c7e0b0b749 - я бегло оценивал разные варианты запросов для решения одной задачи и в итоге победил такой запрс:

```
SELECT t2.id_pe, t2.id FROM
(
  SELECT id_pe FROM `tsq`.`prices` PARTITION (p167) p1
  WHERE `id_pe` IN(
    16700001175, 16700002307, 16700006627, 16700007071, 16700007393, 16700007694, 16700010594, 16700011207,
    16700011208, 16700011226, 16700011240, 16700011253, 16700011264, 16700011312, 16700011315, 16700011323,
    16700011341, 16700011372, 16700011427, 16700011429, 16700011430, 16700011435, 16700011467, 16700011479,
    16700011495, 16700011499, 16700011500, 16700011503, 16700011504, 16700011505, 16700011517, 16700011519,
    16700011521, 16700011670, 16700011692, 16700011718, 16700011803, 16700011853, 16700011880, 16700011895,
    16700011939, 16700011956, 16700011962, 16700012012, 16700012037, 16700012041, 16700012053, 16700012227,
    16700012228, 16700012233, 16700012286, 16700012307, 16700012309, 16700012325, 16700012358, 16700012372,
    16700012373, 16700012404, 16700012405, 16700012407, 16700012420, 16700012436, 16700012480, 16700012483,
    16700012484, 16700012503, 16700012505, 16700012553, 16700012708, 16700012709, 16700012712, 16700012721,
    16700012771, 16700012802, 16700012811, 16700012820, 16700012850, 16700012881, 16700012883, 16700012884,
    16700012890, 16700012899, 16700012917, 16700012945, 16700012948, 16700013027, 16700013028, 16700013035,
    16700013036, 16700013088, 16700013100, 16700013103, 16700013106, 16700013261, 16700013276, 16700013277,
    16700013294, 16700013300, 16700013308, 16700013318, 16700013321, 16700013323, 16700013329, 16700013365,
    16700013368, 16700013382, 16700013404, 16700013406, 16700013411, 16700013452, 16700013475, 16700013476,
    16700013539, 16700013544, 16700013549, 16700013563, 16700013594, 16700013614, 16700013615, 16700013622,
    16700013637, 16700013638, 16700013642, 16700013648, 16700013662, 16700013675, 16700013677, 16700013679,
    16700013690, 16700013692, 16700013702, 16700013708, 16700013739, 16700013761, 16700013781, 16700013800,
    16700013803, 16700013820, 16700013826, 16700013827, 16700013960, 16700014037, 16700014053, 16700014055,
    16700014059, 16700014061, 16700014099
) GROUP BY id_pe) AS t1,
LATERAL (
  SELECT id_pe, id FROM `tsq`.`prices` PARTITION (p167) p2 FORCE INDEX (`id_pe_id`)
  WHERE p2.id_pe = t1.id_pe
  ORDER BY id_pe DESC, id DESC
  LIMIT 2
) AS t2;
```

Далее я решил посмотреть на него в Explain-е более пристально. Посмотрел. И увидел, что
lateral derived table отрабатывает по стратегии materialize и как следствие - происходит рематериазизация
на каждую строку outer-запроса.

```
EXPLAIN ...;
id|select_type      |table     |partitions|type |possible_keys |key     |key_len|ref     |rows|filtered|Extra                     |
--|-----------------|----------|----------|-----|--------------|--------|-------|--------|----|--------|--------------------------|
 1|PRIMARY          |<derived2>|          |ALL  |              |        |       |        |5298|   100.0|Rematerialize (<derived3>)|
 1|PRIMARY          |<derived3>|          |ALL  |              |        |       |        |   2|   100.0|                          |
 3|DEPENDENT DERIVED|p2        |p167      |ref  |id_pe_id      |id_pe_id|9      |t1.id_pe|  40|   100.0|Using index               |
 2|DERIVED          |p1        |p167      |range|id_pe_id,id_pe|id_pe   |9      |        |5298|   100.0|Using where; Using index  |
```

```
EXPLAIN format=json ...;

{
  "query_block": {
    "select_id": 1,
    "cost_info": {
      "query_cost": "15040.13"
    },
    "nested_loop": [
      {
        "table": {
          "table_name": "t1",
          "access_type": "ALL",
          "rows_examined_per_scan": 5298,
          "rows_produced_per_join": 5298,
          "filtered": "100.00",
          "rematerialize": "t2",
          "cost_info": {
            "read_cost": "68.72",
            "eval_cost": "529.80",
            "prefix_cost": "598.53",
            "data_read_per_join": "82K"
          },
...
          "materialized_from_subquery": {
            "using_temporary_table": true,
            "dependent": false,
            "cacheable": true,
            "query_block": {
              "select_id": 2,
              "cost_info": {
                "query_cost": "1062.92"
              },
...
```

```
EXPLAIN ANALIZE ...;

-> Nested loop inner join  (actual time=6.053..8.441 rows=281 loops=1)
    -> Invalidate materialized tables (row from t1)  (actual time=6.013..6.053 rows=147 loops=1)
        -> Table scan on t1  (actual time=0.002..0.016 rows=147 loops=1)
            -> Materialize  (actual time=6.012..6.040 rows=147 loops=1)
                -> Group (no aggregates)  (actual time=0.048..5.968 rows=147 loops=1)
                    -> Filter: (p1.id_pe in (16700001175,16700002307,...))  (cost=1062.93 rows=5298) (actual time=0.036..5.405 rows=5298 loops=1)
                        -> Index range scan on p1 using id_pe  (cost=1062.93 rows=5298) (actual time=0.033..4.332 rows=5298 loops=1)
    -> Table scan on t2  (actual time=0.000..0.000 rows=2 loops=147)
        -> Materialize (invalidate on row from t1)  (actual time=0.015..0.016 rows=2 loops=147)
            -> Limit: 2 row(s)  (actual time=0.004..0.005 rows=2 loops=147)
                -> Index lookup on p2 using id_pe_id (id_pe=t1.id_pe)  (cost=4.35 rows=41) (actual time=0.003..0.004 rows=2 loops=147)
```

И я подумал, что надо принудить его работать по стратегии merge


## 2. Как я пытался добиться стратегии MERGE для LATERAL DERIVED TABLES <a name="try_merge"></a>

#### 2.1. Сначала проверил глобальную настройку с опциями оптимизатора (optimizer_switch):

```
mysql> SELECT @@optimizer_switch\G;
*************************** 1. row ***************************
@@optimizer_switch: index_merge=on,index_merge_union=on,index_merge_sort_union=on,
index_merge_intersection=on,engine_condition_pushdown=on,index_condition_pushdown=on,
mrr=on,mrr_cost_based=on,block_nested_loop=on,batched_key_access=off,
materialization=on,semijoin=on,loosescan=on,firstmatch=on,duplicateweedout=on,
subquery_materialization_cost_based=on,use_index_extensions=on,condition_fanout_filter=on,
derived_merge=on,use_invisible_indexes=off,skip_scan=on,hash_join=on
```

derived_merge=on - убедились, что всё в порядке

#### 2.2. Далее я решил использовать хинты и пробовал запросы вида

```
SELECT /*+ MERGE(t2) */ t2.id_pe, t2.id FROM
(
  SELECT id_pe FROM `tsq`.`prices` PARTITION (p167) p1
  WHERE `id_pe` IN(
    16700001175, 16700002307 /* ... */
) GROUP BY id_pe) AS t1,
LATERAL (
  SELECT id_pe, id FROM `tsq`.`prices` PARTITION (p167) p2 FORCE INDEX (`id_pe_id`)
  WHERE p2.id_pe = t1.id_pe
  ORDER BY id_pe DESC, id DESC
  LIMIT 2
) AS t2;
```

но всё оставалось по-прежнему

## 3. Почему это не получилось <a name="constructs_that_prevent_merging"></a>

А потом я прочёл доку про ограничения применения merge-стратегии

https://dev.mysql.com/doc/refman/8.0/en/derived-table-optimization.html

И вроде я начал понимать, почему он упорно материализует - у него есть какие-то ограничения,
при которых он мерж не применяет:

    disable merging by using in the subquery any constructs that prevent merging:
    - Aggregate functions or window functions (SUM(), MIN(), MAX(), COUNT(), and so forth)
    - DISTINCT
    - GROUP BY
    - HAVING
    - LIMIT
    - UNION or UNION ALL
    - Subqueries in the select list
    - Assignments to user variables
    - Refererences only to literal values (in this case, there is no underlying table)

В частности, упомянуты GROUP BY и LIMIT, а GROUP BY и LIMIT - это про мои подзапросы :)

## 4. Но что-то я выдумал побочно и что это дало <a name="json_table"></a>

Пока я не узрел, что принудить оптимизатор к merge-у моих lateral derived запросов невозможно,
я пробовал какие-то варианты, и уже не помню, из каких соображений, попробовал вот такой:

```
SELECT t2.id_pe, t2.id FROM
JSON_TABLE(
  '[
  {"a": 16700001175}, {"a": 16700002307}, {"a": 16700006627}, {"a": 16700007071},
  {"a": 16700007393}, {"a": 16700007694}, {"a": 16700010594}, {"a": 16700011207},
  {"a": 16700011208}, {"a": 16700011226}, {"a": 16700011240}, {"a": 16700011253},
  {"a": 16700011264}, {"a": 16700011312}, {"a": 16700011315}, {"a": 16700011323},
  {"a": 16700011341}, {"a": 16700011372}, {"a": 16700011427}, {"a": 16700011429},
  {"a": 16700011430}, {"a": 16700011435}, {"a": 16700011467}, {"a": 16700011479},
  {"a": 16700011495}, {"a": 16700011499}, {"a": 16700011500}, {"a": 16700011503},
  {"a": 16700011504}, {"a": 16700011505}, {"a": 16700011517}, {"a": 16700011519},
  {"a": 16700011521}, {"a": 16700011670}, {"a": 16700011692}, {"a": 16700011718},
  {"a": 16700011803}, {"a": 16700011853}, {"a": 16700011880}, {"a": 16700011895},
  {"a": 16700011939}, {"a": 16700011956}, {"a": 16700011962}, {"a": 16700012012},
  {"a": 16700012037}, {"a": 16700012041}, {"a": 16700012053}, {"a": 16700012227},
  {"a": 16700012228}, {"a": 16700012233}, {"a": 16700012286}, {"a": 16700012307},
  {"a": 16700012309}, {"a": 16700012325}, {"a": 16700012358}, {"a": 16700012372},
  {"a": 16700012373}, {"a": 16700012404}, {"a": 16700012405}, {"a": 16700012407},
  {"a": 16700012420}, {"a": 16700012436}, {"a": 16700012480}, {"a": 16700012483},
  {"a": 16700012484}, {"a": 16700012503}, {"a": 16700012505}, {"a": 16700012553},
  {"a": 16700012708}, {"a": 16700012709}, {"a": 16700012712}, {"a": 16700012721},
  {"a": 16700012771}, {"a": 16700012802}, {"a": 16700012811}, {"a": 16700012820},
  {"a": 16700012850}, {"a": 16700012881}, {"a": 16700012883}, {"a": 16700012884},
  {"a": 16700012890}, {"a": 16700012899}, {"a": 16700012917}, {"a": 16700012945},
  {"a": 16700012948}, {"a": 16700013027}, {"a": 16700013028}, {"a": 16700013035},
  {"a": 16700013036}, {"a": 16700013088}, {"a": 16700013100}, {"a": 16700013103},
  {"a": 16700013106}, {"a": 16700013261}, {"a": 16700013276}, {"a": 16700013277},
  {"a": 16700013294}, {"a": 16700013300}, {"a": 16700013308}, {"a": 16700013318},
  {"a": 16700013321}, {"a": 16700013323}, {"a": 16700013329}, {"a": 16700013365},
  {"a": 16700013368}, {"a": 16700013382}, {"a": 16700013404}, {"a": 16700013406},
  {"a": 16700013411}, {"a": 16700013452}, {"a": 16700013475}, {"a": 16700013476},
  {"a": 16700013539}, {"a": 16700013544}, {"a": 16700013549}, {"a": 16700013563},
  {"a": 16700013594}, {"a": 16700013614}, {"a": 16700013615}, {"a": 16700013622},
  {"a": 16700013637}, {"a": 16700013638}, {"a": 16700013642}, {"a": 16700013648},
  {"a": 16700013662}, {"a": 16700013675}, {"a": 16700013677}, {"a": 16700013679},
  {"a": 16700013690}, {"a": 16700013692}, {"a": 16700013702}, {"a": 16700013708}, 
  {"a": 16700013739}, {"a": 16700013761}, {"a": 16700013781}, {"a": 16700013800},
  {"a": 16700013803}, {"a": 16700013820}, {"a": 16700013826}, {"a": 16700013827},
  {"a": 16700013960}, {"a": 16700014037}, {"a": 16700014053}, {"a": 16700014055},
  {"a": 16700014059}, {"a": 16700014061}, {"a": 16700014099}
  ]',
  '$[*]' COLUMNS(id_pe BIGINT PATH '$.a' ERROR ON ERROR )
) AS t0,
LATERAL (
  SELECT id_pe
  FROM `tsq`.`prices` PARTITION (p167) p1
  WHERE p1.id_pe = t0.id_pe
  GROUP BY id_pe
) AS t1,
LATERAL (
  SELECT id_pe, id
  FROM `tsq`.`prices` PARTITION (p167) p2 FORCE INDEX (`id_pe_id`)
  WHERE p2.id_pe = t1.id_pe
  ORDER BY id_pe DESC, id DESC
  LIMIT 2
) AS t2;
```

И он оказался быстрее при единичных тестах.

Тесты "детские" пока, но всё же бросается в глаза:

Много раз подряд исполняю запросы и после какого-то разогрева они выходят
на стабильные числа: 16..18 ms в изначальном варианте и 12..13 ms в варианте,
который начинает трип с json-таблицы.

Это 20-30% по времени исполнения (без реальной нагрузки на сервер).

Смотрим експлейны.

```
EXPLAIN ...;

id|select_type      |table     |partitions|type|possible_keys |key     |key_len|ref     |rows|filtered|Extra                                                                  |
--|-----------------|----------|----------|----|--------------|--------|-------|--------|----|--------|-----------------------------------------------------------------------|
 1|PRIMARY          |t0        |          |ALL |              |        |       |        |   2|   100.0|Table function: json_table; Using temporary; Rematerialize (<derived2>)|
 1|PRIMARY          |<derived2>|          |ALL |              |        |       |        |  39|   100.0|Rematerialize (<derived3>)                                             |
 1|PRIMARY          |<derived3>|          |ALL |              |        |       |        |   2|   100.0|                                                                       |
 3|DEPENDENT DERIVED|p2        |p167      |ref |id_pe_id      |id_pe_id|9      |t1.id_pe|  40|   100.0|Using index                                                            |
 2|DEPENDENT DERIVED|p1        |p167      |ref |id_pe_id,id_pe|id_pe   |9      |t0.id_pe|  39|   100.0|Using where; Using index                                               |
```

```
EXPLAIN ANALIZE ...;

-> Nested loop inner join  (actual time=0.217..10.786 rows=281 loops=1)
    -> Nested loop inner join  (actual time=0.199..7.935 rows=147 loops=1)
        -> Invalidate materialized tables (row from t0)  (actual time=0.144..0.199 rows=147 loops=1)
            -> Materialize table function  (actual time=0.143..0.179 rows=147 loops=1)
        -> Invalidate materialized tables (row from t1)  (actual time=0.052..0.052 rows=1 loops=147)
            -> Table scan on t1  (actual time=0.000..0.000 rows=1 loops=147)
                -> Materialize (invalidate on row from t0)  (actual time=0.052..0.052 rows=1 loops=147)
                    -> Group (no aggregates)  (actual time=0.039..0.039 rows=1 loops=147)
                        -> Filter: (p1.id_pe = t0.id_pe)  (cost=4.23 rows=40) (actual time=0.004..0.035 rows=36 loops=147)
                            -> Index lookup on p1 using id_pe (id_pe=t0.id_pe)  (cost=4.23 rows=40) (actual time=0.004..0.030 rows=36 loops=147)
    -> Table scan on t2  (actual time=0.000..0.000 rows=2 loops=147)
        -> Materialize (invalidate on row from t1)  (actual time=0.018..0.019 rows=2 loops=147)
            -> Limit: 2 row(s)  (actual time=0.005..0.006 rows=2 loops=147)
                -> Index lookup on p2 using id_pe_id (id_pe=t1.id_pe)  (cost=4.35 rows=41) (actual time=0.005..0.006 rows=2 loops=147)
```

```
EXPLAIN format=json ...;

{
"query_block": {
"select_id": 1,
"cost_info": {
  "query_cost": "241.73"
},
"nested_loop": [
{"table": {
  "table_name": "t0", "access_type": "ALL",
  "rows_examined_per_scan": 2,
  "rows_produced_per_join": 2,
  "filtered": "100.00",
  "table_function": "json_table",
  "using_temporary_table": true,
  "rematerialize": "t1",
  "cost_info": {
    "read_cost": "2.52",
    "eval_cost": "0.20",
    "prefix_cost": "2.73",
    "data_read_per_join": "32"
  },
  "used_columns": ["id_pe"]
}},
{"table": {
  "table_name": "t1", "access_type": "ALL",
  "rows_examined_per_scan": 39,
  "rows_produced_per_join": 78,
  "filtered": "100.00",
  "rematerialize": "t2",
  "cost_info": {
    "read_cost": "14.10",
    "eval_cost": "7.80",
    "prefix_cost": "24.63",
    "data_read_per_join": "1K"
  },
  "used_columns": ["id_pe"],
  "materialized_from_subquery": {
    "using_temporary_table": true,
    "dependent": true,
    "cacheable": true,
    "query_block": {
      "select_id": 2,
      "cost_info": {
        "query_cost": "4.23"
      },
      "grouping_operation": {
        "using_filesort": false,
        "table": {
          "table_name": "p1",
          "partitions": ["p167"],
          "access_type": "ref",
          "possible_keys": ["id_pe_id","id_pe"],
          "key": "id_pe",
          "used_key_parts": ["id_pe"],
          "key_length": "9",
          "ref": ["t0.id_pe"],
          "rows_examined_per_scan": 39,
          "rows_produced_per_join": 39,
          "filtered": "100.00",
          "using_index": true,
          "cost_info": {
            "read_cost": "0.27",
            "eval_cost": "3.96",
            "prefix_cost": "4.23",
            "data_read_per_join": "8K"
          },
          "used_columns": ["id","id_pe"],
          "attached_condition": "(`tsq`.`p1`.`id_pe` = `t0`.`id_pe`)"
        }
      }
    }
  }
}},
{"table": {
  "table_name": "t2", "access_type": "ALL",
  "rows_examined_per_scan": 2,
  "rows_produced_per_join": 156,
  "filtered": "100.00",
  "cost_info": {
    "read_cost": "201.50",
    "eval_cost": "15.60",
    "prefix_cost": "241.73",
    "data_read_per_join": "3K"
  },
  "used_columns": ["id_pe", "id"],
  "materialized_from_subquery": {
  "using_temporary_table": true,
  "dependent": true,
  "cacheable": true,
  "query_block": {
    "select_id": 3,
    "cost_info": {
      "query_cost": "4.35"
    },
    "ordering_operation": {
      "using_filesort": false,
      "table": {
        "table_name": "p2",
        "partitions": ["p167"],
        "access_type": "ref",
        "possible_keys": ["id_pe_id"],
        "key": "id_pe_id",
        "used_key_parts": ["id_pe"],
        "key_length": "9",
        "ref": ["t1.id_pe"],
        "rows_examined_per_scan": 40,
        "rows_produced_per_join": 40,
        "filtered": "100.00",
        "using_index": true,
        "cost_info": {
          "read_cost": "0.28",
          "eval_cost": "4.07",
          "prefix_cost": "4.35",
          "data_read_per_join": "8K"
        },
        "used_columns": ["id", "id_pe"]
      }}
    }}
}}]
}}
```

Что я вижу?

Материализаций и рематериализаций стало две вместо одной, НО -
существенно уменьшилось количество rows и (соответственно?) cost-ы.

У меня cost запроса упал с 15040 до 241-го попугая...

Видимо, две рематериализации на 2 и 39 outer-строк существенно экономичнее,
чем одна рематериализация на 5298 строк (то есть по сути 5298 рематериализаций).

Наверное это и дало прирост в скорости исполнения.

Вобщем-то это результат, хотя и.. случайный :)

## 5. Просто попробовать - OPTIMIZER_TRACE <a name="optimizer_trace"></a>

Делаю OPTIMIZER_TRACE на оба запроса и прикладываю результат файлами в эту репу рядом с README

Первый запрос:

```
mysql> SET OPTIMIZER_TRACE="enabled=on",END_MARKERS_IN_JSON=on;
Query OK, 0 rows affected (0,00 sec)

mysql> SET OPTIMIZER_TRACE_MAX_MEM_SIZE=1000000;
Query OK, 0 rows affected (0,00 sec)

mysql> SELECT t2.id_pe, t2.id FROM /* ... первый запрос ... */

+-------------+-------------------+
| id_pe       | id                |
+-------------+-------------------+
| 16700001175 | 16719042900001175 |
| 16700002307 | 16719090400002307 |
| 16700002307 | 16719090300002307 |
...
| 16700014099 | 16719050700014099 |
+-------------+-------------------+
281 rows in set (0,02 sec)

mysql> SELECT trace INTO DUMPFILE '/var/lib/mysql-files/querytrace_1' FROM INFORMATION_SCHEMA.OPTIMIZER_TRACE;
Query OK, 1 row affected (0,01 sec)

mysql> SET OPTIMIZER_TRACE="enabled=off";
Query OK, 0 rows affected (0,00 sec)
```

Получил файл querytrace_1, приложил к д/з.

Второй запрос:

```
mysql> SET OPTIMIZER_TRACE="enabled=on",END_MARKERS_IN_JSON=on;
Query OK, 0 rows affected (0,00 sec)

mysql> SET OPTIMIZER_TRACE_MAX_MEM_SIZE=1000000;
Query OK, 0 rows affected (0,00 sec)

mysql> SELECT t2.id_pe, t2.id FROM /* ... второй запрос ... */

+-------------+-------------------+
| id_pe       | id                |
+-------------+-------------------+
| 16700001175 | 16719042900001175 |
| 16700002307 | 16719090400002307 |
| 16700002307 | 16719090300002307 |
...
| 16700014099 | 16719050700014099 |
+-------------+-------------------+
281 rows in set (0,01 sec)


mysql> SELECT trace INTO DUMPFILE '/var/lib/mysql-files/querytrace_2' FROM INFORMATION_SCHEMA.OPTIMIZER_TRACE;
Query OK, 1 row affected (0,01 sec)

mysql> SET OPTIMIZER_TRACE="enabled=off";
Query OK, 0 rows affected (0,00 sec)
```

Ииииииии... он делает мне пустой trace.

```
mysql> SELECT * FROM INFORMATION_SCHEMA.OPTIMIZER_TRACE;
+-------+-------+-----------------------------------+-------------------------+
| QUERY | TRACE | MISSING_BYTES_BEYOND_MAX_MEM_SIZE | INSUFFICIENT_PRIVILEGES |
+-------+-------+-----------------------------------+-------------------------+
|       |       |                                 0 |                       1 |
+-------+-------+-----------------------------------+-------------------------+
1 row in set (0,00 sec)
```

Читаем доку:

    INSUFFICIENT_PRIVILEGES
    If a traced query uses views or stored routines that have SQL SECURITY with a value of DEFINER,
    it may be that a user other than the definer is denied from seeing the trace of the query.
    In that case, the trace is shown as empty and INSUFFICIENT_PRIVILEGES has a value of 1.
    Otherwise, the value is 0.
    
Но я же под root-ом? ...
Видимо, какие-то баги мускула по поводу JSON_TABLE и OPTIMIZER_TRACE.

Ну я погуглил, но ответа не нашёл (:
Почитал querytrace_1... интересно )).

На этом всё.
Надеюсь, достаточно для того, чтобы засчитать д/з.