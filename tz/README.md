otus_tz
---------------------------------------------------------

Структуру и данные набил в докере.

См. init.sql

Исходил из того, что флаг invoice.full_paid ставится только при счёте на полную оплату (не частичную, даже если это последняя часть), что в поле invoice.discount лежит скидка в деньгах, не в процентах (то есть оплаченная часть равна discount + amount).

Таким образом, признак полной оплаты - сумма invoice.discount + invoice.amount по всем (со статусом 'payed') счетам пользователя по группе должна быть не меньше, чем groups.price_full.

На таблицу `otus_tz`.`invoice` вешаю индекс на три поля, он при любом варианте запроса необходим:
ALTER TABLE `otus_tz`.`invoice` ADD INDEX `status_group_user` (`status`, `group_id`, `user_id`) USING BTREE;

Далее два варианта запроса, один с CTE, другой просто с derived.
EXPLAIN ANALYZE у них идентичный, но с CTE наверное лучше при необходимости повторного использования.

Запросы будут полегче, если нет необходимости выводить первую колонку и/или сортировать по TOTAL_USERS;

По поводу формирования первой колонки так же поднимается варнинг
"Setting user variables within expressions is deprecated and will be removed in a future release", с которым я сходу не соображу, что делать.


Запросы:

первый

```
SET @month_ago = NOW() - INTERVAL 1 MONTH;
SET @today = NOW();
SET @rownum = 0;
SELECT
  @rownum := @rownum + 1 AS `N`,
  der2.`TITLE`,
  der2.`PERCENT`,
  der2.`TOTAL_USERS`
FROM
  (SELECT @rownum:=0) t,
  (
    with der1 AS (
      SELECT
        grp.title,
        invc.group_id,
        invc.user_id,
        /*SUM((invc.amount + invc.discount)) as paid_sum,*/
        /*grp.price_full,*/
        SUM((invc.amount + invc.discount)) >= grp.price_full as payed_full
      FROM
        otus_tz.invoice invc FORCE INDEX (status_group_user)
        INNER JOIN otus_tz.`groups` grp ON (grp.id = invc.group_id)
      WHERE
        invc.`status` = 'payed'
        AND grp.start_date < @month_ago
        /*AND grp.finish_date > @today*/
      GROUP BY invc.group_id, invc.user_id
      ORDER BY NULL
    )
    SELECT
      /*group_id,*/
      title AS `TITLE`,
      /*sum(payed_full) as pf,*/
      round((sum(payed_full)/count(user_id) * 100), 2) as `PERCENT`,
      count(user_id) as `TOTAL_USERS`
    FROM
      der1
    GROUP BY
      group_id
    ORDER BY
      `TOTAL_USERS` DESC
  ) as der2
;
```

второй тот же по сути

```
SET @month_ago = NOW() - INTERVAL 1 MONTH;
SET @today = NOW();
SET @rownum = 0;
SELECT
  @rownum := @rownum + 1 AS `N`,
  der2.`TITLE`,
  der2.`PERCENT`,
  der2.`TOTAL_USERS`
FROM
  (SELECT @rownum:=0) t,
  (
    SELECT
      /*der1.group_id,*/
      der1.title AS `TITLE`,
      /*sum(der1.payed_full) as pf,*/
      round((sum(der1.payed_full)/count(der1.user_id) * 100), 2) as `PERCENT`,
      count(der1.user_id) as `TOTAL_USERS`
    FROM
      (
        SELECT
          grp.title,
          invc.group_id,
          invc.user_id,
          /*SUM((invc.amount + invc.discount)) as paid_sum,*/
          /*grp.price_full,*/
          SUM((invc.amount + invc.discount)) >= grp.price_full as payed_full
        FROM
          otus_tz.invoice invc FORCE INDEX (status_group_user)
          INNER JOIN otus_tz.`groups` grp ON (grp.id = invc.group_id)
        WHERE
          invc.`status` = 'payed'
          AND grp.start_date < @month_ago
          /*AND grp.finish_date > @today*/
        GROUP BY invc.group_id, invc.user_id
        ORDER BY NULL
      ) as der1
    GROUP BY
      der1.group_id
    ORDER BY
      `TOTAL_USERS` DESC
  ) as der2
;
```


Докер:

```
$ docker-compose up otus_tz
```

