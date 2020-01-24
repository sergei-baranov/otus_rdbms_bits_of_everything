##2. Загрузить данные из приложенных в материалах csv.<br/>Реализовать следующими путями: LOAD DATA, mysqlimport.
###2.1. LOAD DATA

История такая:

Для переноса на домашнюю машину одной жирной таблицы для опытов
мне сисадмины выгрузили её в csv-файл.
Там 250М строк, файл 110G весом.

Я разбил его на куски по 1М строк и загрузил через LOAD DATA 5 из них в бд.
Это было ещё в декабре, восстанавливаю историю из чата общения с сисадминами.

Исходный файл:
    feynman@feynman-desktop:/mysql_tablespaces/hd2t$ ls -lah
    итого 231G
    -rwxr-xr-x  1 root    root    104G дек  6 02:14 tradings.txt
    ...

Разбил через split -l 1000000 tradings.txt:
    feynman@feynman-desktop:/mysql_tablespaces/hd2t$ ls -lah
    итого 231G
    -rwxr-xr-x  1 root    root    104G дек  6 02:14 tradings.txt
    -rwxr-xr-x  1 root    root     24G дек  6 01:45 t.tar.bz2
    ...
    -rw-r--r--  1 root    root    506M дек  8 04:48 xiy
    -rw-r--r--  1 root    root    506M дек  8 04:49 xiz
    -rw-r--r--  1 root    root    508M дек  8 04:49 xja
    -rw-r--r--  1 root    root    140M дек  8 04:49 xjb

Строки в файлах вот такие:
    feynman@feynman-desktop:/mysql_tablespaces/hd2t$ tail -n 1 xjb
    2377884327,2019-09-05,397,100,0,0,0,0,0,0,0,0,0,\N,0000-00-00,\N,171575,\N,\N,\N,\N,\N,\N,\N,\N,\N,\N,826.5,2019-09-05-171575-39,0.068710061306015,\N,\N,\N,0.06875,\N,\N,\N,\N,\N,\N,\N,\N,\N,\N,0,\N,0,0,0,0,1.8770491803279,\N,\N,\N,\N,\N,0,0,0,0,0,2019-09-05 15:05:37,\N,\N,\N,\N,\N,\N,\N,0,\N,\N,\N,\N

Определил директорию для файлов
    mysql> SELECT @@secure_file_priv;
    +-----------------------+
    | @@secure_file_priv    |
    +-----------------------+
    | /var/lib/mysql-files/ |
    +-----------------------+

Копировал файлы в неё, ставил разрешения
    feynman@feynman-desktop:/mysql_tablespaces/hd2t$ sudo cp ./xjb /var/lib/mysql-files/xjb
    sudo chown mysql /var/lib/mysql-files/xjb
    sudo chgrp mysql /var/lib/mysql-files/xjb

Была ещё одна заморока с apparmor-ом. Не помню точно как, но как-то сказал ему, что можно mysql это делать.


И заливал
    mysql> LOAD DATA INFILE '/var/lib/mysql-files/xja' IGNORE INTO TABLE su.tradings FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n';
    Query OK, 1000000 rows affected, 65535 warnings (9 min 32,10 sec)
    Records: 1000000  Deleted: 0  Skipped: 0  Warnings: 766849

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

Варнинги смотрел через SHOW WARNINGS; - там ругалось на поля типа date со значением 0000-00-00, но записи заливало:

    mysql> SELECT COUNT(*) FROM su.tradings;
    +----------+
    | COUNT(*) |
    +----------+
    |  2275129 |
    +----------+
    1 row in set (7,63 sec)

Собственно, после этого очень быстро залил 5М записей на опыты.