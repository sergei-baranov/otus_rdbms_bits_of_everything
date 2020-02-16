ДЗ OTUS-RDBMS-2019-10 по занятию 21 - Внутренняя архитектура СУБД PostgreSQL
---------------------------------------------------------
Установка СУБД PostgreSQL
---------------------------------------------------------

Цель: создаем кластер PostgreSQL в докере или на виртуальной машине, запускаем сервер и подключаем клиента.

1. Развернуть контейнер с PostgreSQL или установить СУБД на виртуальную машину.
1. Запустить сервер.
1. Создать клиента с подключением к базе данных postgres через командную строку.
1. Подключиться к серверу используя pgAdmin или другое аналогичное приложение.

## 1. Развернуть контейнер с PostgreSQL или установить СУБД на виртуальную машину.
## 2. Запустить сервер.

Ставлю на домашнюю Ubuntu. Подключаюсь с ноутбука с виндой.

    $ lsb_release -a
    No LSB modules are available.
    Distributor ID: Ubuntu
    Description:    Ubuntu 18.04.4 LTS
    Release:        18.04
    Codename:       bionic

Вот тут - https://postgrespro.ru/docs/postgrespro/11/binary-installation-on-linux - читаю:

    16.1.2. Быстрая установка и настройка
    Если вам нужно установить только один экземпляр Postgres Pro и вы не собираетесь использовать никакие другие продукты на базе PostgreSQL в вашей системе, вы можете использовать режим быстрой установки. Типичная процедура установки в этом случае выглядит так:

    Подключите репозиторий пакетов, предназначенный для вашей операционной системы. Конкретные адреса репозиториев и команды для их подключения в поддерживаемых дистрибутивах Linux вы можете найти на Странице загрузки для соответствующей версии Postgres Pro.

    Установите пакет postgrespro-std-11. При этом по зависимостям установятся все требуемые компоненты, будет создана база данных по умолчанию, запущен сервер баз данных и настроен автозапуск сервера при загрузке системы, а все предоставляемые программы станут доступными в пути PATH. В режиме быстрой установки кластер баз данных инициализируется с включёнными контрольными суммами.

    После завершения установки вы можете запустить psql от имени пользователя postgres и подключиться к только что созданной базе данных, находящийся в каталоге данных /var/lib/pgpro/std-11/data.

    Так как база данных по умолчанию создаётся скриптом pg-setup, путь к каталогу данных сохраняется в файле /etc/default/postgrespro-std-11. Все последующие команды pg-setup, а также любые команды, управляющие службой Postgres Pro, будут нацелены именно на эту базу данных.

    и так далее

Регистрируюсь на https://postgrespro.ru/products/download/postgrespro/11.6.1,
указываю версию продукта 11.6.1, версию ОС Ubuntu 18.0.4, получаю инструкцию:

    Продукт: Postgres Pro Standard 11.6.1
    Платформа: x86_64
    Пакет: postgrespro-std-11-server

    Установка

    apt-get update -y
    apt-get install -y wget gnupg2 || apt-get install -y gnupg
    wget -O - http://repo.postgrespro.ru/keys/GPG-KEY-POSTGRESPRO | apt-key add -
    echo deb http://repo.postgrespro.ru//pgpro-archive/pgpro-11.6.1/ubuntu bionic main > /etc/apt/sources.list.d/postgrespro-std.list
    apt-get update -y
    apt-get install -y postgrespro-std-11-server
    /opt/pgpro/std-11/bin/pg-setup initdb
    /opt/pgpro/std-11/bin/pg-setup service enable
    service postgrespro-std-11 start

    Пакеты

    mamonsu
    orafce-std-11
    pageprep-std-11
    pg-filedump-std-11
    pg-portal-modify-std-11
    pg-probackup-std-11
    pg-repack-std-11
    pgbouncer
    pgpro-pgbadger
    pldebugger-std-11
    postgrespro-std-11-backup-src
    postgrespro-std-11-client
    postgrespro-std-11-contrib
    postgrespro-std-11-dev
    postgrespro-std-11-docs-ru
    postgrespro-std-11-docs
    postgrespro-std-11-jit
    postgrespro-std-11-libs
    postgrespro-std-11-pgprobackup
    postgrespro-std-11-plperl
    postgrespro-std-11-plpython3
    postgrespro-std-11-plpython
    postgrespro-std-11-pltcl
    postgrespro-std-11-server
    postgrespro-std-11