```
$ docker-compose exec otus_tz /bin/sh
# mysql -uroot
mysql> show tables in otus_tz;
+-------------------+
| Tables_in_otus_tz |
+-------------------+
| courses           |
| groups            |
| invoice           |
| users             |
+-------------------+
4 rows in set (0.00 sec)

mysql> use otus_tz;

mysql> select count(1) from invoice;
+----------+
| count(1) |
+----------+
|    38925 |
+----------+
1 row in set (0.01 sec)

mysql> select * from invoice order by rand()  limit 10;
+-------+---------+--------+--------+-----------+----------+-----------+----------+
| id    | user_id | amount | status | full_paid | discount | course_id | group_id |
+-------+---------+--------+--------+-----------+----------+-----------+----------+
| 33896 |     430 |  10000 | payed  |         0 |     2000 |        35 |      197 |
| 36212 |     467 |  10000 | payed  |         0 |     2000 |        36 |      210 |
| 12160 |     687 |  10000 | payed  |         0 |     2000 |         8 |       73 |
|  8036 |     488 |  10000 | payed  |         0 |     2000 |         5 |       47 |
| 25393 |     732 |  10000 | payed  |         0 |     2000 |        23 |      143 |
| 38499 |     196 |  10000 | payed  |         0 |     2000 |        36 |      222 |
| 19153 |     306 |  10000 | payed  |         0 |     2000 |        21 |      108 |
|  4661 |      13 |  10000 | payed  |         0 |     2000 |         3 |       29 |
| 30611 |     314 |  50000 | payed  |         1 |    10000 |        33 |      177 |
|  2707 |     498 |  10000 |        |         0 |     2000 |         1 |       16 |
+-------+---------+--------+--------+-----------+----------+-----------+----------+
10 rows in set (0.02 sec)

mysql> select * from `groups` order by rand()  limit 10;
+-----+-----------+-------------------------+---------+------------+-------------+------------+-------------+
| id  | course_id | title                   | enabled | price_full | price_month | start_date | finish_date |
+-----+-----------+-------------------------+---------+------------+-------------+------------+-------------+
| 172 |        27 | Scala-2020-05           |       1 |      60000 |       12000 | 2020-05-01 | 2020-09-28  |
| 120 |        22 | AdvancedAndroid-2019-05 |       1 |      60000 |       12000 | 2019-05-01 | 2019-09-28  |
|  90 |        11 | Vue-2020-03             |       1 |      60000 |       12000 | 2020-03-01 | 2020-07-28  |
| 190 |        33 | TeamLead2-2021-03       |       1 |      60000 |       12000 | 2021-03-01 | 2021-07-28  |
|  67 |         8 | ReactJs-2018-04         |       1 |      60000 |       12000 | 2018-04-01 | 2018-08-28  |
|  53 |         7 | UnityGames-2019-02      |       1 |      60000 |       12000 | 2019-02-01 | 2019-06-28  |
| 147 |        25 | Php-2018-04             |       1 |      60000 |       12000 | 2018-04-01 | 2018-08-28  |
| 218 |        36 | PostgresQL-2020-03      |       1 |      60000 |       12000 | 2020-03-01 | 2020-07-28  |
|  33 |         5 | ArchSoftware-2018-02    |       1 |      60000 |       12000 | 2018-02-01 | 2018-06-28  |
| 146 |        25 | Php-2018-03             |       1 |      60000 |       12000 | 2018-03-01 | 2018-07-28  |
+-----+-----------+-------------------------+---------+------------+-------------+------------+-------------+
10 rows in set (0.00 sec)
```


