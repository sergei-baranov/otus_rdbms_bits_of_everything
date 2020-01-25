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