Делаю всё по инструкции через sudo:

    $ sudo apt-get update -y
    ...
    $ sudo apt-get install mamonsu
    ...

Дале устанавливаю клиента:

    sudo apt-get install postgresql-client
    ...

Смотрим, что в файле /etc/default/postgrespro-std-11:

    $ cat /etc/default/postgrespro-std-11
    PGDATA=/var/lib/pgpro/std-11/data

Смотрим, что тама:

    $ sudo ls -lah /var/lib/pgpro/std-11/data
    итого 136K
    drwx------ 20 postgres postgres 4,0K фев 13 03:38 .
    drwxr-xr-x  3 postgres postgres 4,0K фев 13 03:33 ..
    drwx------  5 postgres postgres 4,0K фев 13 03:33 base
    -rw-------  1 postgres postgres   44 фев 13 03:38 current_logfiles
    drwx------  2 postgres postgres 4,0K фев 13 03:33 global
    drwx------  2 postgres postgres 4,0K фев 13 03:38 log
    drwx------  2 postgres postgres 4,0K фев 13 03:33 pg_commit_ts
    drwx------  2 postgres postgres 4,0K фев 13 03:33 pg_dynshmem
    -rw-------  1 postgres postgres 4,2K фев 13 03:33 pg_hba.conf
    -rw-------  1 postgres postgres 1,6K фев 13 03:33 pg_ident.conf
    drwx------  4 postgres postgres 4,0K фев 13 03:43 pg_logical
    drwx------  4 postgres postgres 4,0K фев 13 03:33 pg_multixact
    drwx------  2 postgres postgres 4,0K фев 13 03:38 pg_notify
    drwx------  2 postgres postgres 4,0K фев 13 03:33 pg_replslot
    drwx------  2 postgres postgres 4,0K фев 13 03:33 pg_serial
    drwx------  2 postgres postgres 4,0K фев 13 03:33 pg_snapshots
    drwx------  2 postgres postgres 4,0K фев 13 03:33 pg_stat
    drwx------  2 postgres postgres 4,0K фев 13 04:08 pg_stat_tmp
    drwx------  2 postgres postgres 4,0K фев 13 03:33 pg_subtrans
    drwx------  2 postgres postgres 4,0K фев 13 03:33 pg_tblspc
    drwx------  2 postgres postgres 4,0K фев 13 03:33 pg_twophase
    -rw-------  1 postgres postgres    3 фев 13 03:33 PG_VERSION
    drwx------  3 postgres postgres 4,0K фев 13 03:33 pg_wal
    drwx------  2 postgres postgres 4,0K фев 13 03:33 pg_xact
    -rw-------  1 postgres postgres   88 фев 13 03:33 postgresql.auto.conf
    -rw-------  1 postgres postgres  24K фев 13 03:33 postgresql.conf
    -rw-------  1 postgres postgres   65 фев 13 03:38 postmaster.opts
    -rw-------  1 postgres postgres   92 фев 13 03:38 postmaster.pid

Согласно инструкции вот тут - https://www.postgresql.org/docs/11/creating-cluster.html:

    sudo initdb -D /var/lib/pgpro/std-11/data

Редактируем postgresql.conf:

    sudo nano /var/lib/pgpro/std-11/data/postgresql.conf
    ...
    listen_addresses = '*'
    ...

Редактируем pg_hba.conf:

    sudo nano /var/lib/pgpro/std-11/data/pg_hba.conf

    # TYPE  DATABASE        USER            ADDRESS                 METHOD
    # "local" is for Unix domain socket connections only
    local   all             all                                     trust
    # IPv4 local connections:
    host    all             all             127.0.0.1/32            trust
    # IPv6 local connections:
    host    all             all             ::1/128                 trust