```
mysql> SET @month_ago = NOW() - INTERVAL 1 MONTH;
Query OK, 0 rows affected (0.00 sec)

mysql> SET @today = NOW();
Query OK, 0 rows affected (0.00 sec)

mysql> SET @rownum = 0;
Query OK, 0 rows affected (0.01 sec)

mysql> SELECT
    ->   @rownum := @rownum + 1 AS `N`,
    ->   der2.`TITLE`,
    ->   der2.`PERCENT`,
    ->   der2.`TOTAL_USERS`
    -> FROM
    ->   (SELECT @rownum:=0) t,
    ->   (
    ->     with der1 AS (
    ->       SELECT
    ->         grp.title,
    ->         invc.group_id,
    ->         invc.user_id,
    ->         /*SUM((invc.amount + invc.discount)) as paid_sum,*/
    ->         /*grp.price_full,*/
    ->         SUM((invc.amount + invc.discount)) >= grp.price_full as payed_full
    ->       FROM
    ->         otus_tz.invoice invc FORCE INDEX (status_group_user)
    ->         INNER JOIN otus_tz.`groups` grp ON (grp.id = invc.group_id)
    ->       WHERE
    ->         invc.`status` = 'payed'
    ->         AND grp.start_date < @month_ago
    ->         /*AND grp.finish_date > @today*/
    ->       GROUP BY invc.group_id, invc.user_id
    ->       ORDER BY NULL
    ->     )
    ->     SELECT
    ->       /*group_id,*/
    ->       title AS `TITLE`,
    ->       /*sum(payed_full) as pf,*/
    ->       round((sum(payed_full)/count(user_id) * 100), 2) as `PERCENT`,
    ->       count(user_id) as `TOTAL_USERS`
    ->     FROM
    ->       der1
    ->     GROUP BY
    ->       group_id
    ->     ORDER BY
    ->       `TOTAL_USERS` DESC
    ->   ) as der2
    -> ;
+------+-------------------------+---------+-------------+
| N    | TITLE                   | PERCENT | TOTAL_USERS |
+------+-------------------------+---------+-------------+
|    1 | ReactJs-2020-02         |   56.52 |          92 |
|    2 | ReactJs-2018-03         |   40.70 |          86 |
|    3 | PostgresQL-2020-02      |   54.76 |          84 |
|    4 | JavaScript-2019-02      |   75.00 |          80 |
|    5 | Golang-2019-04          |   44.87 |          78 |
|    6 | PostgresQL-2019-04      |   59.74 |          77 |
|    7 | Php-2018-02             |   43.42 |          76 |
|    8 | PostgresQL-2018-03      |   45.33 |          75 |
|    9 | JavaScript-2020-04      |   44.59 |          74 |
|   10 | Php-2018-05             |   43.24 |          74 |
|   11 | Golang-2018-02          |   32.43 |          74 |
|   12 | ReactJs-2019-02         |   36.99 |          73 |
|   13 | JavaScript-2020-02      |   54.79 |          73 |
|   14 | TeamLead2-2020-02       |   57.53 |          73 |
|   15 | Patterns-2019-05        |   44.44 |          72 |
|   16 | TeamLead2-2019-05       |   63.89 |          72 |
|   17 | ArchSoftware-2020-05    |   49.30 |          71 |
|   18 | Vue-2019-05             |   42.25 |          71 |
|   19 | JavaScript-2018-04      |   47.89 |          71 |
|   20 | Java-2019-04            |   43.66 |          71 |
|   21 | Php-2020-04             |   36.62 |          71 |
|   22 | Scala-2018-05           |   71.83 |          71 |
|   23 | ArchSoftware-2018-02    |   36.23 |          69 |
|   24 | ArchSoftware-2018-03    |   56.52 |          69 |
|   25 | Scala-2018-04           |   37.68 |          69 |
|   26 | Golang-2019-02          |   52.17 |          69 |
|   27 | Golang-2020-02          |   62.32 |          69 |
|   28 | Patterns-2019-02        |   57.35 |          68 |
|   29 | AdvancedAndroid-2019-04 |   35.29 |          68 |
|   30 | Php-2020-03             |   47.06 |          68 |
|   31 | TeamLead2-2020-04       |   47.06 |          68 |
|   32 | Golang-2020-03          |   64.71 |          68 |
|   33 | ArchHighload-2020-05    |   56.72 |          67 |
|   34 | ArchHighload-2018-04    |   54.55 |          66 |
|   35 | Scala-2019-04           |   57.58 |          66 |
|   36 | PostgresQL-2019-05      |   42.42 |          66 |
|   37 | Patterns-2019-03        |   43.08 |          65 |
|   38 | UnityGames-2019-02      |   54.69 |          64 |
|   39 | UnityGames-2019-04      |   70.31 |          64 |
|   40 | ReactJs-2019-03         |   43.75 |          64 |
|   41 | JavaScript-2018-02      |   44.44 |          63 |
|   42 | AdvancedAndroid-2020-03 |   55.56 |          63 |
|   43 | Php-2019-03             |   52.38 |          63 |
|   44 | ArchSoftware-2020-02    |   66.13 |          62 |
|   45 | Java-2018-05            |   54.84 |          62 |
|   46 | Patterns-2020-04        |   55.74 |          61 |
|   47 | Patterns-2018-03        |   35.00 |          60 |
|   48 | UnityGames-2019-05      |   38.33 |          60 |
|   49 | Vue-2020-04             |   56.67 |          60 |
|   50 | TeamLead2-2019-04       |   46.67 |          60 |
|   51 | ArchSoftware-2019-04    |   63.79 |          58 |
|   52 | Vue-2019-02             |   60.34 |          58 |
|   53 | Php-2018-04             |   56.90 |          58 |
|   54 | ArchHighload-2020-02    |   63.16 |          57 |
|   55 | UnityGames-2020-03      |   32.14 |          56 |
|   56 | Vue-2018-02             |   53.57 |          56 |
|   57 | UnityGames-2019-03      |   47.27 |          55 |
|   58 | UnityGames-2020-05      |   47.27 |          55 |
|   59 | JavaScript-2018-05      |   67.27 |          55 |
|   60 | Java-2018-02            |   56.36 |          55 |
|   61 | Scala-2020-04           |   49.09 |          55 |
|   62 | ReactJs-2020-04         |   53.70 |          54 |
|   63 | AdvancedAndroid-2019-02 |   42.59 |          54 |
|   64 | Scala-2020-03           |   51.85 |          54 |
|   65 | Vue-2020-03             |   49.06 |          53 |
|   66 | TeamLead2-2018-03       |   33.96 |          53 |
|   67 | Golang-2020-05          |   52.83 |          53 |
|   68 | ArchHighload-2018-02    |   65.38 |          52 |
|   69 | ArchHighload-2019-04    |   40.38 |          52 |
|   70 | ReactJs-2020-05         |   57.69 |          52 |
|   71 | AdvancedAndroid-2018-02 |   38.46 |          52 |
|   72 | Php-2019-02             |   46.15 |          52 |
|   73 | ArchSoftware-2018-04    |   52.94 |          51 |
|   74 | JavaScript-2019-04      |   58.82 |          51 |
|   75 | AdvancedAndroid-2019-03 |   45.10 |          51 |
|   76 | ArchSoftware-2019-02    |   50.00 |          50 |
|   77 | AdvancedAndroid-2018-03 |   54.00 |          50 |
|   78 | AdvancedAndroid-2018-04 |   50.00 |          50 |
|   79 | Java-2019-02            |   58.00 |          50 |
|   80 | TeamLead2-2018-04       |   44.00 |          50 |
|   81 | ArchSoftware-2018-05    |   42.86 |          49 |
|   82 | UnityGames-2018-05      |   44.90 |          49 |
|   83 | AdvancedAndroid-2020-04 |   40.82 |          49 |
|   84 | Golang-2019-05          |   40.82 |          49 |
|   85 | PostgresQL-2018-02      |   53.06 |          49 |
|   86 | Php-2018-03             |   50.00 |          48 |
|   87 | Golang-2018-05          |   35.42 |          48 |
|   88 | PostgresQL-2018-05      |   60.42 |          48 |
|   89 | PostgresQL-2020-05      |   70.83 |          48 |
|   90 | Vue-2020-02             |   57.45 |          47 |
|   91 | AdvancedAndroid-2020-05 |   51.06 |          47 |
|   92 | TeamLead2-2018-05       |   85.11 |          47 |
|   93 | Golang-2018-04          |   76.60 |          47 |
|   94 | Scala-2019-05           |   45.65 |          46 |
|   95 | ArchHighload-2018-05    |   68.89 |          45 |
|   96 | ArchSoftware-2020-03    |   35.56 |          45 |
|   97 | JavaScript-2019-03      |   60.00 |          45 |
|   98 | Php-2020-05             |   42.22 |          45 |
|   99 | Golang-2019-03          |   80.00 |          45 |
|  100 | Php-2020-02             |   61.36 |          44 |
|  101 | TeamLead2-2019-03       |   54.55 |          44 |
|  102 | Golang-2020-04          |   52.27 |          44 |
|  103 | UnityGames-2018-04      |   62.79 |          43 |
|  104 | ReactJs-2018-05         |   44.19 |          43 |
|  105 | JavaScript-2018-03      |   51.16 |          43 |
|  106 | Php-2019-05             |   53.49 |          43 |
|  107 | PostgresQL-2020-03      |   32.56 |          43 |
|  108 | ArchHighload-2019-03    |   57.14 |          42 |
|  109 | Vue-2018-03             |   61.90 |          42 |
|  110 | Java-2018-03            |   38.10 |          42 |
|  111 | Scala-2020-05           |   40.48 |          42 |
|  112 | ReactJs-2019-04         |   65.85 |          41 |
|  113 | ReactJs-2020-03         |   34.15 |          41 |
|  114 | Scala-2018-03           |   31.71 |          41 |
|  115 | Scala-2020-02           |   46.34 |          41 |
|  116 | Vue-2019-04             |   65.00 |          40 |
|  117 | TeamLead2-2020-03       |   50.00 |          40 |
|  118 | PostgresQL-2019-03      |   70.00 |          40 |
|  119 | Patterns-2018-02        |   51.28 |          39 |
|  120 | ArchSoftware-2019-03    |   25.64 |          39 |
|  121 | ReactJs-2018-04         |   48.72 |          39 |
|  122 | JavaScript-2020-03      |   25.64 |          39 |
|  123 | AdvancedAndroid-2018-05 |   53.85 |          39 |
|  124 | Patterns-2020-05        |   42.11 |          38 |
|  125 | ArchSoftware-2020-04    |   31.58 |          38 |
|  126 | Java-2020-02            |   63.16 |          38 |
|  127 | Patterns-2020-03        |   21.62 |          37 |
|  128 | UnityGames-2018-03      |   67.57 |          37 |
|  129 | UnityGames-2020-02      |   56.76 |          37 |
|  130 | Scala-2019-02           |   67.57 |          37 |
|  131 | Golang-2018-03          |   56.76 |          37 |
|  132 | PostgresQL-2018-04      |   62.16 |          37 |
|  133 | Patterns-2018-05        |   52.78 |          36 |
|  134 | ArchHighload-2020-03    |   72.22 |          36 |
|  135 | ReactJs-2019-05         |   50.00 |          36 |
|  136 | Vue-2019-03             |   77.78 |          36 |
|  137 | AdvancedAndroid-2019-05 |   47.22 |          36 |
|  138 | UnityGames-2020-04      |   40.00 |          35 |
|  139 | Vue-2018-05             |   42.86 |          35 |
|  140 | PostgresQL-2020-04      |   37.14 |          35 |
|  141 | Patterns-2018-04        |   58.82 |          34 |
|  142 | Vue-2020-05             |   29.41 |          34 |
|  143 | Java-2020-05            |   73.53 |          34 |
|  144 | Patterns-2019-04        |   60.61 |          33 |
|  145 | ArchHighload-2018-03    |   51.52 |          33 |
|  146 | ArchHighload-2020-04    |   42.42 |          33 |
|  147 | AdvancedAndroid-2020-02 |   42.42 |          33 |
|  148 | Java-2019-03            |   81.82 |          33 |
|  149 | Java-2020-03            |   21.21 |          33 |
|  150 | Php-2019-04             |   57.58 |          33 |
|  151 | JavaScript-2020-05      |   38.71 |          31 |
|  152 | Java-2020-04            |   25.81 |          31 |
|  153 | Java-2019-05            |   86.67 |          30 |
|  154 | ReactJs-2018-02         |   44.83 |          29 |
|  155 | Scala-2018-02           |   37.93 |          29 |
|  156 | TeamLead2-2019-02       |   48.28 |          29 |
|  157 | UnityGames-2018-02      |   39.29 |          28 |
|  158 | Vue-2018-04             |   14.29 |          28 |
|  159 | Scala-2019-03           |   28.57 |          28 |
|  160 | Patterns-2020-02        |   62.96 |          27 |
|  161 | ArchHighload-2019-02    |   34.62 |          26 |
|  162 | TeamLead2-2018-02       |   64.00 |          25 |
|  163 | TeamLead2-2020-05       |   29.17 |          24 |
|  164 | ArchSoftware-2019-05    |   40.91 |          22 |
|  165 | JavaScript-2019-05      |   36.36 |          22 |
|  166 | ArchHighload-2019-05    |   33.33 |          21 |
|  167 | Java-2018-04            |   76.19 |          21 |
|  168 | PostgresQL-2019-02      |   33.33 |          12 |
+------+-------------------------+---------+-------------+
168 rows in set, 2 warnings (0.05 sec)

mysql> show warnings;
+---------+------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Level   | Code | Message                                                                                                                                                                                              |
+---------+------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Warning | 1287 | Setting user variables within expressions is deprecated and will be removed in a future release. Consider alternatives: 'SET variable=expression, ...', or 'SELECT expression(s) INTO variables(s)'. |
| Warning | 1287 | Setting user variables within expressions is deprecated and will be removed in a future release. Consider alternatives: 'SET variable=expression, ...', or 'SELECT expression(s) INTO variables(s)'. |
+---------+------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
2 rows in set (0.00 sec)
```

