Домашнее задание - востановить таблицу из бэкапа
------------------------------------------------

Цель: В этом ДЗ осваиваем инструмент для резервного копирования и восстановления - xtrabackup. Задача восстановить конкретную таблицу из сжатого и шифрованного бэкапа.

в материалах приложен файл бэкапа backup.xbstream.gz.des3 и дамп структуры базы otus - otus-db.dmp.

Бэкап был выполнен с помощью команды
    xtrabackup --databases='otus' --backup --stream=xbstream | gzip - | openssl des3 -salt -k "password" > backup.xbstream.gz.des3

Требуется восстановить таблицу otus.articles из бэкапа (otus-db.dmp + backup.xbstream.gz.des3)
==============================================================================================

Создаём БД:

    mysql> CREATE DATABASE otus CHARACTER SET = utf8mb4;
    Query OK, 1 row affected (0,00 sec)

    feynman@feynman-desktop:~$ ls -lsh /var/lib/mysql/otus
    итого 0

Заливаем струнутуру из дампа:

    feynman@feynman-desktop:~$ mysql -e "source /home/feynman/otus_db-4560-3521f1.dmp" otus -uroot -p

    mysql> SHOW TABLES IN otus;
    +------------------+
    | Tables_in_otus |
    +------------------+
    | Python_Employee |
    | articles |
    | bin_test |
    | myset |
    ...
    +------------------+
    14 rows in set (0,00 sec)

Таблицы otus.articles пустая:

    mysql> SELECT COUNT(*) AS cnt FROM otus.articles;
    +-----+
    | cnt |
    +-----+
    | 0 |
    +-----+
    1 row in set (0,00 sec)

Файловая структура:

    feynman@feynman-desktop:~$ ls -lsh /var/lib/mysql/otus
    итого 2,0M
    112K -rw-r----- 1 mysql mysql 128K янв 22 01:39 articles.ibd
    80K -rw-r----- 1 mysql mysql 112K янв 22 01:39 bin_test.ibd
    80K -rw-r----- 1 mysql mysql 112K янв 22 01:39 fts_00000000000007f7_0000000000003f7d_index_1.ibd
    ...

Расшифровываем (тут была проблема, пока не добавили -md md5):

    feynman@feynman-desktop:~$ openssl des3 -salt -k "password" -d -in /home/feynman/backup.xbstream.gz-4560-0d8b3a.des3 -md md5 -out /home/feynman/backup.xbstream.gz
    *** WARNING : deprecated key derivation used.
    Using -iter or -pbkdf2 would be better.

Распаковываем архив:

    feynman@feynman-desktop:~$ gzip -d /home/feynman/backup.xbstream.gz
    feynman@feynman-desktop:~$ ls -lah /home/feynman
    итого 79M
    ...
    -rw-rw-r-- 1 feynman feynman 74M янв 22 22:45 backup.xbstream
    ...

Устанавливаем xtrabackup:

    feynman@feynman-desktop:~$ sudo apt install percona-xtrabackup
    ...

Распаковываем стрим в файлы:

    feynman@feynman-desktop:~$ mkdir /home/feynman/otus_backup
    feynman@feynman-desktop:~$ mv /home/feynman/backup.xbstream /home/feynman/otus_backup/backup.xbstream
    feynman@feynman-desktop:~$ cd /home/feynman/otus_backup
    feynman@feynman-desktop:~/otus_backup$ xbstream -x < backup.xbstream
    feynman@feynman-desktop:~/otus_backup$ ls -lah otus
    итого 13M
    drwxr-x--- 2 feynman feynman 4,0K янв 22 22:53 .
    drwxrwxr-x 3 feynman feynman 4,0K янв 22 22:53 ..
    -rw-r----- 1 feynman feynman 128K янв 22 22:53 articles.ibd
    -rw-r----- 1 feynman feynman 112K янв 22 22:53 bin_test.ibd
    ...

Убиваем articles.ibd, но не руками, а DISCARD TABLESPACE:

    feynman@feynman-desktop:~/otus_backup$ ls -lah /var/lib/mysql/otus
    итого 2,0M
    drwxr-x--- 2 mysql mysql 4,0K янв 22 01:39 .
    drwxr-x--- 13 mysql mysql 4,0K янв 22 01:26 ..
    -rw-r----- 1 mysql mysql 128K янв 22 01:39 articles.ibd
    -rw-r----- 1 mysql mysql 112K янв 22 01:39 bin_test.ibd


    mysql> ALTER TABLE otus.articles DISCARD TABLESPACE;
    Query OK, 0 rows affected (0,05 sec)

    feynman@feynman-desktop:~/otus_backup$ ls -lah /var/lib/mysql/otus
    итого 2,0M
    drwxr-x--- 2 mysql mysql 4,0K янв 22 01:39 .
    drwxr-x--- 13 mysql mysql 4,0K янв 22 01:26 ..
    -rw-r----- 1 mysql mysql 112K янв 22 01:39 bin_test.ibd

Копируем articles.ibd из бэкапа:

    feynman@feynman-desktop:~/otus_backup$ sudo cp ~/otus_backup/otus/articles.ibd /var/lib/mysql/otus/articles.ibd
    [sudo] пароль для feynman:
    feynman@feynman-desktop:~/otus_backup$ ls -lah /var/lib/mysql/otus
    итого 1,2M
    drwxr-x--- 2 mysql mysql 4,0K янв 22 23:05 .
    drwxr-x--- 13 mysql mysql 4,0K янв 22 01:26 ..
    -rw-r----- 1 root root 128K янв 22 23:05 articles.ibd
    -rw-r----- 1 mysql mysql 112K янв 22 01:39 bin_test.ibd
    ...

Владелец файла должен быть mysql:mysql:

    feynman@feynman-desktop:~/otus_backup$ sudo chown mysql:mysql /var/lib/mysql/otus/articles.ibd
    feynman@feynman-desktop:~/otus_backup$ ls -lah /var/lib/mysql/otus
    итого 1,2M
    drwxr-x--- 2 mysql mysql 4,0K янв 22 23:05 .
    drwxr-x--- 13 mysql mysql 4,0K янв 22 01:26 ..
    -rw-r----- 1 mysql mysql 128K янв 22 23:05 articles.ibd
    -rw-r----- 1 mysql mysql 112K янв 22 01:39 bin_test.ibd
    ...

Делаем IMPORT TABLESPACE:

    mysql> ALTER TABLE otus.articles IMPORT TABLESPACE;
    Query OK, 0 rows affected, 2 warnings (0,08 sec)

И на этом всё готово. Проверяем:

    mysql> SELECT COUNT(*) AS cnt FROM otus.articles;
    +-----+
    | cnt |
    +-----+
    | 11 |
    +-----+
    1 row in set (0,01 sec)