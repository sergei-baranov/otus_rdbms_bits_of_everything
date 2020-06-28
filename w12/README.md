ДЗ OTUS-RDBMS-2019-10 по занятию 12 - MySql: DML: агрегация и сортировка, CTE, аналитические функции
---------------------------------------------------------
Задача: группировать и сортировать данные и использовать групповые функции
---------------------------------------------------------

# Table of Contents

1. [case](#case)
2. [case, rollup, grouping](#case_rollup_grouping)
3. [case, rollup, grouping, having](#case_rollup_grouping_having)
4. [валюта в группировку, MAX, убрать HAVING-ом в GROUPING() = 1 по валютам](#cost1)
5. [то же с подсчётом торговых дней](#cost2)
6. [docker](#docker)


## 1. case <a name="case"></a>

По списку отслеживания каждого пользователя показать,
по скольким парам бумага-биржа из его списка
в БД есть записи с объёмами торгов, а по скольким нет.

```
/* case */
SELECT
  prsn.fname,
  CASE
    WHEN v.id IS NULL THEN 'no volumes'
    ELSE 'with volumes'
  END AS has_volumes,
  COUNT(p.id) as quotations_count
FROM
  portfolio.watchlist_bonds wb
  INNER JOIN common.persons prsn ON (prsn.id = wb.person_id)
  INNER JOIN tsq.prices p ON (p.id_pe = wb.pair_id)
  LEFT JOIN tsq.volumes v ON (v.id = p.id)
GROUP BY
  wb.person_id,
  has_volumes
ORDER BY 1 ASC, 2 DESC
;
```

```
+------------------+--------------+------------------+
| fname            | has_volumes  | quotations_count |
+------------------+--------------+------------------+
| Владимир         | with volumes |              147 |
| Владимир         | no volumes   |             4248 |
| Денис            | with volumes |              159 |
| Денис            | no volumes   |             3664 |
| Елена            | with volumes |               78 |
| Елена            | no volumes   |             3546 |
| Николай          | with volumes |              152 |
| Николай          | no volumes   |             4103 |
| Сергей           | with volumes |               37 |
| Сергей           | no volumes   |             3814 |
+------------------+--------------+------------------+
10 rows in set (0,16 sec)
```

## 2. case, rollup, grouping <a name="case_rollup_grouping"></a>

Количество котировок в БД по каждой бирже
(суммарно по всем парам бумага-биржа по бирже)
в списках отслеживания каждого пользователя

```
/* case, rollup, grouping */
SELECT
  CASE GROUPING(`prsn`.`id`)
    WHEN 1 THEN 'Все юзеры'
    ELSE MAX(`prsn`.`fname`)
  END AS `ename`,
  CASE GROUPING(`exch`.`id`)
    WHEN 1 THEN 'Все биржи'
    ELSE CONCAT((SUBSTRING(MAX(`exch`.`name`), 1, 8)), '...')
  END AS `ename`,
  COUNT(1) as quotations_count
FROM
  portfolio.watchlist_bonds wb
  INNER JOIN common.persons prsn ON (prsn.id = wb.person_id)
  INNER JOIN tsq.prices p ON (p.id_pe = wb.pair_id)
  INNER JOIN tsq.exchanges exch ON (exch.id = p.place_id)
GROUP BY
  `prsn`.`id`,
  `exch`.`id`
WITH ROLLUP
;
```

```
+-------------------+---------------------+------------------+
| ename             | ename               | quotations_count |
+-------------------+---------------------+------------------+
| Николай           | Шэньчжэн...         |                5 |
| Николай           | Корейска...         |              117 |
| Николай           | FINRA TR...         |             3608 |
| Николай           | Selic (B...         |               32 |
| Николай           | Санкт-Пе...         |              104 |
| Николай           | ФБ Санть...         |               17 |
| Николай           | Фиксинг ...         |               95 |
| Николай           | Парагвай...         |                1 |
| Николай           | Ханойска...         |               22 |
| Николай           | ФБ Тунис...         |              188 |
| Николай           | ФБ Руанд...         |               12 |
| Николай           | ФБ Касаб...         |               51 |
| Николай           | BYMA (ра...         |                2 |
| Николай           | Clearcor...         |                1 |
| Николай           | Все биржи           |             4255 |
| Елена             | Шэньчжэн...         |               42 |
| Елена             | Корейска...         |                1 |
| Елена             | FINRA TR...         |             2785 |
| Елена             | Selic (B...         |               65 |
| Елена             | ФБ Санть...         |               18 |
| Елена             | Индонези...         |                1 |
| Елена             | Фиксинг ...         |              356 |
| Елена             | Ханойска...         |                8 |
| Елена             | ФБ Тунис...         |              188 |
| Елена             | Регионал...         |               92 |
| Елена             | ФБ Касаб...         |               51 |
| Елена             | ФБ Монте...         |                4 |
| Елена             | Clearcor...         |               11 |
| Елена             | Все биржи           |             3622 |
| Сергей            | Корейска...         |                5 |
| Сергей            | FINRA TR...         |             3483 |
| Сергей            | Македонс...         |               22 |
| Сергей            | ФБ Санть...         |               24 |
| Сергей            | Индонези...         |                2 |
| Сергей            | Фиксинг ...         |               95 |
| Сергей            | Парагвай...         |                2 |
| Сергей            | Ханойска...         |               62 |
| Сергей            | ФБ Тунис...         |               94 |
| Сергей            | ФБ Монте...         |               42 |
| Сергей            | BYMA (ра...         |                2 |
| Сергей            | Clearcor...         |               16 |
| Сергей            | Все биржи           |             3849 |
| Владимир          | Корейска...         |               97 |
| Владимир          | FINRA TR...         |             3899 |
| Владимир          | ФБ Санть...         |                8 |
| Владимир          | Фиксинг ...         |               95 |
| Владимир          | Ботсванс...         |               98 |
| Владимир          | Ханойска...         |               20 |
| Владимир          | ФБ Касаб...         |               51 |
| Владимир          | Iran Far...         |              102 |
| Владимир          | Clearcor...         |               23 |
| Владимир          | Все биржи           |             4393 |
| Денис             | Шэньчжэн...         |                2 |
| Денис             | Корейска...         |               91 |
| Денис             | FINRA TR...         |             3470 |
| Денис             | ФБ Санть...         |                1 |
| Денис             | Индонези...         |               21 |
| Денис             | Фиксинг ...         |               95 |
| Денис             | ФБ Тунис...         |               94 |
| Денис             | BYMA (ра...         |               43 |
| Денис             | Clearcor...         |                4 |
| Денис             | Все биржи           |             3821 |
| Все юзеры         | Все биржи           |            19940 |
+-------------------+---------------------+------------------+
63 rows in set (0,13 sec)
```

## 3. case, rollup, grouping, having <a name="case_rollup_grouping_having"></a>

То же, но отбрасываем на выводе котировки, по которым в БД нет объёма торгов в деньгах

```
/* case, rollup, grouping, having */
SELECT
  CASE GROUPING(`prsn`.`id`)
    WHEN 1 THEN 'Все юзеры'
    ELSE MAX(`prsn`.`fname`)
  END AS `ename`,
  CASE GROUPING(`exch`.`id`)
    WHEN 1 THEN 'Все биржи'
    ELSE CONCAT((SUBSTRING(MAX(`exch`.`name`), 1, 8)), '...')
  END AS `ename`,
  COUNT(1) as qt_count,
  SUM(v.volume_money) sum_volume_money
FROM
  portfolio.watchlist_bonds wb
  INNER JOIN common.persons prsn ON (prsn.id = wb.person_id)
  INNER JOIN tsq.prices p ON (p.id_pe = wb.pair_id)
  INNER JOIN tsq.exchanges exch ON (exch.id = p.place_id)
  LEFT JOIN tsq.volumes v ON (v.id = p.id)
GROUP BY
  `prsn`.`id`,
  `exch`.`id`
WITH ROLLUP
HAVING sum_volume_money > 0
;
```

```
+-------------------+---------------------+----------+------------------+
| ename             | ename               | qt_count | sum_volume_money |
+-------------------+---------------------+----------+------------------+
| Николай           | BYMA (ра...         |        2 |             9000 |
| Николай           | Все биржи           |     4255 |             9000 |
| Елена             | Индонези...         |        1 |       2147483647 |
| Елена             | Clearcor...         |       11 |      11792450941 |
| Елена             | Все биржи           |     3622 |      13939934588 |
| Сергей            | Индонези...         |        2 |       4294967294 |
| Сергей            | BYMA (ра...         |        2 |         60266857 |
| Сергей            | Clearcor...         |       16 |      10984883647 |
| Сергей            | Все биржи           |     3849 |      15340117798 |
| Владимир          | Iran Far...         |      102 |      51969672940 |
| Владимир          | Clearcor...         |       23 |      19963418235 |
| Владимир          | Все биржи           |     4393 |      71933091175 |
| Денис             | Индонези...         |       21 |      31919803764 |
| Денис             | BYMA (ра...         |       43 |          6090120 |
| Денис             | Clearcor...         |        4 |        660000000 |
| Денис             | Все биржи           |     3821 |      32585893884 |
| Все юзеры         | Все биржи           |    19940 |     133799046445 |
+-------------------+---------------------+----------+------------------+
17 rows in set (0,24 sec)
```

## 4. валюта в группировку, MAX, убрать HAVING-ом в GROUPING() = 1 по валютам <a name="cost1"></a>

Максимальная и минимальная стоимость торгующихся пар
списка в группировке по валютам за период,
отбрасывая сумму по всем валютам как бессмысленную

```
/* валюта в группировку, MAX, убрать HAVING-ом в GROUPING() = 1 по валютам (бессмысл.) */
SELECT
  CASE GROUPING(`prsn`.`id`)
    WHEN 1 THEN 'Все юзеры'
    ELSE MAX(`prsn`.`fname`)
  END AS `uname`,
  CASE GROUPING(`exch`.`id`)
    WHEN 1 THEN 'Все биржи'
    ELSE CONCAT((SUBSTRING(MAX(`exch`.`name`), 1, 8)), '...')
  END AS `ename`,
  CASE GROUPING(`e`.`currency_id`)
    WHEN 1 THEN NULL
    ELSE MAX(c.code)
  END AS `cname`,
  ROUND(MIN(wb.quantity * p.indicative_price)) as min_wl_cost,
  ROUND(MAX(wb.quantity * p.indicative_price)) as max_wl_cost
FROM
  portfolio.watchlist_bonds wb
  INNER JOIN common.persons prsn ON (prsn.id = wb.person_id)
  INNER JOIN tsq.prices p ON (p.id_pe = wb.pair_id)
  INNER JOIN tsq.exchanges exch ON (exch.id = p.place_id)
  INNER JOIN bonds.emissions e ON (e.id = p.emission_id)
  INNER JOIN common.currencies c ON (c.id = e.currency_id)
WHERE
  p.`date` BETWEEN '2019-05-01' AND '2019-05-31'
GROUP BY
  `prsn`.`id`,
  `e`.`currency_id`,
  `exch`.`id`
WITH ROLLUP
HAVING
  `max_wl_cost` IS NOT NULL
  AND `cname` IS NOT NULL
  AND `ename` = 'Все биржи'
ORDER BY max_wl_cost DESC
;
```

```
+------------------+-------------------+-------+-------------+-------------+
| uname            | ename             | cname | min_wl_cost | max_wl_cost |
+------------------+-------------------+-------+-------------+-------------+
| Денис            | Все биржи         | USD   |        1013 |       12628 |
| Владимир         | Все биржи         | USD   |        1151 |       12347 |
| Владимир         | Все биржи         | VND   |        5332 |       12154 |
| Сергей           | Все биржи         | USD   |        1090 |       11460 |
| Елена            | Все биржи         | BRL   |       10635 |       11023 |
| Сергей           | Все биржи         | VND   |        5296 |       10351 |
| Денис            | Все биржи         | KRW   |        6124 |       10184 |
| Николай          | Все биржи         | USD   |         337 |       10146 |
| Николай          | Все биржи         | MAD   |       10065 |       10074 |
| Елена            | Все биржи         | USD   |        1017 |       10056 |
| Николай          | Все биржи         | KRW   |        3712 |        9879 |
| Владимир         | Все биржи         | KRW   |        1322 |        9816 |
| Елена            | Все биржи         | KRW   |        9657 |        9657 |
| Елена            | Все биржи         | TND   |        3300 |        9400 |
| Сергей           | Все биржи         | INR   |        3914 |        9318 |
| Владимир         | Все биржи         | INR   |        8711 |        9276 |
| Денис            | Все биржи         | IDR   |        3693 |        9100 |
| Николай          | Все биржи         | CLF   |        3260 |        9069 |
| Владимир         | Все биржи         | BWP   |        8800 |        8821 |
| Николай          | Все биржи         | TND   |        5300 |        8282 |
| Денис            | Все биржи         | KZT   |        8208 |        8266 |
| Владимир         | Все биржи         | KZT   |        8123 |        8177 |
| Владимир         | Все биржи         | CLF   |        3386 |        7711 |
| Сергей           | Все биржи         | IDR   |        7203 |        7203 |
| Сергей           | Все биржи         | TND   |        6900 |        6900 |
| Денис            | Все биржи         | TND   |        5600 |        5600 |
| Сергей           | Все биржи         | KZT   |        5488 |        5490 |
| Николай          | Все биржи         | KZT   |        5299 |        5341 |
| Елена            | Все биржи         | CLF   |        5078 |        5121 |
| Елена            | Все биржи         | CNY   |        4990 |        5003 |
| Елена            | Все биржи         | MAD   |        4607 |        4643 |
| Николай          | Все биржи         | CLP   |        4517 |        4525 |
| Елена            | Все биржи         | INR   |        4044 |        4508 |
| Денис            | Все биржи         | INR   |        4119 |        4119 |
| Николай          | Все биржи         | VND   |        3802 |        3845 |
| Елена            | Все биржи         | IDR   |        3692 |        3692 |
| Владимир         | Все биржи         | IRR   |        3421 |        3600 |
| Сергей           | Все биржи         | CLP   |        3404 |        3438 |
| Николай          | Все биржи         | BRL   |        2578 |        2788 |
| Елена            | Все биржи         | XOF   |        2200 |        2200 |
| Сергей           | Все биржи         | KRW   |        1252 |        2132 |
| Владимир         | Все биржи         | MAD   |        1994 |        2009 |
| Елена            | Все биржи         | KZT   |        1150 |        1484 |
+------------------+-------------------+-------+-------------+-------------+
43 rows in set (0,11 sec)
```

## 5. то же с подсчётом торговых дней <a name="cost2"></a>

То же самое, но с явной датой и подсчётом торговых дней за период

```
/* То же самое, но с явной датой и подсчётом торговых дней за период */
/* валюта, дата в группировку, MAX, убрать HAVING-ом в GROUPING() = 1 по валютам (бессмысл.) */
SELECT
  CASE GROUPING(`prsn`.`id`)
    WHEN 1 THEN 'Все юзеры'
    ELSE MAX(`prsn`.`fname`)
  END AS `uname`,
  CASE GROUPING(`e`.`currency_id`)
    WHEN 1 THEN NULL
    ELSE MAX(c.code)
  END AS `cname`,
  CASE GROUPING(`exch`.`id`)
    WHEN 1 THEN 'Все биржи'
    ELSE CONCAT((SUBSTRING(MAX(`exch`.`name`), 1, 8)), '...')
  END AS `ename`,
  CASE GROUPING(`p`.`date`)
    WHEN 1 THEN 'Все дни'
    ELSE MAX(`p`.`date`)
  END AS `dname`,
  COUNT(DISTINCT p.`date`) days,
  ROUND(MAX(wb.quantity * p.indicative_price)) as max_wl_currency_day_cost
FROM
  portfolio.watchlist_bonds wb
  INNER JOIN common.persons prsn ON (prsn.id = wb.person_id)
  INNER JOIN tsq.prices p ON (p.id_pe = wb.pair_id)
  INNER JOIN tsq.exchanges exch ON (exch.id = p.place_id)
  INNER JOIN bonds.emissions e ON (e.id = p.emission_id)
  INNER JOIN common.currencies c ON (c.id = e.currency_id)
WHERE
  p.`date` BETWEEN '2019-05-01' AND '2019-05-31'
GROUP BY
  `prsn`.`id`,
  `e`.`currency_id`,
  `p`.`date`,
  `exch`.`id`
WITH ROLLUP
HAVING
  `max_wl_currency_day_cost` IS NOT NULL
  AND `cname` IS NOT NULL
  AND `ename` = 'Все биржи'
  AND `dname` = 'Все дни'
ORDER BY `max_wl_currency_day_cost` DESC
;
```

```
+------------------+-------+-------------------+---------------+------+--------------------------+
| uname            | cname | ename             | dname         | days | max_wl_currency_day_cost |
+------------------+-------+-------------------+---------------+------+--------------------------+
| Денис            | USD   | Все биржи         | Все дни       |   22 |                    12628 |
| Владимир         | USD   | Все биржи         | Все дни       |   22 |                    12347 |
| Владимир         | VND   | Все биржи         | Все дни       |    3 |                    12154 |
| Сергей           | USD   | Все биржи         | Все дни       |   22 |                    11460 |
| Елена            | BRL   | Все биржи         | Все дни       |   22 |                    11023 |
| Сергей           | VND   | Все биржи         | Все дни       |    4 |                    10351 |
| Денис            | KRW   | Все биржи         | Все дни       |   20 |                    10184 |
| Николай          | USD   | Все биржи         | Все дни       |   22 |                    10146 |
| Николай          | MAD   | Все биржи         | Все дни       |    8 |                    10074 |
| Елена            | USD   | Все биржи         | Все дни       |   22 |                    10056 |
| Николай          | KRW   | Все биржи         | Все дни       |   20 |                     9879 |
| Владимир         | KRW   | Все биржи         | Все дни       |   21 |                     9816 |
| Елена            | KRW   | Все биржи         | Все дни       |    1 |                     9657 |
| Елена            | TND   | Все биржи         | Все дни       |   21 |                     9400 |
| Сергей           | INR   | Все биржи         | Все дни       |    7 |                     9318 |
| Владимир         | INR   | Все биржи         | Все дни       |    8 |                     9276 |
| Денис            | IDR   | Все биржи         | Все дни       |    8 |                     9100 |
| Николай          | CLF   | Все биржи         | Все дни       |    2 |                     9069 |
| Владимир         | BWP   | Все биржи         | Все дни       |   21 |                     8821 |
| Николай          | TND   | Все биржи         | Все дни       |   21 |                     8282 |
| Денис            | KZT   | Все биржи         | Все дни       |   18 |                     8266 |
| Владимир         | KZT   | Все биржи         | Все дни       |   18 |                     8177 |
| Владимир         | CLF   | Все биржи         | Все дни       |    6 |                     7711 |
| Сергей           | IDR   | Все биржи         | Все дни       |    1 |                     7203 |
| Сергей           | TND   | Все биржи         | Все дни       |   21 |                     6900 |
| Денис            | TND   | Все биржи         | Все дни       |   21 |                     5600 |
| Сергей           | KZT   | Все биржи         | Все дни       |   18 |                     5490 |
| Николай          | KZT   | Все биржи         | Все дни       |   18 |                     5341 |
| Елена            | CLF   | Все биржи         | Все дни       |    8 |                     5121 |
| Елена            | CNY   | Все биржи         | Все дни       |   19 |                     5003 |
| Елена            | MAD   | Все биржи         | Все дни       |    8 |                     4643 |
| Николай          | CLP   | Все биржи         | Все дни       |    9 |                     4525 |
| Елена            | INR   | Все биржи         | Все дни       |    5 |                     4508 |
| Денис            | INR   | Все биржи         | Все дни       |    1 |                     4119 |
| Николай          | VND   | Все биржи         | Все дни       |    5 |                     3845 |
| Елена            | IDR   | Все биржи         | Все дни       |    1 |                     3692 |
| Владимир         | IRR   | Все биржи         | Все дни       |   21 |                     3600 |
| Сергей           | CLP   | Все биржи         | Все дни       |    9 |                     3438 |
| Николай          | BRL   | Все биржи         | Все дни       |    6 |                     2788 |
| Елена            | XOF   | Все биржи         | Все дни       |   18 |                     2200 |
| Сергей           | KRW   | Все биржи         | Все дни       |    5 |                     2132 |
| Владимир         | MAD   | Все биржи         | Все дни       |    8 |                     2009 |
| Елена            | KZT   | Все биржи         | Все дни       |   18 |                     1484 |
+------------------+-------+-------------------+---------------+------+--------------------------+
43 rows in set (0,13 sec)
```

Это всё бессмысленно без учёта пропусков в торгах по парам и без курса валют,
просто пример владения синтаксисом.

## 6. docker <a name="docker"></a>

сам себе: mysqldump
```
sudo mysqldump bonds  -p*** --single-transaction --tables emissions --where="id in (SELECT DISTINCT emission_id FROM tsq.prices WHERE tsq.prices.id_pe IN (SELECT DISTINCT pair_id FROM portfolio.watchlist_bonds))" > ~/emissions.sql

sudo mysqldump tsq -p*** --extended-insert=FALSE --single-transaction --tables prices --where="id_pe IN (SELECT DISTINCT pair_id FROM portfolio.watchlist_bonds)" > ~/prices.sql

sudo mysqldump tsq -p*** --extended-insert=FALSE --single-transaction --tables volumes --where="id in (select id from tsq.prices where id_pe IN (SELECT DISTINCT pair_id FROM portfolio.watchlist_bonds))" > ~/volumes.sql
```

#### Поднять сервис можно командой:

```
docker-compose up otus_rdbms_201910_sergei_baranov_w12
```

#### Остановить:

```
docker-compose stop otus_rdbms_201910_sergei_baranov_w12
```

#### При проблемах вида
"Problem while dropping database.
Can't remove database directory ... Please remove it manually."
и т.п.:

- Открываем терминал в контейнере:

```
docker-compose exec otus_rdbms_201910_sergei_baranov_w12 /bin/sh
```

- и в терминале в контейнере:

```
cd /var/lib/mysql
rm -R common
rm -R bonds
rm -R tsq
```

#### Для подключения к БД используйте команду:

```
docker-compose exec otus_rdbms_201910_sergei_baranov_w12 mysql -u root -p12345
```

или, если не пускает, то

```
docker-compose exec otus_rdbms_201910_sergei_baranov_w12 mysql -uroot
```

то же из sh

```
docker-compose exec otus_rdbms_201910_sergei_baranov_w12 /bin/sh
# mysql -uroot
mysql>
```

```
SELECT * FROM tsq.dz12p1;
SELECT * FROM tsq.dz12p2;
SELECT * FROM tsq.dz12p3;
SELECT * FROM tsq.dz12p4;
SELECT * FROM tsq.dz12p5;
```