```
mysql> SET @month_ago = NOW() - INTERVAL 1 MONTH;
Query OK, 0 rows affected (0.00 sec)

mysql> SET @today = NOW();
Query OK, 0 rows affected (0.00 sec)

mysql> SET @rownum = 0;
Query OK, 0 rows affected (0.01 sec)

mysql> SELECT
    ->   @rownum := @rownum + 1 AS `N`,
    ->   der2.`TITLE`,
    ->   der2.`PERCENT`,
    ->   der2.`TOTAL_USERS`
    -> FROM
    ->   (SELECT @rownum:=0) t,
    ->   (
    ->     SELECT
    ->       /*der1.group_id,*/
    ->       der1.title AS `TITLE`,
    ->       /*sum(der1.payed_full) as pf,*/
    ->       round((sum(der1.payed_full)/count(der1.user_id) * 100), 2) as `PERCENT`,
    ->       count(der1.user_id) as `TOTAL_USERS`
    ->     FROM
    ->       (
    ->         SELECT
    ->           grp.title,
    ->           invc.group_id,
    ->           invc.user_id,
    ->           /*SUM((invc.amount + invc.discount)) as paid_sum,*/
    ->           /*grp.price_full,*/
    ->           SUM((invc.amount + invc.discount)) >= grp.price_full as payed_full
    ->         FROM
    ->           otus_tz.invoice invc FORCE INDEX (status_group_user)
    ->           INNER JOIN otus_tz.`groups` grp ON (grp.id = invc.group_id)
    ->         WHERE
    ->           invc.`status` = 'payed'
    ->           AND grp.start_date < @month_ago
    ->           /*AND grp.finish_date > @today*/
    ->         GROUP BY invc.group_id, invc.user_id
    ->         ORDER BY NULL
    ->       ) as der1
    ->     GROUP BY
    ->       der1.group_id
    ->     ORDER BY
    ->       `TOTAL_USERS` DESC
    ->   ) as der2
    -> ;
+------+-------------------------+---------+-------------+
| N    | TITLE                   | PERCENT | TOTAL_USERS |
+------+-------------------------+---------+-------------+
|    1 | ReactJs-2020-02         |   56.52 |          92 |
|    2 | ReactJs-2018-03         |   40.70 |          86 |
|    3 | PostgresQL-2020-02      |   54.76 |          84 |
|    4 | JavaScript-2019-02      |   75.00 |          80 |
|    5 | Golang-2019-04          |   44.87 |          78 |
|    6 | PostgresQL-2019-04      |   59.74 |          77 |
|    7 | Php-2018-02             |   43.42 |          76 |
|    8 | PostgresQL-2018-03      |   45.33 |          75 |
|    9 | JavaScript-2020-04      |   44.59 |          74 |
|   10 | Php-2018-05             |   43.24 |          74 |
|   11 | Golang-2018-02          |   32.43 |          74 |
|   12 | ReactJs-2019-02         |   36.99 |          73 |
|   13 | JavaScript-2020-02      |   54.79 |          73 |
|   14 | TeamLead2-2020-02       |   57.53 |          73 |
|   15 | Patterns-2019-05        |   44.44 |          72 |
|   16 | TeamLead2-2019-05       |   63.89 |          72 |
|   17 | ArchSoftware-2020-05    |   49.30 |          71 |
|   18 | Vue-2019-05             |   42.25 |          71 |
|   19 | JavaScript-2018-04      |   47.89 |          71 |
|   20 | Java-2019-04            |   43.66 |          71 |
|   21 | Php-2020-04             |   36.62 |          71 |
|   22 | Scala-2018-05           |   71.83 |          71 |
|   23 | ArchSoftware-2018-02    |   36.23 |          69 |
|   24 | ArchSoftware-2018-03    |   56.52 |          69 |
|   25 | Scala-2018-04           |   37.68 |          69 |
|   26 | Golang-2019-02          |   52.17 |          69 |
|   27 | Golang-2020-02          |   62.32 |          69 |
|   28 | Patterns-2019-02        |   57.35 |          68 |
|   29 | AdvancedAndroid-2019-04 |   35.29 |          68 |
|   30 | Php-2020-03             |   47.06 |          68 |
|   31 | TeamLead2-2020-04       |   47.06 |          68 |
|   32 | Golang-2020-03          |   64.71 |          68 |
|   33 | ArchHighload-2020-05    |   56.72 |          67 |
|   34 | ArchHighload-2018-04    |   54.55 |          66 |
|   35 | Scala-2019-04           |   57.58 |          66 |
|   36 | PostgresQL-2019-05      |   42.42 |          66 |
|   37 | Patterns-2019-03        |   43.08 |          65 |
|   38 | UnityGames-2019-02      |   54.69 |          64 |
|   39 | UnityGames-2019-04      |   70.31 |          64 |
|   40 | ReactJs-2019-03         |   43.75 |          64 |
|   41 | JavaScript-2018-02      |   44.44 |          63 |
|   42 | AdvancedAndroid-2020-03 |   55.56 |          63 |
|   43 | Php-2019-03             |   52.38 |          63 |
|   44 | ArchSoftware-2020-02    |   66.13 |          62 |
|   45 | Java-2018-05            |   54.84 |          62 |
|   46 | Patterns-2020-04        |   55.74 |          61 |
|   47 | Patterns-2018-03        |   35.00 |          60 |
|   48 | UnityGames-2019-05      |   38.33 |          60 |
|   49 | Vue-2020-04             |   56.67 |          60 |
|   50 | TeamLead2-2019-04       |   46.67 |          60 |
|   51 | ArchSoftware-2019-04    |   63.79 |          58 |
|   52 | Vue-2019-02             |   60.34 |          58 |
|   53 | Php-2018-04             |   56.90 |          58 |
|   54 | ArchHighload-2020-02    |   63.16 |          57 |
|   55 | UnityGames-2020-03      |   32.14 |          56 |
|   56 | Vue-2018-02             |   53.57 |          56 |
|   57 | UnityGames-2019-03      |   47.27 |          55 |
|   58 | UnityGames-2020-05      |   47.27 |          55 |
|   59 | JavaScript-2018-05      |   67.27 |          55 |
|   60 | Java-2018-02            |   56.36 |          55 |
|   61 | Scala-2020-04           |   49.09 |          55 |
|   62 | ReactJs-2020-04         |   53.70 |          54 |
|   63 | AdvancedAndroid-2019-02 |   42.59 |          54 |
|   64 | Scala-2020-03           |   51.85 |          54 |
|   65 | Vue-2020-03             |   49.06 |          53 |
|   66 | TeamLead2-2018-03       |   33.96 |          53 |
|   67 | Golang-2020-05          |   52.83 |          53 |
|   68 | ArchHighload-2018-02    |   65.38 |          52 |
|   69 | ArchHighload-2019-04    |   40.38 |          52 |
|   70 | ReactJs-2020-05         |   57.69 |          52 |
|   71 | AdvancedAndroid-2018-02 |   38.46 |          52 |
|   72 | Php-2019-02             |   46.15 |          52 |
|   73 | ArchSoftware-2018-04    |   52.94 |          51 |
|   74 | JavaScript-2019-04      |   58.82 |          51 |
|   75 | AdvancedAndroid-2019-03 |   45.10 |          51 |
|   76 | ArchSoftware-2019-02    |   50.00 |          50 |
|   77 | AdvancedAndroid-2018-03 |   54.00 |          50 |
|   78 | AdvancedAndroid-2018-04 |   50.00 |          50 |
|   79 | Java-2019-02            |   58.00 |          50 |
|   80 | TeamLead2-2018-04       |   44.00 |          50 |
|   81 | ArchSoftware-2018-05    |   42.86 |          49 |
|   82 | UnityGames-2018-05      |   44.90 |          49 |
|   83 | AdvancedAndroid-2020-04 |   40.82 |          49 |
|   84 | Golang-2019-05          |   40.82 |          49 |
|   85 | PostgresQL-2018-02      |   53.06 |          49 |
|   86 | Php-2018-03             |   50.00 |          48 |
|   87 | Golang-2018-05          |   35.42 |          48 |
|   88 | PostgresQL-2018-05      |   60.42 |          48 |
|   89 | PostgresQL-2020-05      |   70.83 |          48 |
|   90 | Vue-2020-02             |   57.45 |          47 |
|   91 | AdvancedAndroid-2020-05 |   51.06 |          47 |
|   92 | TeamLead2-2018-05       |   85.11 |          47 |
|   93 | Golang-2018-04          |   76.60 |          47 |
|   94 | Scala-2019-05           |   45.65 |          46 |
|   95 | ArchHighload-2018-05    |   68.89 |          45 |
|   96 | ArchSoftware-2020-03    |   35.56 |          45 |
|   97 | JavaScript-2019-03      |   60.00 |          45 |
|   98 | Php-2020-05             |   42.22 |          45 |
|   99 | Golang-2019-03          |   80.00 |          45 |
|  100 | Php-2020-02             |   61.36 |          44 |
|  101 | TeamLead2-2019-03       |   54.55 |          44 |
|  102 | Golang-2020-04          |   52.27 |          44 |
|  103 | UnityGames-2018-04      |   62.79 |          43 |
|  104 | ReactJs-2018-05         |   44.19 |          43 |
|  105 | JavaScript-2018-03      |   51.16 |          43 |
|  106 | Php-2019-05             |   53.49 |          43 |
|  107 | PostgresQL-2020-03      |   32.56 |          43 |
|  108 | ArchHighload-2019-03    |   57.14 |          42 |
|  109 | Vue-2018-03             |   61.90 |          42 |
|  110 | Java-2018-03            |   38.10 |          42 |
|  111 | Scala-2020-05           |   40.48 |          42 |
|  112 | ReactJs-2019-04         |   65.85 |          41 |
|  113 | ReactJs-2020-03         |   34.15 |          41 |
|  114 | Scala-2018-03           |   31.71 |          41 |
|  115 | Scala-2020-02           |   46.34 |          41 |
|  116 | Vue-2019-04             |   65.00 |          40 |
|  117 | TeamLead2-2020-03       |   50.00 |          40 |
|  118 | PostgresQL-2019-03      |   70.00 |          40 |
|  119 | Patterns-2018-02        |   51.28 |          39 |
|  120 | ArchSoftware-2019-03    |   25.64 |          39 |
|  121 | ReactJs-2018-04         |   48.72 |          39 |
|  122 | JavaScript-2020-03      |   25.64 |          39 |
|  123 | AdvancedAndroid-2018-05 |   53.85 |          39 |
|  124 | Patterns-2020-05        |   42.11 |          38 |
|  125 | ArchSoftware-2020-04    |   31.58 |          38 |
|  126 | Java-2020-02            |   63.16 |          38 |
|  127 | Patterns-2020-03        |   21.62 |          37 |
|  128 | UnityGames-2018-03      |   67.57 |          37 |
|  129 | UnityGames-2020-02      |   56.76 |          37 |
|  130 | Scala-2019-02           |   67.57 |          37 |
|  131 | Golang-2018-03          |   56.76 |          37 |
|  132 | PostgresQL-2018-04      |   62.16 |          37 |
|  133 | Patterns-2018-05        |   52.78 |          36 |
|  134 | ArchHighload-2020-03    |   72.22 |          36 |
|  135 | ReactJs-2019-05         |   50.00 |          36 |
|  136 | Vue-2019-03             |   77.78 |          36 |
|  137 | AdvancedAndroid-2019-05 |   47.22 |          36 |
|  138 | UnityGames-2020-04      |   40.00 |          35 |
|  139 | Vue-2018-05             |   42.86 |          35 |
|  140 | PostgresQL-2020-04      |   37.14 |          35 |
|  141 | Patterns-2018-04        |   58.82 |          34 |
|  142 | Vue-2020-05             |   29.41 |          34 |
|  143 | Java-2020-05            |   73.53 |          34 |
|  144 | Patterns-2019-04        |   60.61 |          33 |
|  145 | ArchHighload-2018-03    |   51.52 |          33 |
|  146 | ArchHighload-2020-04    |   42.42 |          33 |
|  147 | AdvancedAndroid-2020-02 |   42.42 |          33 |
|  148 | Java-2019-03            |   81.82 |          33 |
|  149 | Java-2020-03            |   21.21 |          33 |
|  150 | Php-2019-04             |   57.58 |          33 |
|  151 | JavaScript-2020-05      |   38.71 |          31 |
|  152 | Java-2020-04            |   25.81 |          31 |
|  153 | Java-2019-05            |   86.67 |          30 |
|  154 | ReactJs-2018-02         |   44.83 |          29 |
|  155 | Scala-2018-02           |   37.93 |          29 |
|  156 | TeamLead2-2019-02       |   48.28 |          29 |
|  157 | UnityGames-2018-02      |   39.29 |          28 |
|  158 | Vue-2018-04             |   14.29 |          28 |
|  159 | Scala-2019-03           |   28.57 |          28 |
|  160 | Patterns-2020-02        |   62.96 |          27 |
|  161 | ArchHighload-2019-02    |   34.62 |          26 |
|  162 | TeamLead2-2018-02       |   64.00 |          25 |
|  163 | TeamLead2-2020-05       |   29.17 |          24 |
|  164 | ArchSoftware-2019-05    |   40.91 |          22 |
|  165 | JavaScript-2019-05      |   36.36 |          22 |
|  166 | ArchHighload-2019-05    |   33.33 |          21 |
|  167 | Java-2018-04            |   76.19 |          21 |
|  168 | PostgresQL-2019-02      |   33.33 |          12 |
+------+-------------------------+---------+-------------+
168 rows in set, 2 warnings (0.05 sec)

mysql> SHOW WARNINGS;
+---------+------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Level   | Code | Message                                                                                                                                                                                              |
+---------+------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Warning | 1287 | Setting user variables within expressions is deprecated and will be removed in a future release. Consider alternatives: 'SET variable=expression, ...', or 'SELECT expression(s) INTO variables(s)'. |
| Warning | 1287 | Setting user variables within expressions is deprecated and will be removed in a future release. Consider alternatives: 'SET variable=expression, ...', or 'SELECT expression(s) INTO variables(s)'. |
+---------+------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
2 rows in set (0.00 sec)
```
