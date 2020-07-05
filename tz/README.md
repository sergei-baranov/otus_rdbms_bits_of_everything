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

Запросы:

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
        SUM((invc.amount + invc.discount)) > grp.price_full as payed_full
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
      title AS 'TITLE',
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

тот же по сути

```
SET @month_ago = NOW() - INTERVAL 1 MONTH;
SET @today = NOW();
SET @rownum = 0;
EXPLAIN ANALYZE SELECT
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
          SUM((invc.amount + invc.discount)) > grp.price_full as payed_full
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
    ->         SUM((invc.amount + invc.discount)) > grp.price_full as payed_full
    ->       FROM
    ->         otus_tz.invoice invc FORCE INDEX (status_group_user)
    ->         INNER JOIN otus_tz.`groups` grp ON (grp.id = invc.group_id)
    ->       WHERE
    ->         invc.`status` = 'payed'
    ->         AND grp.start_date < @month_ago
    ->       GROUP BY invc.group_id, invc.user_id
    ->       ORDER BY NULL
    ->     )
    ->     SELECT
    ->       title AS 'TITLE',
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
|    1 | Patterns-2018-03        |   57.61 |          92 |
|    2 | ReactJs-2018-04         |   55.43 |          92 |
|    3 | TeamLead2-2019-02       |   54.35 |          92 |
|    4 | TeamLead2-2020-02       |   51.65 |          91 |
|    5 | Scala-2020-02           |   48.89 |          90 |
|    6 | Vue-2018-04             |   57.95 |          88 |
|    7 | Java-2020-03            |   48.86 |          88 |
|    8 | Java-2018-02            |   40.70 |          86 |
|    9 | Php-2018-04             |   53.49 |          86 |
|   10 | ArchHighload-2018-02    |   43.53 |          85 |
|   11 | TeamLead2-2018-05       |   37.65 |          85 |
|   12 | Scala-2018-02           |   54.22 |          83 |
|   13 | Golang-2019-03          |   63.41 |          82 |
|   14 | ArchHighload-2020-02    |   61.25 |          80 |
|   15 | UnityGames-2019-03      |   56.96 |          79 |
|   16 | JavaScript-2018-04      |   47.44 |          78 |
|   17 | ReactJs-2018-03         |   55.84 |          77 |
|   18 | AdvancedAndroid-2018-04 |   49.35 |          77 |
|   19 | AdvancedAndroid-2020-03 |   50.65 |          77 |
|   20 | Scala-2018-04           |   47.37 |          76 |
|   21 | UnityGames-2020-05      |   52.00 |          75 |
|   22 | ArchSoftware-2020-02    |   56.76 |          74 |
|   23 | JavaScript-2019-02      |   48.65 |          74 |
|   24 | PostgresQL-2018-02      |   54.79 |          73 |
|   25 | Patterns-2018-05        |   54.93 |          71 |
|   26 | Java-2020-02            |   59.15 |          71 |
|   27 | Golang-2018-04          |   61.97 |          71 |
|   28 | ArchHighload-2019-03    |   38.57 |          70 |
|   29 | UnityGames-2018-03      |   75.36 |          69 |
|   30 | Golang-2019-04          |   44.93 |          69 |
|   31 | ArchSoftware-2020-03    |   55.88 |          68 |
|   32 | TeamLead2-2018-02       |   55.88 |          68 |
|   33 | ArchHighload-2018-03    |   40.30 |          67 |
|   34 | AdvancedAndroid-2020-05 |   44.78 |          67 |
|   35 | Php-2019-04             |   29.85 |          67 |
|   36 | TeamLead2-2020-05       |   31.34 |          67 |
|   37 | ArchSoftware-2018-03    |   43.94 |          66 |
|   38 | UnityGames-2020-03      |   57.58 |          66 |
|   39 | Vue-2018-03             |   66.67 |          66 |
|   40 | Vue-2020-02             |   57.58 |          66 |
|   41 | AdvancedAndroid-2019-02 |   42.42 |          66 |
|   42 | Php-2019-05             |   57.58 |          66 |
|   43 | JavaScript-2020-04      |   64.62 |          65 |
|   44 | JavaScript-2020-05      |   50.77 |          65 |
|   45 | Php-2020-03             |   40.00 |          65 |
|   46 | UnityGames-2018-02      |   53.13 |          64 |
|   47 | JavaScript-2019-04      |   57.81 |          64 |
|   48 | Php-2018-03             |   37.50 |          64 |
|   49 | Golang-2018-03          |   48.44 |          64 |
|   50 | AdvancedAndroid-2018-03 |   66.67 |          63 |
|   51 | Golang-2018-05          |   49.21 |          63 |
|   52 | Golang-2020-03          |   47.62 |          63 |
|   53 | Golang-2020-05          |   58.73 |          63 |
|   54 | ArchSoftware-2018-05    |   58.06 |          62 |
|   55 | Java-2018-04            |   54.84 |          62 |
|   56 | Golang-2020-04          |   59.68 |          62 |
|   57 | ArchHighload-2019-05    |   29.51 |          61 |
|   58 | ArchSoftware-2019-03    |   47.54 |          61 |
|   59 | JavaScript-2019-03      |   32.79 |          61 |
|   60 | TeamLead2-2019-05       |   50.82 |          61 |
|   61 | Patterns-2019-05        |   46.67 |          60 |
|   62 | Golang-2020-02          |   31.67 |          60 |
|   63 | ReactJs-2019-05         |   55.93 |          59 |
|   64 | Vue-2019-04             |   33.90 |          59 |
|   65 | Golang-2018-02          |   54.24 |          59 |
|   66 | ArchHighload-2019-02    |   58.62 |          58 |
|   67 | UnityGames-2020-04      |   53.45 |          58 |
|   68 | AdvancedAndroid-2019-04 |   55.17 |          58 |
|   69 | AdvancedAndroid-2020-04 |   29.31 |          58 |
|   70 | Scala-2020-05           |   62.07 |          58 |
|   71 | Golang-2019-05          |   70.69 |          58 |
|   72 | Patterns-2019-04        |   33.33 |          57 |
|   73 | Patterns-2020-04        |   57.89 |          57 |
|   74 | Patterns-2020-05        |   57.89 |          57 |
|   75 | ReactJs-2019-03         |   40.35 |          57 |
|   76 | Vue-2018-02             |   43.86 |          57 |
|   77 | Vue-2019-02             |   57.89 |          57 |
|   78 | Php-2018-05             |   50.88 |          57 |
|   79 | TeamLead2-2019-04       |   59.65 |          57 |
|   80 | ArchHighload-2020-04    |   51.79 |          56 |
|   81 | ArchHighload-2020-05    |   57.41 |          54 |
|   82 | PostgresQL-2018-04      |   31.48 |          54 |
|   83 | PostgresQL-2020-02      |   64.81 |          54 |
|   84 | UnityGames-2019-04      |   15.09 |          53 |
|   85 | Scala-2020-03           |   52.83 |          53 |
|   86 | Patterns-2018-02        |   51.92 |          52 |
|   87 | JavaScript-2018-03      |   69.23 |          52 |
|   88 | AdvancedAndroid-2019-05 |   61.54 |          52 |
|   89 | TeamLead2-2020-04       |   39.22 |          51 |
|   90 | PostgresQL-2019-02      |   54.90 |          51 |
|   91 | Patterns-2019-02        |   50.00 |          50 |
|   92 | JavaScript-2020-03      |   46.00 |          50 |
|   93 | ArchHighload-2020-03    |   36.73 |          49 |
|   94 | Java-2020-04            |   55.10 |          49 |
|   95 | Php-2019-02             |   61.22 |          49 |
|   96 | Scala-2019-03           |   51.02 |          49 |
|   97 | ArchSoftware-2018-02    |   60.42 |          48 |
|   98 | ArchSoftware-2019-05    |   75.00 |          48 |
|   99 | AdvancedAndroid-2018-05 |   47.92 |          48 |
|  100 | Java-2019-02            |   33.33 |          48 |
|  101 | ReactJs-2018-05         |   70.21 |          47 |
|  102 | ReactJs-2019-02         |   70.21 |          47 |
|  103 | Scala-2018-03           |   65.96 |          47 |
|  104 | PostgresQL-2019-05      |   31.91 |          47 |
|  105 | ArchSoftware-2020-05    |   39.13 |          46 |
|  106 | Php-2020-02             |   35.56 |          45 |
|  107 | ArchSoftware-2020-04    |   56.82 |          44 |
|  108 | ReactJs-2020-03         |   47.73 |          44 |
|  109 | Vue-2019-03             |   13.64 |          44 |
|  110 | Vue-2019-05             |   56.82 |          44 |
|  111 | TeamLead2-2018-03       |   36.36 |          44 |
|  112 | PostgresQL-2018-05      |   54.55 |          44 |
|  113 | PostgresQL-2020-03      |   29.55 |          44 |
|  114 | PostgresQL-2020-04      |   38.64 |          44 |
|  115 | UnityGames-2018-04      |   32.56 |          43 |
|  116 | Java-2018-05            |   34.88 |          43 |
|  117 | PostgresQL-2020-05      |   41.86 |          43 |
|  118 | ArchSoftware-2019-04    |   26.83 |          41 |
|  119 | TeamLead2-2020-03       |   73.17 |          41 |
|  120 | AdvancedAndroid-2020-02 |   51.28 |          39 |
|  121 | Php-2020-05             |   48.72 |          39 |
|  122 | Golang-2019-02          |   76.92 |          39 |
|  123 | Vue-2020-05             |   52.63 |          38 |
|  124 | Php-2019-03             |   68.42 |          38 |
|  125 | ReactJs-2020-02         |   83.78 |          37 |
|  126 | JavaScript-2019-05      |   67.57 |          37 |
|  127 | Scala-2019-05           |   51.35 |          37 |
|  128 | ArchSoftware-2019-02    |   66.67 |          36 |
|  129 | Java-2018-03            |   30.56 |          36 |
|  130 | Java-2019-03            |   41.67 |          36 |
|  131 | Java-2019-04            |   52.78 |          36 |
|  132 | Java-2019-05            |   61.11 |          36 |
|  133 | Php-2018-02             |   83.33 |          36 |
|  134 | Patterns-2020-02        |   57.14 |          35 |
|  135 | Patterns-2020-03        |   68.57 |          35 |
|  136 | UnityGames-2018-05      |   65.71 |          35 |
|  137 | ArchSoftware-2018-04    |   52.94 |          34 |
|  138 | PostgresQL-2019-04      |   52.94 |          34 |
|  139 | ArchHighload-2019-04    |   51.52 |          33 |
|  140 | Patterns-2018-04        |   46.88 |          32 |
|  141 | TeamLead2-2018-04       |   78.13 |          32 |
|  142 | Scala-2019-04           |   25.81 |          31 |
|  143 | Vue-2020-03             |   43.33 |          30 |
|  144 | PostgresQL-2018-03      |   53.33 |          30 |
|  145 | UnityGames-2019-05      |   58.62 |          29 |
|  146 | Vue-2018-05             |   48.28 |          29 |
|  147 | JavaScript-2018-05      |   27.59 |          29 |
|  148 | ReactJs-2019-04         |   25.00 |          28 |
|  149 | UnityGames-2019-02      |   51.85 |          27 |
|  150 | Vue-2020-04             |   40.74 |          27 |
|  151 | ReactJs-2020-04         |   23.08 |          26 |
|  152 | ReactJs-2020-05         |   73.08 |          26 |
|  153 | UnityGames-2020-02      |   56.00 |          25 |
|  154 | Scala-2020-04           |   36.00 |          25 |
|  155 | AdvancedAndroid-2018-02 |   79.17 |          24 |
|  156 | Scala-2018-05           |   25.00 |          24 |
|  157 | Scala-2019-02           |   45.83 |          24 |
|  158 | JavaScript-2018-02      |   30.43 |          23 |
|  159 | Java-2020-05            |   21.74 |          23 |
|  160 | TeamLead2-2019-03       |   47.83 |          23 |
|  161 | ArchHighload-2018-05    |   27.27 |          22 |
|  162 | AdvancedAndroid-2019-03 |   18.18 |          22 |
|  163 | Php-2020-04             |   54.55 |          22 |
|  164 | ReactJs-2018-02         |   47.37 |          19 |
|  165 | JavaScript-2020-02      |   31.58 |          19 |
|  166 | PostgresQL-2019-03      |   33.33 |          18 |
|  167 | Patterns-2019-03        |   17.65 |          17 |
|  168 | ArchHighload-2018-04    |   46.67 |          15 |
+------+-------------------------+---------+-------------+
168 rows in set, 2 warnings (0,11 sec)
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
    ->       der1.title AS `TITLE`,
    ->       round((sum(der1.payed_full)/count(der1.user_id) * 100), 2) as `PERCENT`,
    ->       count(der1.user_id) as `TOTAL_USERS`
    ->     FROM
    ->       (
    ->         SELECT
    ->           grp.title,
    ->           invc.group_id,
    ->           invc.user_id,
    ->           SUM((invc.amount + invc.discount)) > grp.price_full as payed_full
    ->         FROM
    ->           otus_tz.invoice invc FORCE INDEX (status_group_user)
    ->           INNER JOIN otus_tz.`groups` grp ON (grp.id = invc.group_id)
    ->         WHERE
    ->           invc.`status` = 'payed'
    ->           AND grp.start_date < @month_ago
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
|    1 | ReactJs-2018-05         |    0.00 |          93 |
|    2 | UnityGames-2020-04      |    0.00 |          91 |
|    3 | Patterns-2020-02        |    1.14 |          88 |
|    4 | JavaScript-2019-03      |    3.49 |          86 |
|    5 | ReactJs-2018-02         |    2.41 |          83 |
|    6 | Vue-2019-03             |    2.44 |          82 |
|    7 | UnityGames-2019-05      |    1.23 |          81 |
|    8 | PostgresQL-2018-02      |    6.41 |          78 |
|    9 | Java-2019-02            |    1.32 |          76 |
|   10 | Scala-2020-02           |    1.33 |          75 |
|   11 | ArchHighload-2018-04    |    0.00 |          74 |
|   12 | Vue-2018-05             |    0.00 |          74 |
|   13 | Php-2020-02             |    0.00 |          74 |
|   14 | Java-2020-03            |    1.37 |          73 |
|   15 | Php-2018-03             |    1.37 |          73 |
|   16 | Patterns-2018-05        |    0.00 |          72 |
|   17 | ArchHighload-2018-02    |    0.00 |          72 |
|   18 | UnityGames-2018-03      |    0.00 |          72 |
|   19 | ReactJs-2020-05         |    1.41 |          71 |
|   20 | ArchSoftware-2019-04    |    1.45 |          69 |
|   21 | TeamLead2-2019-04       |    0.00 |          69 |
|   22 | UnityGames-2018-04      |    0.00 |          68 |
|   23 | Java-2018-04            |    1.47 |          68 |
|   24 | TeamLead2-2019-03       |    2.94 |          68 |
|   25 | Golang-2019-05          |    1.47 |          68 |
|   26 | Patterns-2018-04        |    1.49 |          67 |
|   27 | UnityGames-2019-04      |    5.97 |          67 |
|   28 | JavaScript-2019-05      |    0.00 |          67 |
|   29 | AdvancedAndroid-2020-02 |    0.00 |          66 |
|   30 | Java-2019-04            |    0.00 |          66 |
|   31 | Patterns-2019-02        |    1.54 |          65 |
|   32 | Scala-2020-03           |    3.08 |          65 |
|   33 | JavaScript-2019-04      |    1.56 |          64 |
|   34 | AdvancedAndroid-2019-03 |    0.00 |          64 |
|   35 | Java-2018-03            |    0.00 |          64 |
|   36 | Golang-2019-04          |    1.56 |          64 |
|   37 | ArchSoftware-2018-03    |    0.00 |          63 |
|   38 | ReactJs-2019-05         |    0.00 |          63 |
|   39 | Vue-2019-02             |    4.76 |          63 |
|   40 | Php-2019-03             |    3.17 |          63 |
|   41 | TeamLead2-2018-02       |    1.59 |          63 |
|   42 | ArchHighload-2019-03    |    3.23 |          62 |
|   43 | ArchHighload-2020-04    |    1.61 |          62 |
|   44 | ReactJs-2018-03         |    0.00 |          62 |
|   45 | ReactJs-2020-04         |    3.23 |          62 |
|   46 | Vue-2020-03             |    1.61 |          62 |
|   47 | Scala-2019-05           |    0.00 |          62 |
|   48 | Golang-2018-05          |    0.00 |          62 |
|   49 | AdvancedAndroid-2018-05 |    0.00 |          61 |
|   50 | Vue-2018-03             |    0.00 |          60 |
|   51 | Patterns-2020-03        |    1.69 |          59 |
|   52 | ArchSoftware-2019-02    |    0.00 |          59 |
|   53 | ArchSoftware-2019-05    |    1.69 |          59 |
|   54 | Vue-2018-02             |    3.39 |          59 |
|   55 | Scala-2019-02           |    0.00 |          59 |
|   56 | PostgresQL-2019-02      |    0.00 |          59 |
|   57 | ReactJs-2019-03         |    0.00 |          58 |
|   58 | TeamLead2-2020-02       |    1.72 |          58 |
|   59 | Patterns-2018-02        |    0.00 |          57 |
|   60 | ArchSoftware-2018-05    |    0.00 |          57 |
|   61 | ReactJs-2020-03         |    1.75 |          57 |
|   62 | Php-2020-03             |    0.00 |          57 |
|   63 | Scala-2020-05           |    1.75 |          57 |
|   64 | Patterns-2020-04        |    1.79 |          56 |
|   65 | ArchSoftware-2018-04    |    0.00 |          55 |
|   66 | ArchSoftware-2020-05    |    0.00 |          54 |
|   67 | AdvancedAndroid-2019-02 |    0.00 |          54 |
|   68 | Golang-2018-03          |    3.70 |          54 |
|   69 | PostgresQL-2019-03      |    1.85 |          54 |
|   70 | AdvancedAndroid-2018-04 |    0.00 |          53 |
|   71 | PostgresQL-2020-04      |    0.00 |          53 |
|   72 | ArchHighload-2020-03    |    3.85 |          52 |
|   73 | UnityGames-2019-03      |    1.92 |          52 |
|   74 | UnityGames-2020-05      |    3.85 |          52 |
|   75 | JavaScript-2018-03      |    0.00 |          52 |
|   76 | JavaScript-2020-03      |    0.00 |          52 |
|   77 | PostgresQL-2018-03      |    0.00 |          52 |
|   78 | TeamLead2-2020-03       |    0.00 |          51 |
|   79 | Patterns-2018-03        |    4.08 |          49 |
|   80 | UnityGames-2020-03      |    2.04 |          49 |
|   81 | Vue-2018-04             |    2.04 |          49 |
|   82 | TeamLead2-2018-03       |    4.08 |          49 |
|   83 | JavaScript-2020-05      |    0.00 |          48 |
|   84 | TeamLead2-2020-05       |    4.17 |          48 |
|   85 | ArchHighload-2019-04    |    0.00 |          46 |
|   86 | ArchSoftware-2020-03    |    0.00 |          46 |
|   87 | UnityGames-2018-05      |    0.00 |          46 |
|   88 | Php-2019-05             |    2.17 |          46 |
|   89 | Scala-2018-05           |    4.35 |          46 |
|   90 | TeamLead2-2018-04       |    0.00 |          46 |
|   91 | PostgresQL-2020-05      |    0.00 |          46 |
|   92 | ArchHighload-2018-05    |    0.00 |          45 |
|   93 | ArchSoftware-2020-02    |    0.00 |          45 |
|   94 | Vue-2020-04             |    2.22 |          45 |
|   95 | Scala-2018-03           |    4.44 |          45 |
|   96 | Patterns-2019-04        |    0.00 |          44 |
|   97 | Java-2018-02            |    0.00 |          44 |
|   98 | Java-2019-03            |    0.00 |          44 |
|   99 | Java-2020-05            |    2.27 |          44 |
|  100 | ArchHighload-2020-05    |    0.00 |          43 |
|  101 | UnityGames-2018-02      |    0.00 |          43 |
|  102 | ArchHighload-2019-02    |    0.00 |          42 |
|  103 | UnityGames-2019-02      |    0.00 |          42 |
|  104 | ReactJs-2019-04         |    2.38 |          42 |
|  105 | Java-2019-05            |    0.00 |          42 |
|  106 | Java-2020-02            |    0.00 |          42 |
|  107 | Php-2018-04             |    0.00 |          42 |
|  108 | JavaScript-2018-02      |    0.00 |          41 |
|  109 | JavaScript-2020-04      |    0.00 |          41 |
|  110 | AdvancedAndroid-2020-03 |    0.00 |          41 |
|  111 | PostgresQL-2019-05      |    0.00 |          41 |
|  112 | Php-2020-04             |    0.00 |          40 |
|  113 | Scala-2019-04           |    0.00 |          40 |
|  114 | Golang-2018-04          |    0.00 |          40 |
|  115 | ArchHighload-2019-05    |    0.00 |          39 |
|  116 | ArchHighload-2020-02    |    2.56 |          39 |
|  117 | AdvancedAndroid-2018-03 |    2.56 |          39 |
|  118 | TeamLead2-2019-02       |    5.13 |          39 |
|  119 | Golang-2019-03          |    0.00 |          39 |
|  120 | UnityGames-2020-02      |    0.00 |          38 |
|  121 | Scala-2020-04           |    2.63 |          38 |
|  122 | JavaScript-2019-02      |    0.00 |          37 |
|  123 | Java-2020-04            |    0.00 |          37 |
|  124 | JavaScript-2018-05      |    8.33 |          36 |
|  125 | Golang-2018-02          |    2.78 |          36 |
|  126 | PostgresQL-2020-03      |    0.00 |          36 |
|  127 | AdvancedAndroid-2020-05 |    0.00 |          35 |
|  128 | Php-2019-02             |    2.86 |          35 |
|  129 | Php-2020-05             |    0.00 |          34 |
|  130 | TeamLead2-2018-05       |    2.94 |          34 |
|  131 | Golang-2020-02          |    0.00 |          34 |
|  132 | ArchSoftware-2020-04    |    0.00 |          33 |
|  133 | Golang-2020-03          |    3.03 |          33 |
|  134 | PostgresQL-2019-04      |    0.00 |          33 |
|  135 | ReactJs-2019-02         |    0.00 |          32 |
|  136 | ReactJs-2020-02         |    3.13 |          32 |
|  137 | Vue-2019-05             |    0.00 |          32 |
|  138 | JavaScript-2018-04      |    0.00 |          31 |
|  139 | ArchSoftware-2018-02    |    0.00 |          30 |
|  140 | Java-2018-05            |    0.00 |          30 |
|  141 | Scala-2019-03           |    0.00 |          30 |
|  142 | Vue-2020-05             |    3.45 |          29 |
|  143 | Php-2018-02             |    0.00 |          29 |
|  144 | ReactJs-2018-04         |    0.00 |          27 |
|  145 | PostgresQL-2018-04      |    0.00 |          27 |
|  146 | Vue-2019-04             |    0.00 |          26 |
|  147 | Scala-2018-04           |    0.00 |          26 |
|  148 | Patterns-2019-05        |    0.00 |          25 |
|  149 | Php-2018-05             |    0.00 |          25 |
|  150 | PostgresQL-2018-05      |    0.00 |          25 |
|  151 | JavaScript-2020-02      |    0.00 |          23 |
|  152 | AdvancedAndroid-2018-02 |    4.35 |          23 |
|  153 | ArchSoftware-2019-03    |    0.00 |          22 |
|  154 | AdvancedAndroid-2020-04 |    0.00 |          22 |
|  155 | Scala-2018-02           |    0.00 |          22 |
|  156 | Golang-2020-05          |    0.00 |          22 |
|  157 | Patterns-2020-05        |    0.00 |          21 |
|  158 | Vue-2020-02             |    0.00 |          21 |
|  159 | Golang-2020-04          |    0.00 |          20 |
|  160 | PostgresQL-2020-02      |    0.00 |          20 |
|  161 | ArchHighload-2018-03    |    0.00 |          19 |
|  162 | AdvancedAndroid-2019-04 |    0.00 |          16 |
|  163 | TeamLead2-2019-05       |    0.00 |          15 |
|  164 | TeamLead2-2020-04       |    6.67 |          15 |
|  165 | Golang-2019-02          |    0.00 |          13 |
|  166 | AdvancedAndroid-2019-05 |    0.00 |          12 |
|  167 | Patterns-2019-03        |    0.00 |          11 |
|  168 | Php-2019-04             |    0.00 |          10 |
+------+-------------------------+---------+-------------+
168 rows in set, 2 warnings (0.06 sec)
```