Редактируем pg_ident.conf:

    sudo nano /var/lib/pgpro/std-11/data/pg_ident.conf

    # MAPNAME       SYSTEM-USERNAME         PG-USERNAME
    mymap           feynman                 guest
    mymap           root                    postgres


Потом выполнил:

    $ sudo /opt/pgpro/std-11/bin/pg-setup service stop
    $ sudo /opt/pgpro/std-11/bin/pg-setup service start
    $ sudo psql -U postgres -w

и оно меня пустило:

    $ sudo psql -U postgres -w
    psql (11.6)
    Введите "help", чтобы получить справку.

    postgres=# \d
    Отношения не найдены.
    postgres=# quit
    
смотрим список баз:

    postgres=# select datname, encoding, datcollate, datistemplate, datallowconn from pg_database;
      datname  | encoding |   datcollate    | datistemplate | datallowconn
    -----------+----------+-----------------+---------------+--------------
     postgres  |        6 | ru_RU.UTF-8@icu | f             | t
     template1 |        6 | ru_RU.UTF-8@icu | t             | t
     template0 |        6 | ru_RU.UTF-8@icu | t             | f
    (3 строки)


## 3. Создать клиента с подключением к базе данных postgres через командную строку.
## 4. Подключиться к серверу используя pgAdmin или другое аналогичное приложение.

Подключаться решил пока что через DBeaver с ноутбука.
ip машины с Ubuntu 192.168.1.64, ip ноутбука 192.168.1.45.

В консоли постгреса задаю пароль пользователю postgres:

    postgres=# ALTER USER postgres WITH PASSWORD 'secret';
    ALTER ROLE
    postgres=#

На ноутбуке выбираю в DBeaver "Создать соединение" -> "PosthreSQL" -> кнопка "Далее", ввожу настройки:

    Хост: 192.168.1.64
    Порт: 5432
    База данных: postgres
    Пользователь: postgres
    Пароль: secret

Соединяюсь и получаю сообщение:

    ВАЖНО: в pg_hba.conf нет записи для компьютера "192.168.1.45",
    пользователя "postgres", базы "postgres", SSL выкл.
    
В баше Убунты правлю опять pg_hba.conf:

    login as: feynman
    feynman@192.168.1.64's password:
    Welcome to Ubuntu 18.04.4 LTS (GNU/Linux 5.3.0-28-generic x86_64)
    feynman@feynman-desktop:~$ sudo nano /var/lib/pgpro/std-11/data/pg_hba.conf
    [sudo] пароль для feynman:
    ...
    
Добавляю запись:

    # TYPE  DATABASE    USER    ADDRESS         METHOD
    ...
    # my notebook
    host    all         all     192.168.1.45    trust

Сохраняю, перезапускаю сервер:

    feynman@feynman-desktop:~$ sudo /opt/pgpro/std-11/bin/pg-setup service stop
    feynman@feynman-desktop:~$ sudo /opt/pgpro/std-11/bin/pg-setup service start
    Job for postgrespro-std-11.service failed because the control process exited with error code.
    See "systemctl status postgrespro-std-11.service" and "journalctl -xe" for details.
    
