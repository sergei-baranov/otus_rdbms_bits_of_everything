Сначала вторая часть задания, потом первая.
-------------------------------------------

## 2. Загрузить данные из приложенных в материалах csv.<br/>Реализовать следующими путями: LOAD DATA, mysqlimport.
### 2.1. LOAD DATA

История такая:

Для переноса на домашнюю машину одной жирной таблицы для опытов
мне сисадмины выгрузили её в csv-файл.
Там 250М строк, файл 110G весом.

Структура таблирцы - su_tradings.sql (файл рядом в директории)

Я разбил его на куски по 1М строк и загрузил через LOAD DATA 5 из них в бд.
Это было ещё в декабре, восстанавливаю историю из чата общения с сисадминами.

Сам себе заметка, чтобы потом вспомнить, когда создавал тейблспейс,
была проблема с apparmor (плюс к правам и владельцам):

    $ sudo nano /etc/apparmor.d/usr.sbin.mysqld

    # Allow data dir access
    /var/lib/mysql/ r,
    /var/lib/mysql/** rwk,
    /mysql_tablespaces/ r,  
    /mysql_tablespaces/hd2t/ r,
    /mysql_tablespaces/hd2t/** rwk,
    # три последние строчки - это я добавил

    mysql> CREATE TABLESPACE ts1 ADD DATAFILE '/mysql_tablespaces/hd2t/ts1.ibd' ENGINE InnoDB;
    Query OK, 0 rows affected (0,11 sec)

Исходный файл c дампом в csv:

    $ ls -lah
    итого 231G
    -rwxr-xr-x  1 root    root    104G дек  6 02:14 tradings.txt
    ...

Разбил через split -l 1000000 tradings.txt:

    $ ls -lah
    итого 231G
    -rwxr-xr-x  1 root    root    104G дек  6 02:14 tradings.txt
    -rwxr-xr-x  1 root    root     24G дек  6 01:45 t.tar.bz2
    ...
    -rw-r--r--  1 root    root    506M дек  8 04:48 xiy
    -rw-r--r--  1 root    root    506M дек  8 04:49 xiz
    -rw-r--r--  1 root    root    508M дек  8 04:49 xja
    -rw-r--r--  1 root    root    140M дек  8 04:49 xjb

Строки в файлах вот такие:

    $ tail -n 1 xjb
    2377884327,2019-09-05,397,100,0,0,0,0,0,0,0,0,0,\N,0000-00-00,\N,171575,\N,\N,\N,\N,\N,\N,\N,\N,\N,\N,826.5,2019-09-05-171575-39,0.068710061306015,\N,\N,\N,0.06875,\N,\N,\N,\N,\N,\N,\N,\N,\N,\N,0,\N,0,0,0,0,1.8770491803279,\N,\N,\N,\N,\N,0,0,0,0,0,2019-09-05 15:05:37,\N,\N,\N,\N,\N,\N,\N,0,\N,\N,\N,\N

Выяснил директорию для файлов, откуда мускул согласен их заливать:

    mysql> SELECT @@secure_file_priv;
    +-----------------------+
    | @@secure_file_priv    |
    +-----------------------+
    | /var/lib/mysql-files/ |
    +-----------------------+

Скопировал файлы в неё, проставил разрешения:

    $ sudo cp ./xjb /var/lib/mysql-files/xjb
    sudo chown mysql /var/lib/mysql-files/xjb
    sudo chgrp mysql /var/lib/mysql-files/xjb

И заливал вот так:

    mysql> LOAD DATA INFILE '/var/lib/mysql-files/xja' IGNORE INTO TABLE su.tradings FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n';
    Query OK, 1000000 rows affected, 65535 warnings (9 min 32,10 sec)
    Records: 1000000  Deleted: 0  Skipped: 0  Warnings: 766849

9 min 32,10 sec как-то много.
Выставил настройки для скорости: sync_binlog был 1, innodb_flush_method был fsync,
поменял, стало:

    mysql> SELECT @@innodb_flush_method;
    +-----------------------+
    | @@innodb_flush_method |
    +-----------------------+
    | O_DIRECT              |
    +-----------------------+
    1 row in set (0,00 sec)
    
    mysql> SELECT @@sync_binlog;
    +---------------+
    | @@sync_binlog |
    +---------------+
    |             0 |
    +---------------+
    1 row in set (0,00 sec)

И соответственно загрузка стала существенно быстрее работать:

    mysql> LOAD DATA INFILE '/var/lib/mysql-files/xiv' IGNORE INTO TABLE su.tradings FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n';
    Query OK, 0 rows affected, 65535 warnings (32,97 sec)
    Records: 1000000  Deleted: 0  Skipped: 1000000  Warnings: 1772542

32,97 sec - это гораздо лучше

Варнинги смотрел через SHOW WARNINGS; - там ругалось на поля типа date со значением 0000-00-00, но записи заливало:

    mysql> SELECT COUNT(*) FROM su.tradings;
    +----------+
    | COUNT(*) |
    +----------+
    |  2275129 |
    +----------+
    1 row in set (7,63 sec)

Собственно, после этого очень быстро залил 5М записей на опыты.

### 2.2. mysqlimport

Сейчас mysqlimport-ом зальём ещё 1М строк.

Проверяем, что я там заливал последнее через LOAD DATA

    $ sudo ls /var/lib/mysql-files/
    xiv

Убеждаемся, что действительно залил

    $ tail -n 1 /var/lib/mysql-files/xiv
    2341660277,2019-05-09,255,99.56,100.66,0,100.1,100.1,100.05,0,100.11,0,0,\N,0000-00-00,\N,115211,\N,\N,\N,\N,\N,\N,\N,\N,\N,\N,0,2019-05-09-115211-25,\N,\N,\N,\N,\N,\N,\N,\N,\N,\N,\N,\N,\N,\N,\N,0,\N,0,0,0,0,0.69444444444444,\N,\N,\N,\N,\N,0,100.07,0,0,0,2019-05-10 19:07:02,\N,\N,\N,\N,\N,100.07,Close,0,\N,\N,\N,109.99999999999943

    mysql> SELECT id FROM su.tradings WHERE id = 2341660277;
    +------------+
    | id         |
    +------------+
    | 2341660277 |
    +------------+
    1 row in set (0,07 sec)

Заливал. Значит будем лить следующий файл - xiu.
Убеждаемся, что его я ещё не лил:

    $ tail -n 1 /mysql_tablespaces/hd2t/xiu
    2324987925,2019-03-12,255,0,0,0,111.52,111.6,111.493,0,0,0,0,\N,0000-00-00,\N,120857,0.021021897111942,\N,0.053811176581376,\N,\N,\N,\N,1015.2080473065,2.7241256218856,\N,135.08,2019-03-12-120857-25,\N,\N,\N,\N,\N,\N,\N,\N,\N,0.021021897111942,\N,0.053811176581376,\N,\N,\N,0,\N,0,0,0,0,3.0437158469945,\N,0.031110222874595,\N,10.533942999536,\N,0,111.501,0,0,0,2019-03-13 03:07:54,\N,\N,\N,\N,\N,111.501,Close,0.021021897111942,Clearance,1015.2080473065,2.7241256218856,\N

    mysql> SELECT id FROM su.tradings WHERE id = 2324987925;
    Empty set (0,01 sec)

Отлично. Загружаем его mysqlimport-ом. Даже сделаем два файла за раз: xiu и xit.

Копируем файлы с переименованием, чтобы название файлов соответствовали таблице tradings:

    $ sudo cp /mysql_tablespaces/hd2t/xiu /mysql_tablespaces/hd2t/tradings.a
    $ sudo cp /mysql_tablespaces/hd2t/xit /mysql_tablespaces/hd2t/tradings.b

И запускаем mysqlimport:

    $ mysqlimport --verbose --use-threads=4 --lock-tables --ignore --user=root --password --fields-enclosed-by='' --fields-terminated-by=',' --lines-terminated-by='\n' su /mysql_tablespaces/hd2t/tradings.a mysql_tablespaces/hd2t/tradings.b
    Connecting to localhost
    Selecting database su
    Locking tables for write
    mysqlimport: Error: 1066 Not unique table/alias: 'tradings'

Наверное не хочет два файла на одну таблицу. Оставляем один.

    $ mysqlimport --verbose --use-threads=4 --lock-tables --ignore --user=root --password --fields-enclosed-by='' --fields-terminated-by=',' --lines-terminated-by='\n' su /mysql_tablespaces/hd2t/tradings.a
    Connecting to localhost
    Selecting database su
    Locking tables for write
    Loading data from SERVER file: /mysql_tablespaces/hd2t/tradings.a into tradings
    mysqlimport: Error: 1290, The MySQL server is running with the --secure-file-priv option so it cannot execute this statement, when using table: tradings

Копируем файлы в специальную директорию и выставляем им владельца:

    $ sudo mv /mysql_tablespaces/hd2t/tradings.a /var/lib/mysql-files/tradings.a
    $ sudo mv /mysql_tablespaces/hd2t/tradings.b /var/lib/mysql-files/tradings.b
    $ sudo chown mysql:mysql /var/lib/mysql-files/tradings.a
    $ sudo chown mysql:mysql /var/lib/mysql-files/tradings.b

Пробуем теперь:

    $ mysqlimport --verbose --use-threads=4 --lock-tables --ignore --user=root --password --fields-enclosed-by='' --fields-terminated-by=',' --lines-terminated-by='\n' su /var/lib/mysql-files/tradings.a
    Connecting to localhost
    Selecting database su
    Locking tables for write
    Loading data from SERVER file: /var/lib/mysql-files/tradings.a into tradings
    su.tradings: Records: 1000000  Deleted: 0  Skipped: 0  Warnings: 783539
    Disconnecting from localhost

HDD скрипел минут 30. Проверяем опции записи:

    mysql> SELECT @@innodb_flush_method;
    +-----------------------+
    | @@innodb_flush_method |
    +-----------------------+
    | O_DIRECT              |
    +-----------------------+
    1 row in set (0,00 sec)

    mysql> SELECT @@sync_binlog;
    +---------------+
    | @@sync_binlog |
    +---------------+
    |             0 |
    +---------------+
    1 row in set (0,00 sec)

Всё в порядке с опциями....

Проверяем конфиг:

    sudo nano /etc/mysql/my.cnf

    !includedir /etc/mysql/conf.d/
    !includedir /etc/mysql/mysql.conf.d/
    [mysqld]
    default-authentication-plugin=mysql_native_password
    innodb_directories=";/mysql_tablespaces/hd2t;/mysql_tablespaces/sd1t"
    innodb_flush_log_at_trx_commit=0
    sync_binlog=0
    innodb_flush_method=O_DIRECT
    innodb_buffer_pool_size=16G
    bind-address=0.0.0.0

Плохо работает mysqlimport ))

Может ему помешали 4 потока? конкурируют за диск, например.

Прогоним второй файл в одном потоке:

    $ mysqlimport --verbose --lock-tables --ignore --user=root --password --fields-enclosed-by='' --fields-terminated-by=',' --lines-terminated-by='\n' su /var/lib/mysql-files/tradings.b
    Connecting to localhost
    Selecting database su
    Locking tables for write
    Loading data from SERVER file: /var/lib/mysql-files/tradings.b into tradings
    su.tradings: Records: 1000000  Deleted: 0  Skipped: 0  Warnings: 785724
    Disconnecting from localhost

50 минут. Непонятно. Попробуем ещё один файл через LOAD DATA.

Подготавливаем файл tradings.c:

    $ sudo cp /mysql_tablespaces/hd2t/xis /var/lib/mysql-files/tradings.c
    $ sudo chown mysql:mysql /var/lib/mysql-files/tradings.c

Делаем LOAD DATA:

    mysql> LOAD DATA INFILE '/var/lib/mysql-files/tradings.c' IGNORE INTO TABLE su.tradings FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n';
    Query OK, 1000000 rows affected, 65535 warnings (39 min 29,81 sec)
    Records: 1000000  Deleted: 0  Skipped: 0  Warnings: 803521

Собственно, то же время. Интересно, как у меня получалось 32 секунды? Таблица была меньше, возможно начали новую партицию. Или я просто прогнал один и тот же файл второй раз.
Прогоню повторно последний:

    mysql> LOAD DATA INFILE '/var/lib/mysql-files/tradings.c' IGNORE INTO TABLE su.tradings FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n';
    Query OK, 0 rows affected, 65535 warnings (24,10 sec)
    Records: 1000000  Deleted: 0  Skipped: 1000000  Warnings: 1803521

Ага, всё понятно, те 32 секунды на hdd - это ошибка была, второй раз прогнал файл по существующим записям... А жаль )

Тогда ещё попробую запихнуть LOAD DATA в одну транзакцию.

    $ sudo cp /mysql_tablespaces/hd2t/xir /var/lib/mysql-files/tradings.d
    $ sudo chown mysql:mysql /var/lib/mysql-files/tradings.d

    mysql> START TRANSACTION READ WRITE; LOAD DATA INFILE '/var/lib/mysql-files/tradings.d' IGNORE INTO TABLE su.tradings FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n'; COMMIT;
    Query OK, 0 rows affected (0,00 sec)

    Query OK, 1000000 rows affected, 65535 warnings (45 min 57,12 sec)
    Records: 1000000  Deleted: 0  Skipped: 0  Warnings: 801662

    Query OK, 0 rows affected (1,67 sec)

То же самое.

Ну и увеличим буфер лога для интересу

    $ sudo cp /mysql_tablespaces/hd2t/xiq /var/lib/mysql-files/tradings.e
    $ sudo chown mysql:mysql /var/lib/mysql-files/tradings.e

    mysql> SET GLOBAL innodb_log_buffer_size = 167772160;
    Query OK, 0 rows affected (0,01 sec)

    mysql> SELECT @@innodb_log_buffer_size;
    +--------------------------+
    | @@innodb_log_buffer_size |
    +--------------------------+
    |                167772160 |
    +--------------------------+
    1 row in set (0,00 sec)

    mysql> START TRANSACTION READ WRITE;
    Query OK, 0 rows affected (0,00 sec)

    mysql> LOAD DATA INFILE '/var/lib/mysql-files/tradings.e' IGNORE INTO TABLE su.tradings FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n';

    mysql> LOAD DATA INFILE '/var/lib/mysql-files/tradings.e' IGNORE INTO TABLE su.tradings FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n';
    Query OK, 1000000 rows affected, 65535 warnings (53 min 35,28 sec)
    Records: 1000000  Deleted: 0  Skipped: 0  Warnings: 797277

    mysql> COMMIT;
    Query OK, 0 rows affected (0,75 sec)

Вобщем каждый следующий лимон льётся дольше предыдущего, что как бы логично.

innodb_log_buffer_size в моём случае на это не повлиял.

На этом всё пока что, думаю, перестройка всех многочисленных индексов su.tradings на hdd съедает всё время.
В оптимизированном варианте таблицы (таблиц) такого количества индексов уже не будет,там может проведём такие опыты с LOAD DATA ещё раз.

## 1. Описать пример транзакции из своего проекта с изменением данных в нескольких таблицах. Реализовать в виде хранимой процедуры.

Таблица su.tradings (файл su_tradings.sql) на первом этапе рефакторинга переливается внешним приложением (php-скрипт) в таблицу sb.tradings (файл sb_tradings.sql).

Набор полей там тот же, но чуть изменены партиции, double поля приведены к decimal-ам и primary key переделан под одиночный уникальный НЕ autoincrement integer, который формируется во внешнем приложении из даты, идентификатора биржи и идентификатора облигации, а в таблице раскладывается обратно на три GENERATED STORED поля.

Далее - второй этап - мы сплитим эту таблицу вертикально на несколько таблиц поменьше, по нескольким причинам, в основном потому, что они пишутся раздельно в разное время, и потому, что размеры одной таблицы нам конкретно мешают например при бэкапе, и т.д. Так же у этих таблиц будет меньше индексов, меньше полей и другие партиции (по факту замеров реальных данных).

Переброс данных из sb.tradings в несколько таблиц пока неясно ещё, как будет осуществляться, но возможно, что и хранимой процедурой, подобной представленной (по крайней мере на стадии резерча я наверняка буду использовать эту процедуру (see sb_split_sb_tradings_next_chunk.sql)):

    /*
    запускать примерно так:
    use sb;
    call split_sb_tradings_next_chunk(255, '2019-04-09', '238, 242, 1102, 1116, 1117, 1120, 1190, 1504, 1556, 1641', @rc, @err);
    */
    use sb;
    DELIMITER ;;
    CREATE DEFINER = `sb`@`%` PROCEDURE split_sb_tradings_next_chunk(
        IN in_trading_ground_id INT
        , IN in_anchor_date DATE
        , IN in_bonds_ids VARCHAR(10000)
        , OUT rc VARCHAR(45)
        , OUT err VARCHAR(1000)
    ) MODIFIES SQL DATA
    main:BEGIN
        DECLARE l_src_part_num VARCHAR(4);
        DECLARE l_dest_part_num VARCHAR(4);
        DECLARE l_all_fields VARCHAR(2500);
        DECLARE l_sql_select VARCHAR(14000);
        DECLARE l_prices_fields VARCHAR(500);
        DECLARE l_yields_fields VARCHAR(500);
        DECLARE l_volumes_fields VARCHAR(500);
        DECLARE l_risks_metrics_fields VARCHAR(500);
        DECLARE l_spreads_fields VARCHAR(500);

        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            GET DIAGNOSTICS CONDITION 1
            rc = RETURNED_SQLSTATE, err = MESSAGE_TEXT;
            ROLLBACK;
            RESIGNAL;
        END;

        CASE
        WHEN in_trading_ground_id <   2 THEN SET l_src_part_num = 'p1';
        WHEN in_trading_ground_id <   5 THEN SET l_src_part_num = 'p4';
        WHEN in_trading_ground_id <   7 THEN SET l_src_part_num = 'p6';
        WHEN in_trading_ground_id <  10 THEN SET l_src_part_num = 'p9';
        WHEN in_trading_ground_id <  11 THEN SET l_src_part_num = 'p10';
        WHEN in_trading_ground_id <  21 THEN SET l_src_part_num = 'p20';
        WHEN in_trading_ground_id <  26 THEN SET l_src_part_num = 'p25';
        WHEN in_trading_ground_id <  29 THEN SET l_src_part_num = 'p28';
        WHEN in_trading_ground_id <  30 THEN SET l_src_part_num = 'p29';
        WHEN in_trading_ground_id <  52 THEN SET l_src_part_num = 'p51';
        WHEN in_trading_ground_id <  70 THEN SET l_src_part_num = 'p69';
        WHEN in_trading_ground_id <  72 THEN SET l_src_part_num = 'p71';
        WHEN in_trading_ground_id <  88 THEN SET l_src_part_num = 'p87';
        WHEN in_trading_ground_id < 110 THEN SET l_src_part_num = 'p109';
        WHEN in_trading_ground_id < 120 THEN SET l_src_part_num = 'p119';
        WHEN in_trading_ground_id < 146 THEN SET l_src_part_num = 'p145';
        WHEN in_trading_ground_id < 150 THEN SET l_src_part_num = 'p149';
        WHEN in_trading_ground_id < 200 THEN SET l_src_part_num = 'p199';
        WHEN in_trading_ground_id < 300 THEN SET l_src_part_num = 'p299';
        WHEN in_trading_ground_id < 400 THEN SET l_src_part_num = 'p399';
        WHEN in_trading_ground_id < 500 THEN SET l_src_part_num = 'p499';
        ELSE SET l_src_part_num = 'p0';
        END CASE;

        CASE
        WHEN in_trading_ground_id <   4 THEN SET l_dest_part_num = 'p1';
        WHEN in_trading_ground_id <   5 THEN SET l_dest_part_num = 'p4';
        WHEN in_trading_ground_id <   8 THEN SET l_dest_part_num = 'p7';
        WHEN in_trading_ground_id <  20 THEN SET l_dest_part_num = 'p19';
        WHEN in_trading_ground_id <  21 THEN SET l_dest_part_num = 'p20';
        WHEN in_trading_ground_id <  71 THEN SET l_dest_part_num = 'p70';
        WHEN in_trading_ground_id <  72 THEN SET l_dest_part_num = 'p71';
        WHEN in_trading_ground_id <  91 THEN SET l_dest_part_num = 'p90';
        WHEN in_trading_ground_id <  92 THEN SET l_dest_part_num = 'p91';
        WHEN in_trading_ground_id < 110 THEN SET l_dest_part_num = 'p109';
        WHEN in_trading_ground_id < 120 THEN SET l_dest_part_num = 'p119';
        WHEN in_trading_ground_id < 150 THEN SET l_dest_part_num = 'p149';
        WHEN in_trading_ground_id < 168 THEN SET l_dest_part_num = 'p167';
        WHEN in_trading_ground_id < 237 THEN SET l_dest_part_num = 'p236';
        WHEN in_trading_ground_id < 241 THEN SET l_dest_part_num = 'p240';
        WHEN in_trading_ground_id < 245 THEN SET l_dest_part_num = 'p244';
        WHEN in_trading_ground_id < 255 THEN SET l_dest_part_num = 'p254';
        WHEN in_trading_ground_id < 256 THEN SET l_dest_part_num = 'p255';
        WHEN in_trading_ground_id < 259 THEN SET l_dest_part_num = 'p258';
        WHEN in_trading_ground_id < 301 THEN SET l_dest_part_num = 'p300';
        WHEN in_trading_ground_id < 334 THEN SET l_dest_part_num = 'p333';
        WHEN in_trading_ground_id < 415 THEN SET l_dest_part_num = 'p414';
        WHEN in_trading_ground_id < 500 THEN SET l_dest_part_num = 'p499';
        ELSE SET l_dest_part_num = 'p0';
        END CASE;

        /* fields for select from sb.tradings to cte */
        SET l_all_fields = CONCAT(
        '      `id`\n',
        '    , `boardid`\n',
        '    , `clear_price`, `buying_quote`, `selling_quote`, `last_price`\n',
        '    , `open_price`, `max_price`, `min_price`, `avar_price`, `mid_price`\n',
        '    , `marketprice`, `marketprice2`, `admittedquote`, `legalcloseprice`\n',
        '    , `clearance_profit`, `offer_profit`, `clearance_profit_effect`\n',
        '    , `offer_profit_effect`, `coupon_profit_effect`, `current_yield`\n',
        '    , `clearance_profit_nominal`, `offer_profit_nominal`\n',
        '    , `ytm_bid`, `yto_bid`, `ytc_bid`\n',
        '    , `ytm_offer`, `yto_offer`, `ytc_offer`\n',
        '    , `ytm_last`, `yto_last`, `ytc_last`\n',
        '    , `ytm_close`, `yto_close`, `ytc_close`\n',
        '    , `overturn`, `volume`, `volume_money`, `agreement_number`\n',
        '    , `dur`, `dur_to`, `dur_mod`, `dur_mod_to`\n',
        '    , `pvbp`, `pvbp_offer`, `convexity`, `convexity_offer`\n',
        '    , `g_spread`, `t_spread`, `t_spread_benchmark`\n'
        );

        /* select from sb.tradings */
        /*
        в этой части я перечисляю все поля, необходимые для всех
        пяти таблиц, так как надеюсь, что CTE не будет реально
        обращаться к БД все пять раз, а идентичные SELECT-ы
        возьмёт из кеша
        */
        SET l_sql_select = CONCAT(
        '    SELECT\n',
        l_all_fields,
        '    FROM\n',
        '      sb.tradings PARTITION (', l_src_part_num, ')\n',
        '    WHERE\n',
        '      `place_id` = ', in_trading_ground_id, '\n',
        '      AND `date` = "', in_anchor_date, '"\n',
        '      AND `emission_id` IN (', in_bonds_ids, ')\n',
        '    ORDER BY NULL'
        );

        /* fields for select from cte and insert into tsq.prices */
        SET l_prices_fields = CONCAT(
            '`id`, `boardid`',
            ', `clear_price`, `buying_quote`, `selling_quote`, `last_price`',
            ', `open_price`, `max_price`, `min_price`, `avar_price`, `mid_price`',
            ', `marketprice`, `marketprice2`, `admittedquote`, `legalcloseprice`'
        );

        /* fields for select from cte and insert into tsq.yields */
        SET l_yields_fields = CONCAT(
            '`id`',
            ', `clearance_profit`, `offer_profit`, `clearance_profit_effect`',
            ', `offer_profit_effect`, `coupon_profit_effect`, `current_yield`',
            ', `clearance_profit_nominal`, `offer_profit_nominal`',
            ', `ytm_bid`, `yto_bid`, `ytc_bid`',
            ', `ytm_offer`, `yto_offer`, `ytc_offer`',
            ', `ytm_last`, `yto_last`, `ytc_last`',
            ', `ytm_close`, `yto_close`, `ytc_close`'
        );

        /* fields for select from cte and insert into tsq.volumes */
        SET l_volumes_fields = CONCAT(
            '`id`',
            ', `overturn`, `volume`, `volume_money`, `agreement_number`'
        );

        /* fields for select from cte and insert into tsq.risks_metrics */
        SET l_risks_metrics_fields = CONCAT(
            '`id`',
            ', `dur`, `dur_to`, `dur_mod`, `dur_mod_to`',
            ', `pvbp`, `pvbp_offer`, `convexity`, `convexity_offer`'
        );

        /* fields for select from cte and insert into tsq.spreads */
        SET l_spreads_fields = CONCAT(
            '`id`',
            ', `g_spread`, `t_spread`, `t_spread_benchmark`'
        );

        /* INSERT INTO tsq.prices */
        SET @sql_prices = CONCAT(
            'INSERT IGNORE INTO tsq.prices PARTITION (', l_dest_part_num, ') (\n',
            l_prices_fields,
            ') WITH cte (',
            l_all_fields,
            ') AS (',
            l_sql_select,
            ') SELECT ',
            l_prices_fields,
            ' FROM cte'
        );

        /* debug
        SELECT @sql_prices;
        LEAVE main;
        */

        /* INSERT INTO tsq.yields */
        SET @sql_yields = CONCAT(
            'INSERT IGNORE INTO tsq.yields PARTITION (', l_dest_part_num, ') (\n',
            l_yields_fields,
            ') WITH cte (',
            l_all_fields,
            ') AS (',
            l_sql_select,
            ') SELECT ',
            l_yields_fields,
            ' FROM cte'
        );

        /* INSERT INTO tsq.volumes */
        SET @sql_volumes = CONCAT(
            'INSERT IGNORE INTO tsq.volumes PARTITION (', l_dest_part_num, ') (\n',
            l_volumes_fields,
            ') WITH cte (',
            l_all_fields,
            ') AS (',
            l_sql_select,
            ') SELECT ',
            l_volumes_fields,
            ' FROM cte'
        );

        /* INSERT INTO tsq.risks_metrics */
        SET @sql_risks_metrics = CONCAT(
            'INSERT IGNORE INTO tsq.risks_metrics PARTITION (', l_dest_part_num, ') (\n',
            l_risks_metrics_fields,
            ') WITH cte (',
            l_all_fields,
            ') AS (',
            l_sql_select,
            ') SELECT ',
            l_risks_metrics_fields,
            ' FROM cte'
        );

        /* INSERT INTO tsq.spreads */
        SET @sql_spreads = CONCAT(
            'INSERT IGNORE INTO tsq.spreads PARTITION (', l_dest_part_num, ') (\n',
            l_spreads_fields,
            ') WITH cte (',
            l_all_fields,
            ') AS (',
            l_sql_select,
            ') SELECT ',
            l_spreads_fields,
            ' FROM cte'
        );

        START TRANSACTION READ WRITE;

        PREPARE s1 FROM @sql_prices;
        EXECUTE s1;
        DEALLOCATE PREPARE s1;

        PREPARE s2 FROM @sql_yields;
        EXECUTE s2;
        DEALLOCATE PREPARE s2;

        PREPARE s3 FROM @sql_volumes;
        EXECUTE s3;
        DEALLOCATE PREPARE s3;

        PREPARE s4 FROM @sql_risks_metrics;
        EXECUTE s4;
        DEALLOCATE PREPARE s4;

        PREPARE s5 FROM @sql_spreads;
        EXECUTE s5;
        DEALLOCATE PREPARE s5;

        COMMIT;
    END ;;
    DELIMITER ;

На домашней машине (вне кластера и без репликации и т.п.) проверил - всё работает.