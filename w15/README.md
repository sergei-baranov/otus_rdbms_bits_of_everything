ДЗ OTUS-RDBMS-2019-10 по занятию 15 - MySql: Хранимые процедуры и триггеры
---------------------------------------------------------
Цель: использовать хранимые процедуры и функций для оптимизации работы с БД
---------------------------------------------------------

1. [процедуры](#procedures)
2. [docker](#docker)

Я сделал две процедуры по списку отслеживания котировок облигаций пользователями.

Одна - для того, чтобы посмотреть стоимость портфеля заданного пользователя
на заданную дату и опционально биржу и валюту.

Вторая - стоимость всех портфелей всех пользователей на заданную дату.

Первую разрешил вызывать пользователям client и manager, вторую - только пользователю manager.

Всё оформил для докера - залил в него структуру, минимальные данные, процедуры, пользователей.

## 1. процедуры <a name="procedures"></a>

см. init.sql

первая
```
USE portfolio;
/*
 * на входе: пользователь, дата, валюта, биржа
 */
DROP PROCEDURE IF EXISTS `portfolio`.`wl_cost_on_date`;
DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `portfolio`.`wl_cost_on_date`(
  in_person int
, in_date varchar(10)
, in_currency int
, in_exchange int
, out rc int
, out err varchar(1000)
)
SQL SECURITY DEFINER
BEGIN
    DECLARE l_currency_cond VARCHAR(255);
    DECLARE l_exchange_cond VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
        rc = RETURNED_SQLSTATE, err = MESSAGE_TEXT;
        RESIGNAL;
    END;
   
    SET l_currency_cond = IF(in_currency, CONCAT('AND e.currency_id = ', in_currency), '');
    SET l_exchange_cond = IF(in_exchange, CONCAT('AND p.place_id = ', in_exchange), '');
    SET @l_sql = CONCAT(
    'SELECT
      e.currency_id, c.code as currency_code,
      SUM(t3.indicative_price) as sum_indicative_price,
      ? as bound_date,
      MAX(`t3`.`date`) as max_trading_date
    FROM
      bonds.emissions e
      INNER JOIN common.currencies c ON c.id = e.currency_id 
      INNER JOIN (
      SELECT t2.id_pe, t2.id, t2.indicative_price, t2.emission_id, t2.`date` FROM
        (
          SELECT id_pe from `tsq`.`prices` FORCE INDEX (`id_pe_id`)
          WHERE `id_pe` IN(
            SELECT wb.pair_id FROM portfolio.watchlist_bonds wb WHERE wb.person_id = ?
          ) GROUP BY id_pe
        ) AS t1,
        LATERAL (
          SELECT id_pe, id, indicative_price, emission_id, `date`
          FROM `tsq`.`prices` p FORCE INDEX (`id_pe_id`)
          WHERE
            t1.id_pe = p.id_pe
            AND `date` < ?
            ', l_exchange_cond, '
          ORDER BY id_pe DESC, id DESC limit 1
        ) as t2
      ) as t3 ON (t3.emission_id = e.id)
      WHERE
        1
        ', l_currency_cond, '
    GROUP BY e.currency_id;');
    
    PREPARE stmt FROM @l_sql;
    SET @l_date = in_date;
    SET @l_person = in_person;
    EXECUTE stmt USING @l_date,@l_person,@l_date;
END $$
DELIMITER ;
```

вторая
```
/*
 * на входе: дата
 */
DROP PROCEDURE IF EXISTS `portfolio`.`wl_cost_on_date_allusers`;
DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `portfolio`.`wl_cost_on_date_allusers`(
  in_date varchar(10)
, out rc int
, out err varchar(1000)
)
SQL SECURITY DEFINER
BEGIN

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
        rc = RETURNED_SQLSTATE, err = MESSAGE_TEXT;
        RESIGNAL;
    END;

    SELECT 
      CASE GROUPING(currency_code)
        WHEN 1 THEN 'Все валюты'
        ELSE MAX(currency_code)
      END AS `currency`,
      CASE GROUPING(user_id)
        WHEN 1 THEN 'Все юзеры'
        ELSE MAX(fname)
      END AS `uname`,
      SUM(pair_cost) as wl_cost,
      MAX(max_trading_date) as max_trading_date,
      MAX(bound_date) as bound_date
    FROM (
    SELECT
      prsn.id as user_id, prsn.fname, pwb.pair_id, pwb.quantity, t4.currency_code, t4.indicative_price,
      (t4.indicative_price * pwb.quantity) as pair_cost,
      t4.max_trading_date, t4.bound_date
    FROM
      portfolio.watchlist_bonds pwb
      INNER JOIN common.persons prsn ON (prsn.id = pwb.person_id)
      LEFT JOIN (
    SELECT
      t3.id_pe, MAX(c.id) as currency_id, MAX(c.code) as currency_code,
      MAX(t3.indicative_price) as indicative_price,
      in_date as bound_date,
      MAX(`t3`.`date`) as max_trading_date
    FROM
      bonds.emissions e
      INNER JOIN common.currencies c ON c.id = e.currency_id 
      INNER JOIN (
      SELECT t2.id_pe, t2.id, t2.indicative_price, t2.emission_id, t2.`date` FROM
        (
          SELECT id_pe from `tsq`.`prices` FORCE INDEX (`id_pe_id`)
          WHERE `id_pe` IN(
            SELECT wb.pair_id FROM portfolio.watchlist_bonds wb
          ) GROUP BY id_pe
        ) AS t1,
        LATERAL (
          SELECT id_pe, id, indicative_price, emission_id, `date`
          FROM `tsq`.`prices` p FORCE INDEX (`id_pe_id`)
          WHERE
            t1.id_pe = p.id_pe
            AND `date` < in_date
          ORDER BY id_pe DESC, id DESC limit 1
        ) as t2
      ) as t3 ON (t3.emission_id = e.id)
    GROUP BY t3.id_pe
    ) as t4 ON (t4.id_pe = pwb.pair_id)
    ) as t5
    GROUP BY currency_code, user_id WITH ROLLUP
    HAVING currency IS NOT NULL AND currency <> 'Все валюты' AND wl_cost IS NOT NULL
;
END $$
DELIMITER ;
```

пользователи, привилегии
```
CREATE USER `client`@`localhost` IDENTIFIED BY '12345';
CREATE USER `manager`@`localhost` IDENTIFIED BY '12345';
GRANT EXECUTE ON PROCEDURE `portfolio`.`wl_cost_on_date` TO `client`@`localhost`;
GRANT EXECUTE ON PROCEDURE `portfolio`.`wl_cost_on_date` TO `manager`@`localhost`;
GRANT EXECUTE ON PROCEDURE `portfolio`.`wl_cost_on_date_allusers` TO `manager`@`localhost`;
```

## 2. docker <a name="docker"></a>

    nb: при отработке init.sql из докера мускул перед созданием процедуры согласился съесть только делимитер в виде ДВУХ долларов
    DELEMITER $$ 
    на DELIMITER $ и DELIMITER // ругался 1105  Unsupported DELIMITER
    

#### Поднять сервис можно командой:

```
docker-compose up otus_rdbms_201910_sergei_baranov_wl
```

#### Остановить:

```
docker-compose stop otus_rdbms_201910_sergei_baranov_wl
```

#### При проблемах вида
"Problem while dropping database.
Can't remove database directory ... Please remove it manually."
и т.п.:

- Открываем терминал в контейнере:

```
docker-compose exec otus_rdbms_201910_sergei_baranov_wl /bin/sh
```

- и в терминале в контейнере:

```
cd /var/lib/mysql
rm -R portfolio
rm -R tsq
rm -R bonds
rm -R common
```

#### Для подключения к БД используйте команду:

```
docker-compose exec otus_rdbms_201910_sergei_baranov_wl mysql -u root -p12345
```

или, если не пускает, то

```
docker-compose exec otus_rdbms_201910_sergei_baranov_wl mysql -uroot
```

то же из sh

```
docker-compose exec otus_rdbms_201910_sergei_baranov_wl /bin/sh
# mysql -uroot
mysql>
```

#### Для пользователя client@localhost

```
c:\VCS\...\w15>docker-compose exec otus_rdbms_201910_sergei_baranov_wl /bin/sh
# mysql -u client -p
Enter password: 12345
Welcome to the MySQL monitor.  Commands end with ; or \g.
...
```

Стоимость портфеля пользователя 2 на дату '2019-08-01'
```
mysql> CALL `portfolio`.`wl_cost_on_date`(2, '2019-08-01', 0, 0, @rc, @err);
+-------------+---------------+----------------------+------------+------------------+
| currency_id | currency_code | sum_indicative_price | bound_date | max_trading_date |
+-------------+---------------+----------------------+------------+------------------+
|          47 | CNY           |                 NULL | 2019-08-01 | 2019-06-18       |
|          55 | KRW           |       100.5900000000 | 2019-08-01 | 2019-05-08       |
|           2 | USD           |      7773.9797030000 | 2019-08-01 | 2019-07-31       |
|          32 | BRL           |       118.6503377000 | 2019-08-01 | 2019-07-11       |
|         227 | CLF           |       338.3800000000 | 2019-08-01 | 2019-06-07       |
|          51 | IDR           |        97.1500000000 | 2019-08-01 | 2019-05-09       |
|          17 | KZT           |       278.1841000000 | 2019-08-01 | 2019-07-31       |
|          57 | TND           |       200.0000000000 | 2019-08-01 | 2019-07-31       |
|         233 | XOF           |       100.0000000000 | 2019-08-01 | 2019-07-31       |
|         175 | MAD           |       105.3200000000 | 2019-08-01 | 2019-07-31       |
|          46 | INR           |       200.2300000000 | 2019-08-01 | 2019-06-25       |
+-------------+---------------+----------------------+------------+------------------+
11 rows in set (0.02 sec)

Query OK, 0 rows affected (0.02 sec)
```

Стоимость портфеля пользователя 4 на дату '2019-05-05' только по долларовым бумагам на бирже 167
```
mysql> CALL `portfolio`.`wl_cost_on_date`(4, '2019-05-05', 2, 167, @rc, @err);
+-------------+---------------+----------------------+------------+------------------+
| currency_id | currency_code | sum_indicative_price | bound_date | max_trading_date |
+-------------+---------------+----------------------+------------+------------------+
|           2 | USD           |      6056.8526030000 | 2019-05-05 | 2019-05-03       |
+-------------+---------------+----------------------+------------+------------------+
1 row in set (0,03 sec)

Query OK, 0 rows affected (0,03 sec)
```

При этом ничего больше этому пользователю не доступно:
```
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| portfolio          |
+--------------------+
2 rows in set (0.00 sec)

mysql> show tables in portfolio;
Empty set (0.01 sec)

mysql> call `portfolio`.`wl_cost_on_date_allusers`('2019-06-17', @rc, @err);
ERROR 1370 (42000): execute command denied to user 'client'@'localhost' for routine 'portfolio.wl_cost_on_date_allusers'
```

#### Для пользователя manager@localhost

```
c:\VCS\github-sergei-baranov\otus_rdbms_bits_of_everything\w15>docker-compose exec otus_rdbms_201910_sergei_baranov_wl /bin/sh
# mysql -u manager -p
Enter password: 12345
Welcome to the MySQL monitor.  Commands end with ; or \g.
...

mysql> set names utf8mb4;
Query OK, 0 rows affected (0.00 sec)
```

Сводка по стоимости портфелей всех пользователей на 2019-06-17:

```
mysql> call `portfolio`.`wl_cost_on_date_allusers`('2019-06-17', @rc, @err);
+----------+-----------+--------------------+------------------+------------+
| currency | uname     | wl_cost            | max_trading_date | bound_date |
+----------+-----------+--------------------+------------------+------------+
| BRL      | Николай   |    2783.3760871450 | 2019-06-14       | 2019-06-17 |
| BRL      | Елена     |   11398.7275738000 | 2019-06-14       | 2019-06-17 |
| BRL      | Все юзеры |   14182.1036609450 | 2019-06-14       | 2019-06-17 |
| BWP      | Владимир  |    8764.8000000000 | 2019-06-14       | 2019-06-17 |
| BWP      | Все юзеры |    8764.8000000000 | 2019-06-14       | 2019-06-17 |
| CLF      | Николай   |   15955.1300000000 | 2019-05-22       | 2019-06-17 |
| CLF      | Елена     |   24086.8000000000 | 2019-06-07       | 2019-06-17 |
| CLF      | Сергей    |   16306.3000000000 | 2019-06-07       | 2019-06-17 |
| CLF      | Владимир  |   11126.9500000000 | 2019-06-03       | 2019-06-17 |
| CLF      | Денис     |    4495.7800000000 | 2019-04-16       | 2019-06-17 |
| CLF      | Все юзеры |   71970.9600000000 | 2019-06-07       | 2019-06-17 |
| CLP      | Николай   |    4524.5200000000 | 2019-05-20       | 2019-06-17 |
| CLP      | Сергей    |    3480.5100000000 | 2019-06-12       | 2019-06-17 |
| CLP      | Все юзеры |    8005.0300000000 | 2019-06-12       | 2019-06-17 |
| IDR      | Елена     |    3691.7000000000 | 2019-05-09       | 2019-06-17 |
| IDR      | Сергей    |    7202.8800000000 | 2019-05-06       | 2019-06-17 |
| IDR      | Денис     |   27050.9700000000 | 2019-05-14       | 2019-06-17 |
| IDR      | Все юзеры |   37945.5500000000 | 2019-05-14       | 2019-06-17 |
| INR      | Елена     |    8705.7600000000 | 2019-06-12       | 2019-06-17 |
| INR      | Сергей    |   29245.4600000000 | 2019-06-13       | 2019-06-17 |
| INR      | Владимир  |   24930.7900000000 | 2019-06-14       | 2019-06-17 |
| INR      | Денис     |    4142.4600000000 | 2019-06-10       | 2019-06-17 |
| INR      | Все юзеры |   67024.4700000000 | 2019-06-14       | 2019-06-17 |
| IRR      | Владимир  |    3430.8288000000 | 2019-06-14       | 2019-06-17 |
| IRR      | Все юзеры |    3430.8288000000 | 2019-06-14       | 2019-06-17 |
| KRW      | Николай   |   22510.6600000000 | 2019-06-14       | 2019-06-17 |
| KRW      | Елена     |    9656.6400000000 | 2019-05-08       | 2019-06-17 |
| KRW      | Сергей    |    3383.8200000000 | 2019-05-27       | 2019-06-17 |
| KRW      | Владимир  |   16534.3670000000 | 2019-06-14       | 2019-06-17 |
| KRW      | Денис     |   22394.0530000000 | 2019-06-13       | 2019-06-17 |
| KRW      | Все юзеры |   74479.5400000000 | 2019-06-14       | 2019-06-17 |
| KZT      | Николай   |    5338.8160000000 | 2019-06-14       | 2019-06-17 |
| KZT      | Елена     |    1158.8934000000 | 2019-06-14       | 2019-06-17 |
| KZT      | Сергей    |    5499.5270000000 | 2019-06-14       | 2019-06-17 |
| KZT      | Владимир  |    8179.6704000000 | 2019-06-14       | 2019-06-17 |
| KZT      | Денис     |    8292.6255000000 | 2019-06-14       | 2019-06-17 |
| KZT      | Все юзеры |   28469.5323000000 | 2019-06-14       | 2019-06-17 |
| MAD      | Николай   |   10054.8000000000 | 2019-06-14       | 2019-06-17 |
| MAD      | Елена     |    4643.3200000000 | 2019-06-14       | 2019-06-17 |
| MAD      | Владимир  |    2009.6300000000 | 2019-06-14       | 2019-06-17 |
| MAD      | Все юзеры |   16707.7500000000 | 2019-06-14       | 2019-06-17 |
| TND      | Николай   |   13582.0000000000 | 2019-06-14       | 2019-06-17 |
| TND      | Елена     |   12700.0000000000 | 2019-06-14       | 2019-06-17 |
| TND      | Сергей    |    6900.0000000000 | 2019-06-14       | 2019-06-17 |
| TND      | Денис     |    5600.0000000000 | 2019-06-14       | 2019-06-17 |
| TND      | Все юзеры |   38782.0000000000 | 2019-06-14       | 2019-06-17 |
| USD      | Николай   |  317659.5961160000 | 2019-06-14       | 2019-06-17 |
| USD      | Елена     |  356407.1194860000 | 2019-06-14       | 2019-06-17 |
| USD      | Сергей    |  356999.8852090000 | 2019-06-14       | 2019-06-17 |
| USD      | Владимир  |  355160.9607000000 | 2019-06-14       | 2019-06-17 |
| USD      | Денис     |  410424.7535600000 | 2019-06-14       | 2019-06-17 |
| USD      | Все юзеры | 1796652.3150710000 | 2019-06-14       | 2019-06-17 |
| VND      | Николай   |    3833.2000000000 | 2019-06-14       | 2019-06-17 |
| VND      | Сергей    |   16053.6430000000 | 2019-06-10       | 2019-06-17 |
| VND      | Владимир  |   23908.2960000000 | 2019-06-14       | 2019-06-17 |
| VND      | Все юзеры |   43795.1390000000 | 2019-06-14       | 2019-06-17 |
| XOF      | Елена     |    2200.0000000000 | 2019-06-14       | 2019-06-17 |
| XOF      | Все юзеры |    2200.0000000000 | 2019-06-14       | 2019-06-17 |
+----------+-----------+--------------------+------------------+------------+
58 rows in set (0.08 sec)

Query OK, 0 rows affected (0.08 sec)
```

И больше ему ничего не доступно:

```
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| portfolio          |
+--------------------+
2 rows in set (0.01 sec)

mysql> show tables in portfolio;
Empty set (0.00 sec)
```