Смотрим логи:

    feynman@feynman-desktop:~$ journalctl -xe  --no-pager
    -- Начат процесс запуска юнита postgrespro-std-11.service.
    фев 16 18:02:36 feynman-desktop postgres[18696]: 2020-02-16 18:02:36.079 MSK [18696] СООБЩЕНИЕ:  для приёма подключений по адресу IPv4 "0.0.0.0" открыт порт 5432
    фев 16 18:02:36 feynman-desktop postgres[18696]: 2020-02-16 18:02:36.080 MSK [18696] СООБЩЕНИЕ:  для приёма подключений по адресу IPv6 "::" открыт порт 5432
    фев 16 18:02:36 feynman-desktop postgres[18696]: 2020-02-16 18:02:36.082 MSK [18696] СООБЩЕНИЕ:  для приёма подключений открыт Unix-сокет "/tmp/.s.PGSQL.5432"
    фев 16 18:02:36 feynman-desktop postgres[18696]: 2020-02-16 18:02:36.094 MSK [18696] СООБЩЕНИЕ:  передача вывода в протокол процессу сбора протоколов
    фев 16 18:02:36 feynman-desktop postgres[18696]: 2020-02-16 18:02:36.094 MSK [18696] ПОДСКАЗКА:  В дальнейшем протоколы будут выводиться в каталог "log".
    фев 16 18:02:36 feynman-desktop systemd[1]: postgrespro-std-11.service: Main process exited, code=exited, status=1/FAILURE
    фев 16 18:02:36 feynman-desktop systemd[1]: postgrespro-std-11.service: Killing process 18719 (postgres) with signal SIGKILL.
    фев 16 18:02:36 feynman-desktop systemd[1]: postgrespro-std-11.service: Failed with result 'exit-code'.
    фев 16 18:02:36 feynman-desktop systemd[1]: Failed to start Postgres Pro std 11 database server.

Смотрим вторые:

    feynman@feynman-desktop:~$ systemctl status postgrespro-std-11.service
    всё то же самое
    
Трохи гуглю и добавляю в запись в pg_hba.conf /32 у адресу клиента:

    # my notebook
    host    all    all    192.168.1.45/32    trust
     
Перезапускаю сервер:
 
    feynman@feynman-desktop:~$ sudo /opt/pgpro/std-11/bin/pg-setup service stop
    feynman@feynman-desktop:~$ sudo /opt/pgpro/std-11/bin/pg-setup service start
    feynman@feynman-desktop:~$

Опять пробую подконнектиться с ноутбука через DBeaver.
Получилось!

Вижу схему public, в ней пусто. Вижу два табличных пространства: pg_default и pg_global.
И так далее.

Правда, я подключаюсь через trust метод в pg_hba.conf.
Меняю trust на password:

    # TYPE  DATABASE    USER    ADDRESS            METHOD
    ...
    # my notebook
    host    all         all     192.168.1.45/32    password

Перезапускаю сервер, он запускается:

    feynman@feynman-desktop:~$ sudo /opt/pgpro/std-11/bin/pg-setup service stop
    feynman@feynman-desktop:~$ sudo /opt/pgpro/std-11/bin/pg-setup service start
    feynman@feynman-desktop:~$

В настройках DBeaver-а меняю пароль secret на qwerty.
Коннекчусь, получаю ошибку:

    ВАЖНО: пользователь "postgres" не прошёл проверку подлинности (по паролю)
    
В настройках DBeaver-а меняю пароль qwerty на secret.
Коннекчусь - всё работает!

Считаю, что всё прошло успешно, и первое дз по постгресу выполнено.
Незашифрованный пароль конечно, детский сад, но для начала на домашней машине пойдёт.

** **
**PS: пообщался с сисадмином, установил md5 для пароля, задал пароль secret2:**

    $ sudo nano /var/lib/pgpro/std-11/data/pg_hba.conf

    # TYPE  DATABASE    USER    ADDRESS            METHOD
    ...
    # my notebook
    host    all         all     192.168.1.45/32    md5
    
    $ sudo su - postgres
    [sudo] пароль для feynman:
    postgres@feynman-desktop:~$ psql
    psql (11.6)
    Введите "help", чтобы получить справку.
    postgres=# \password postgres
    Введите новый пароль:
    Повторите его:
    postgres=# quit
    postgres@feynman-desktop:~$

    $ s sudo /opt/pgpro/std-11/bin/pg-setup service stop
    $ s sudo /opt/pgpro/std-11/bin/pg-setup service start

Коннекчусь DBeaver-ом, получаю ошибку:

    ВАЖНО: пользователь "postgres" не прошёл проверку подлинности (по паролю)

В настройках DBeaver-а меняю пароль secret на secret2.
Коннекчусь - всё работает!



