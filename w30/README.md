ДЗ OTUS-RDBMS-2019-10 по занятию 30 - PostgreSQL: Кластеризация: patroni
---------------------------------------------------------
Построить отказоустойчивый кластер с помощью patroni
---------------------------------------------------------

Цель: Настраиваем HA кластер на базе Patroni

1. Развернуть кластер PostgreSQL из трех нод. Создать тестовую базу
1. Проверить статус репликации
1. Сделать switchover/failover
1. Поменять конфигурацию PostgreSQL + с параметром требующим перезагрузки
1. Настроить клиентские подключения через HAProxy

---------------------------------------------------------

План такой:

1. Ставим на хостовой машине etcd (https://github.com/etcd-io/etcd)
1. Далее три ноды докера spilo (https://github.com/zalando/spilo)
1. Далее по вышеуказанным пунктам

---------------------------------------------------------

Шаги получились в итоге такие:

1. etcd на хостовой машине
1. spilo. собираю image
1. spilo. запускаю три контейнера
1. Заставляем spilo-контейнеры работать через etcd хоста
1. Интересно почитать, что там в etcd
1. Интересно посмотреть ,что там в patroni rest api
1. Создадим тестовую базу
1. Проверить статус репликации
1. Подключение к мастеру в докер с хостовой машины
1. Делаю failover через patronictl
1. Делаю switchover через рест
1. Настраиваем HAProxy
1. Поменять конфигурацию PostgreSQL + с параметром требующим перезагрузки

---------------------------------------------------------

## 1. etcd на хостовой машине

Иду сюда: http://play.etcd.io/install

В учебных целях всё упрощаю:
Убираю все галки про https и т.д.
Выбираю размер кластера 1 нода.
Больше ничего не меняю.

Далее ниже выбираю вариант запуска systemd.

Потом выполняю тупо все инструкции ниже
(Install on Linux, Run with systemd, Check status)

В итоге получаю:

    $ sudo systemctl enable s1.service
    Created symlink /etc/systemd/system/multi-user.target.wants/s1.service → /etc/systemd/system/s1.service.
    $ sudo systemctl start s1.service
    $ ETCDCTL_API=3 /tmp/test-etcd/etcdctl \
    >   --endpoints localhost:2379 \
    >   endpoint health
    localhost:2379 is healthy: successfully committed proposal: took = 723.141µs

## 2. spilo. собираю image

    $ git clone https://github.com/zalando/spilo.git
    Клонирование в «spilo»…
    remote: Enumerating objects: 13, done.
    remote: Counting objects: 100% (13/13), done.
    remote: Compressing objects: 100% (10/10), done.
    remote: Total 3134 (delta 5), reused 6 (delta 3), pack-reused 3121
    Получение объектов: 100% (3134/3134), 13.72 MiB | 2.28 MiB/s, готово.
    Определение изменений: 100% (2048/2048), готово.
    $ cd spilo
    $ ls
    BUGS.md  CONTRIBUTING.rst  docs             etcd-cluster-appliance  LICENSE     postgres-appliance  spilo_cmd
    contrib  delivery.yaml     ENVIRONMENT.rst  kubernetes              mkdocs.yml  README.rst
    $ cd postgres-appliance
    $ docker build --build-arg COMPRESS=true --tag myspilo .
    ........
    Successfully built c56fc35ddcb2
    Successfully tagged myspilo:latest
    $ docker images
    REPOSITORY    TAG        IMAGE ID        CREATED            SIZE
    myspilo       latest     c56fc35ddcb2    20 minutes ago     129MB

## 3. spilo. запускаю три контейнера

В одном терминале:

    $ docker run -it --name myspilo1 myspilo:latest
    ........
    2020-04-12 22:47:10,921 INFO: Lock owner: f9a4acfa9b65; I am f9a4acfa9b65
    2020-04-12 22:47:10,927 INFO: no action.  i am the leader with the lock
    ........

Во втором терминале:

    $ docker run -it --name myspilo2 myspilo:latest
    ........
    2020-04-12 22:48:47,758 INFO: Lock owner: 96f2bbfbef98; I am 96f2bbfbef98
    2020-04-12 22:48:47,866 INFO: no action.  i am the leader with the lock
    ........
    
Что-то пошло не так. Возможно, надо указать опции для подключения к etcd

## 4. Заставляем spilo-контейнеры работать через etcd хоста

Останавливаем etcd

    $ sudo systemctl stop s1.service
    $ sudo systemctl disable s1.service
    Removed /etc/systemd/system/multi-user.target.wants/s1.service.
    
Конфигурируем его слушать 192.168.1.64

    $ sudo nano /etc/systemd/system/s1.service
    меняем
    --listen-client-urls http://localhost:2379 --advertise-client-urls http://localhost:2379
    на
    --listen-client-urls http://192.168.1.64:2379 --advertise-client-urls http://192.168.1.64:2379
    $ sudo systemctl daemon-reload
    $ sudo systemctl cat s1.service
    # всё норм, вижу 192.168.1.64
    $ sudo systemctl enable s1.service
    Created symlink /etc/systemd/system/multi-user.target.wants/s1.service → /etc/systemd/system/s1.service.
    $ sudo systemctl start s1.service
    $ ETCDCTL_API=3 /tmp/test-etcd/etcdctl \
      --endpoints 192.168.1.64:2379 \
      endpoint health
    192.168.1.64:2379 is healthy: successfully committed proposal: took = 671.445µs
    
Запускаем докер с опцией ETCD_HOST

    $ docker container rm myspilo1
    myspilo1
    $ docker run -it -e ETCD_HOST=192.168.1.64 --name myspilo1 myspilo:latest
    decompressing spilo image...
    ....
    2020-04-13 00:21:09,495 INFO: initialized a new cluster
    2020-04-13 00:21:19,477 INFO: Lock owner: e9477f065cf0; I am e9477f065cf0
    2020-04-13 00:21:19,488 INFO: no action.  i am the leader with the lock
    
Запускаем второй с той же опцией

    $ docker run -it -e ETCD_HOST=192.168.1.64 --name myspilo2 myspilo:latest
    ....
    2020-04-13 00:23:43,313 INFO: Selected new etcd server http://192.168.1.64:2379
    2020-04-13 00:23:43,321 INFO: No PostgreSQL configuration items changed, nothing to reload.
    2020-04-13 00:23:43,327 INFO: Lock owner: e9477f065cf0; I am d0cacc06fa17
    2020-04-13 00:23:43,329 INFO: trying to bootstrap from leader 'e9477f065cf0'
    2020-04-13 00:23:53,326 INFO: Lock owner: e9477f065cf0; I am d0cacc06fa17
    2020-04-13 00:23:53,328 INFO: bootstrap from leader 'e9477f065cf0' in progress
    ...
    2020-04-13 00:25:39,485 INFO: no action.  i am a secondary and i am following a leader

Запускаем третий

    $ docker run -it -e ETCD_HOST=192.168.1.64 --name myspilo3 myspilo:latest
    ...
    2020-04-13 00:36:09,485 INFO: no action.  i am a secondary and i am following a leader

УРА

## 5. Интересно почитать, что там в etcd

/service/

    $ /tmp/test-etcd/etcdctl -C http://192.168.1.64:2379 ls /service/ --recursive
    /service/dummy
    /service/dummy/members
    /service/dummy/members/e9477f065cf0
    /service/dummy/members/d0cacc06fa17
    /service/dummy/members/54be6a8d7513
    /service/dummy/initialize
    /service/dummy/config
    /service/dummy/leader
    /service/dummy/optime
    /service/dummy/optime/leader
    
e9477f065cf0

    $ /tmp/test-etcd/etcdctl -C http://192.168.1.64:2379 get /service/dummy/members/e9477f065cf0
    {
        "conn_url":"postgres://172.17.0.2:5432/postgres",
        "api_url":"http://172.17.0.2:8008/patroni",
        "state":"running",
        "role":"master",
        "version":"1.6.4",
        "xlog_location":100663296,
        "timeline":1
    }
    
d0cacc06fa17

    $ /tmp/test-etcd/etcdctl -C http://192.168.1.64:2379 get /service/dummy/members/d0cacc06fa17
    {
        "conn_url":"postgres://172.17.0.3:5432/postgres",
        "api_url":"http://172.17.0.3:8008/patroni",
        "state":"running",
        "role":"replica",
        "version":"1.6.4",
        "xlog_location":100663296,
        "timeline":1
    }

54be6a8d7513

    $ /tmp/test-etcd/etcdctl -C http://192.168.1.64:2379 get /service/dummy/members/54be6a8d7513
    {
        "conn_url":"postgres://172.17.0.4:5432/postgres",
        "api_url":"http://172.17.0.4:8008/patroni",
        "state":"running",
        "role":"replica",
        "version":"1.6.4",
        "xlog_location":100663296,
        "timeline":1
    }

## 6. Интересно посмотреть ,что там в patroni rest api

    $ wget -O - http://172.17.0.2:8008/master > /dev/null
    --2020-04-14 01:21:55--  http://172.17.0.2:8008/master
    Подключение к 172.17.0.2:8008... соединение установлено.
    HTTP-запрос отправлен. Ожидание ответа… 200 OK
    
    $ wget -O - http://172.17.0.3:8008/master > /dev/null
    --2020-04-14 01:22:11--  http://172.17.0.3:8008/master
    Подключение к 172.17.0.3:8008... соединение установлено.
    HTTP-запрос отправлен. Ожидание ответа… 503 Service Unavailable
    
    $ wget -O - http://172.17.0.4:8008/master > /dev/null
    --2020-04-14 01:22:17--  http://172.17.0.4:8008/master
    Подключение к 172.17.0.4:8008... соединение установлено.
    HTTP-запрос отправлен. Ожидание ответа… 503 Service Unavailable
    
    $ curl -s  http://172.17.0.2:8008/cluster | jq
    {
      "members": [
        {
          "name": "54be6a8d7513",
          "host": "172.17.0.4",
          "port": 5432,
          "role": "replica",
          "state": "running",
          "api_url": "http://172.17.0.4:8008/patroni",
          "timeline": 1,
          "lag": 0
        },
        {
          "name": "d0cacc06fa17",
          "host": "172.17.0.3",
          "port": 5432,
          "role": "replica",
          "state": "running",
          "api_url": "http://172.17.0.3:8008/patroni",
          "timeline": 1,
          "lag": 0
        },
        {
          "name": "e9477f065cf0",
          "host": "172.17.0.2",
          "port": 5432,
          "role": "leader",
          "state": "running",
          "api_url": "http://172.17.0.2:8008/patroni",
          "timeline": 1
        }
      ]
    }
    
## 7. Создадим тестовую базу

Пойдём на мастера и проникнем в psql

    $ docker exec -it myspilo1 bash
    ...
    # pwd
    /home/postgres
    # whoami
    root
    # hostname
    e9477f065cf0
    # psql -h e9477f065cf0 -p 5432 -U postgres -d postgres
    ... всё плохо ...
    # ls
    etc  pgdata  pgq_ticker.ini  postgres.yml
    # cat ./postgres.yml
    ...
    pg_hba:
    - local   all             all                                   trust
    - host    all             all                127.0.0.1/32       md5
    - host    all             all                ::1/128            md5
    - hostssl replication     standby all                md5
    - hostnossl all           all                all                reject
    - hostssl all             all                all                md5
    # psql -U postgres
    ... так пустил ...
    postgres=# \l
                                       List of databases
       Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
    -----------+----------+----------+-------------+-------------+-----------------------
     postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
     template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
               |          |          |             |             | postgres=CTc/postgres
     template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
               |          |          |             |             | postgres=CTc/postgres
    (3 rows)

Создаю бд replicatest и таблицу со строкой в ней

    postgres=# CREATE DATABASE replicatest;
    CREATE DATABASE
    postgres=# \l
                                       List of databases
        Name     |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
    -------------+----------+----------+-------------+-------------+-----------------------
     postgres    | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
     replicatest | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
     
     # \connect replicatest
     You are now connected to database "replicatest" as user "postgres".
     replicatest=# CREATE TABLE IF NOT EXISTS words (word varchar(40) NOT NULL,
     replicatest(#     CONSTRAINT uword UNIQUE(word));
     CREATE TABLE
     replicatest=# \d
                      List of relations
      Schema |         Name          | Type  |  Owner
     --------+-----------------------+-------+----------
      public | pg_stat_kcache        | view  | postgres
      public | pg_stat_kcache_detail | view  | postgres
      public | pg_stat_statements    | view  | postgres
      public | words                 | table | postgres
     (4 rows)
                                                              ^
     replicatest=# insert into words (word) values ('abarakadabra'), ('boo');
     INSERT 0 2
     replicatest=# select * from words;
          word
     --------------
      abarakadabra
      boo
     (2 rows)

## 8. Проверить статус репликации

Сначала пойдём на первую реплику и посмотрим, что там творится по факту:

    $ docker exec -it myspilo2 bash
    # psql -U postgres
    psql (12.2 (Ubuntu 12.2-2.pgdg18.04+1))
    Type "help" for help.
    
    postgres=# \l
                                       List of databases
        Name     |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
    -------------+----------+----------+-------------+-------------+-----------------------
     postgres    | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
     replicatest | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
     template0   | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
                 |          |          |             |             | postgres=CTc/postgres
     template1   | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
                 |          |          |             |             | postgres=CTc/postgres
    (4 rows)
    
    postgres=# # \connect replicatest
    You are now connected to database "replicatest" as user "postgres".
        
    replicatest=# select * from words;
         word
    --------------
     abarakadabra
     boo
    (2 rows)

По факту репликация работает

Теперь проверим статусы по рест апи патрони
запросом с хостовой машины:

    $ curl -s  http://172.17.0.2:8008/patroni | jq
    {
      "state": "running",
      "postmaster_start_time": "2020-04-13 00:21:08.822 UTC",
      "role": "master",
      "server_version": 120002,
      "cluster_unlocked": false,
      "xlog": {
        "location": 117440512
      },
      "timeline": 1,
      "replication": [
        {
          "usename": "standby",
          "application_name": "d0cacc06fa17",
          "client_addr": "172.17.0.3",
          "state": "streaming",
          "sync_state": "async",
          "sync_priority": 0
        },
        {
          "usename": "standby",
          "application_name": "54be6a8d7513",
          "client_addr": "172.17.0.4",
          "state": "streaming",
          "sync_state": "async",
          "sync_priority": 0
        }
      ],
      "database_system_identifier": "6814984661834715206",
      "patroni": {
        "version": "1.6.4",
        "scope": "dummy"
      }
    }
    
    $ curl -s  http://172.17.0.3:8008/patroni | jq
    {
      "state": "running",
      "postmaster_start_time": "2020-04-13 00:24:20.739 UTC",
      "role": "replica",
      "server_version": 120002,
      "cluster_unlocked": false,
      "xlog": {
        "received_location": 117440512,
        "replayed_location": 117440512,
        "replayed_timestamp": "2020-04-13 23:20:01.827 UTC",
        "paused": false
      },
      "timeline": 1,
      "database_system_identifier": "6814984661834715206",
      "patroni": {
        "version": "1.6.4",
        "scope": "dummy"
      }
    }
    
    $ curl -s  http://172.17.0.4:8008/patroni | jq
    {
      "state": "running",
      "postmaster_start_time": "2020-04-13 00:35:59.828 UTC",
      "role": "replica",
      "server_version": 120002,
      "cluster_unlocked": false,
      "xlog": {
        "received_location": 117440512,
        "replayed_location": 117440512,
        "replayed_timestamp": "2020-04-13 23:20:01.827 UTC",
        "paused": false
      },
      "timeline": 1,
      "database_system_identifier": "6814984661834715206",
      "patroni": {
        "version": "1.6.4",
        "scope": "dummy"
      }

## 9. подключимся к мастеру в докер с хостовой машины

В postgres.yml в докере находим креденшлы:

    postgresql:
      authentication:
        replication:
          password: standby
          username: standby
        superuser:
          password: zalando
          username: postgres
          
Подключаемся с хостовой машины:

    $ psql -h 172.17.0.2 -U postgres -p 5432
    Пароль пользователя postgres:
    psql (11.6, сервер 12.2 (Ubuntu 12.2-2.pgdg18.04+1))
    ПРЕДУПРЕЖДЕНИЕ: psql имеет базовую версию 11, а сервер - 12.
                 Часть функций psql может не работать.
    SSL-соединение (протокол: TLSv1.3, шифр: TLS_AES_256_GCM_SHA384, бит: 256, сжатие: выкл.)
    Введите "help", чтобы получить справку.
    
    postgres=# \l
                                     Список баз данных
       Имя     | Владелец | Кодировка | LC_COLLATE  |  LC_CTYPE   |     Права доступа
    -------------+----------+-----------+-------------+-------------+-----------------------
    postgres    | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 |
    replicatest | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 |
    template0   | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
               |          |           |             |             | postgres=CTc/postgres
    template1   | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
               |          |           |             |             | postgres=CTc/postgres
    (4 строки)
    
    postgres=# \connect replicatest
    psql (11.6, сервер 12.2 (Ubuntu 12.2-2.pgdg18.04+1))
    ПРЕДУПРЕЖДЕНИЕ: psql имеет базовую версию 11, а сервер - 12.
                  Часть функций psql может не работать.
    SSL-соединение (протокол: TLSv1.3, шифр: TLS_AES_256_GCM_SHA384, бит: 256, сжатие: выкл.)
    Вы подключены к базе данных "replicatest" как пользователь "postgres".
    replicatest=# select * from words;
       word
    --------------
    abarakadabra
    boo
    (2 строки)

## 10. Делаю failover через patronictl

Иду в докер к мастеру и делаю patronictl failover
(systemctl там нет, services patroni тоже не находит)

    root@e9477f065cf0:/home/postgres# patronictl failover
    Candidate ['54be6a8d7513', 'd0cacc06fa17'] []: d0cacc06fa17
    Current cluster topology
    +---------+--------------+------------+--------+---------+----+-----------+
    | Cluster |    Member    |    Host    |  Role  |  State  | TL | Lag in MB |
    +---------+--------------+------------+--------+---------+----+-----------+
    |  dummy  | 54be6a8d7513 | 172.17.0.4 |        | running |  1 |         0 |
    |  dummy  | d0cacc06fa17 | 172.17.0.3 |        | running |  1 |         0 |
    |  dummy  | e9477f065cf0 | 172.17.0.2 | Leader | running |  1 |           |
    +---------+--------------+------------+--------+---------+----+-----------+
    Are you sure you want to failover cluster dummy, demoting current master e9477f065cf0? [y/N]: y
    2020-04-14 01:09:33.22866 Successfully failed over to "d0cacc06fa17"
    +---------+--------------+------------+--------+---------+----+-----------+
    | Cluster |    Member    |    Host    |  Role  |  State  | TL | Lag in MB |
    +---------+--------------+------------+--------+---------+----+-----------+
    |  dummy  | 54be6a8d7513 | 172.17.0.4 |        | running |  1 |         0 |
    |  dummy  | d0cacc06fa17 | 172.17.0.3 | Leader | running |  1 |           |
    |  dummy  | e9477f065cf0 | 172.17.0.2 |        | stopped |    |   unknown |
    +---------+--------------+------------+--------+---------+----+-----------+
    root@e9477f065cf0:/home/postgres#

Иду в докер к d0cacc06fa17 и вижу:

    2020-04-14 01:09:19,485 INFO: no action.  i am a secondary and i am following a leader
    2020-04-14 01:09:29,482 INFO: Lock owner: e9477f065cf0; I am d0cacc06fa17
    2020-04-14 01:09:29,482 INFO: does not have lock
    2020-04-14 01:09:29,485 INFO: no action.  i am a secondary and i am following a leader
    2020-04-14 01:09:32,230 INFO: Lock owner: e9477f065cf0; I am d0cacc06fa17
    2020-04-14 01:09:32,230 INFO: does not have lock
    2020-04-14 01:09:32,235 INFO: no action.  i am a secondary and i am following a leader
    2020-04-14 01:09:33,053 INFO: Cleaning up failover key after acquiring leader lock...
    2020-04-14 01:09:33,058 WARNING: Could not activate Linux watchdog device: "Can't open watchdog device: [Errno 2] No such file or directory: '/dev/watchdog'"
    2020-04-14 01:09:33,061 INFO: promoted self to leader by acquiring session lock
    server promoting
    2020-04-14 01:09:33,066 INFO: cleared rewind state after becoming the leader
    2020-04-14 01:09:34,082 INFO: Lock owner: d0cacc06fa17; I am d0cacc06fa17
    2020-04-14 01:09:34,183 INFO: no action.  i am the leader with the lock
    SET
    DO
    DO
    DO
    NOTICE:  extension "pg_auth_mon" already exists, skipping
    ...
    GRANT
    GRANT
    RESET
    2020-04-14 01:09:44,082 INFO: Lock owner: d0cacc06fa17; I am d0cacc06fa17
    2020-04-14 01:09:44,089 INFO: no action.  i am the leader with the lock

Иду в докер бывшего мастера и вижу:

    2020-04-14 01:09:29,477 INFO: Lock owner: e9477f065cf0; I am e9477f065cf0
    2020-04-14 01:09:29,482 INFO: no action.  i am the leader with the lock
    2020-04-14 01:09:32,118 INFO: received failover request with leader=e9477f065cf0 candidate=d0cacc06fa17 scheduled_at=None
    2020-04-14 01:09:32,126 INFO: Got response from d0cacc06fa17 http://172.17.0.3:8008/patroni: {"state": "running", "postmaster_start_time": "2020-04-13 00:24:20.739 UTC", "role": "replica", "server_version": 120002, "cluster_unlocked": false, "xlog": {"received_location": 117440512, "replayed_location": 117440512, "replayed_timestamp": "2020-04-13 23:20:01.827 UTC", "paused": false}, "timeline": 1, "database_system_identifier": "6814984661834715206", "patroni": {"version": "1.6.4", "scope": "dummy"}}
    2020-04-14 01:09:32,225 INFO: Lock owner: e9477f065cf0; I am e9477f065cf0
    2020-04-14 01:09:32,234 INFO: Got response from d0cacc06fa17 http://172.17.0.3:8008/patroni: {"state": "running", "postmaster_start_time": "2020-04-13 00:24:20.739 UTC", "role": "replica", "server_version": 120002, "cluster_unlocked": false, "xlog": {"received_location": 117440512, "replayed_location": 117440512, "replayed_timestamp": "2020-04-13 23:20:01.827 UTC", "paused": false}, "timeline": 1, "database_system_identifier": "6814984661834715206", "patroni": {"version": "1.6.4", "scope": "dummy"}}
    2020-04-14 01:09:32,331 INFO: manual failover: demoting myself
    2020-04-14 01:09:33,051 INFO: Leader key released
    2020-04-14 01:09:35,060 INFO: Local timeline=1 lsn=0/8000028
    2020-04-14 01:09:35,070 INFO: master_timeline=2
    2020-04-14 01:09:35,070 INFO: master: history=1 0/80000A0       no recovery target specified
    
    2020-04-14 01:09:35,071 INFO: closed patroni connection to the postgresql cluster
    2020-04-14 01:09:35 UTC [6721]: [1-1] 5e950d4f.1a41 0     LOG:  Auto detecting pg_stat_kcache.linux_hz parameter...
    2020-04-14 01:09:35 UTC [6721]: [2-1] 5e950d4f.1a41 0     LOG:  pg_stat_kcache.linux_hz is set to 500000
    2020-04-14 01:09:35 UTC [6721]: [3-1] 5e950d4f.1a41 0     LOG:  starting PostgreSQL 12.2 (Ubuntu 12.2-2.pgdg18.04+1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 7.4.0-1ubuntu1~18.04.1) 7.4.0, 64-bit
    2020-04-14 01:09:35 UTC [6721]: [4-1] 5e950d4f.1a41 0     LOG:  listening on IPv4 address "0.0.0.0", port 5432
    2020-04-14 01:09:35 UTC [6721]: [5-1] 5e950d4f.1a41 0     LOG:  listening on IPv6 address "::", port 5432
    2020-04-14 01:09:35,516 INFO: postmaster pid=6721
    2020-04-14 01:09:35 UTC [6721]: [6-1] 5e950d4f.1a41 0     LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
    2020-04-14 01:09:35 UTC [6721]: [7-1] 5e950d4f.1a41 0     LOG:  redirecting log output to logging collector process
    2020-04-14 01:09:35 UTC [6721]: [8-1] 5e950d4f.1a41 0     HINT:  Future log output will appear in directory "../pg_log".
    /var/run/postgresql:5432 - rejecting connections
    /var/run/postgresql:5432 - accepting connections
    2020-04-14 01:09:42,226 INFO: Lock owner: d0cacc06fa17; I am e9477f065cf0
    2020-04-14 01:09:42,226 INFO: does not have lock
    2020-04-14 01:09:42,226 INFO: establishing a new patroni connection to the postgres cluster
    2020-04-14 01:09:42,255 INFO: no action.  i am a secondary and i am following a leader
    
С хостовой машины делаю запрос по ресту

    curl -s  http://172.17.0.2:8008/cluster | jq
    
    {
      "members": [
        {
          "name": "54be6a8d7513",
          "host": "172.17.0.4",
          "port": 5432,
          "role": "replica",
          "state": "running",
          "api_url": "http://172.17.0.4:8008/patroni",
          "timeline": 2,
          "lag": 0
        },
        {
          "name": "d0cacc06fa17",
          "host": "172.17.0.3",
          "port": 5432,
          "role": "leader",
          "state": "running",
          "api_url": "http://172.17.0.3:8008/patroni",
          "timeline": 2
        },
        {
          "name": "e9477f065cf0",
          "host": "172.17.0.2",
          "port": 5432,
          "role": "replica",
          "state": "running",
          "api_url": "http://172.17.0.2:8008/patroni",
          "timeline": 2,
          "lag": 0
        }
      ]
    }

Убедимся, что прежний postgres теперь read-only

    $ psql -h 172.17.0.2 -U postgres -p 5432
    postgres=# \connect replicatest
    replicatest=# select * from words;
         word
    --------------
     abarakadabra
     boo
    (2 строки)
    
    replicatest=# insert into words (word) values (collins);
    ERROR:  column "collins" does not exist
    СТРОКА 1: insert into words (word) values (collins);
                                               ^
    replicatest=# insert into words (word) values ('collins');
    ERROR:  cannot execute INSERT in a read-only transaction


## 11. Делаю switchover через рест

Сделаем через рест. Вернём первую ноду в статус мастера.
(с третьей попытки, когда указали И текущего лидера, И кандидата)

    $ curl -s http://172.17.0.3:8008/switchover -XPOST -d '{"candidate":"e9477f065cf0"}'
    Switchover could be performed only from a specific leader
    
    $ curl -s http://172.17.0.3:8008/switchover -XPOST -d '{"leader":"e9477f065cf0"}'
    leader name does not match
    
    $ curl -s http://172.17.0.3:8008/switchover -XPOST -d '{"leader":"d0cacc06fa17", "candidate":"e9477f065cf0"}'
    Successfully switched over to "e9477f065cf0"
    
    $ curl -s  http://172.17.0.2:8008/cluster | jq                                                    {
      "members": [
        {
          "name": "54be6a8d7513",
          "host": "172.17.0.4",
          "port": 5432,
          "role": "replica",
          "state": "running",
          "api_url": "http://172.17.0.4:8008/patroni",
          "timeline": 3,
          "lag": 0
        },
        {
          "name": "d0cacc06fa17",
          "host": "172.17.0.3",
          "port": 5432,
          "role": "replica",
          "state": "running",
          "api_url": "http://172.17.0.3:8008/patroni",
          "timeline": 3,
          "lag": 0
        },
        {
          "name": "e9477f065cf0",
          "host": "172.17.0.2",
          "port": 5432,
          "role": "leader",
          "state": "running",
          "api_url": "http://172.17.0.2:8008/patroni",
          "timeline": 3
        }
      ]
    }
    
## 12. Настраиваем HAProxy

Устанавливаю на хостовой машине:

    $ sudo apt install haproxy
    ...
    $ cd /etc/haproxy
    feynman@feynman-desktop:/etc/haproxy$ ls -lah
    итого 24K
    drwxr-xr-x   3 root root 4,0K апр 14 22:26 .
    drwxr-xr-x 138 root root  12K апр 14 22:26 ..
    drwxr-xr-x   2 root root 4,0K апр 14 22:26 errors
    -rw-r--r--   1 root root 1,3K окт 28 15:01 haproxy.cfg

Ищем конфигурацию на сайте патрони

    https://github.com/zalando/patroni/blob/master/haproxy.cfg
    
Меняем под себя:

    $ sudo mv ./haproxy.cfg ./haproxy.cfg.old
    $ sudo nano ./haproxy.cfg
    
    global
        maxconn 100
    
    defaults
        log global
        mode tcp
        retries 2
        timeout client 30m
        timeout connect 4s
        timeout server 30m
        timeout check 5s
    
    listen stats
        mode http
        bind *:7000
        stats enable
        stats uri /
    
    listen batman
        bind *:5000
        option httpchk
        http-check expect status 200
        default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
        server postgresql_172.17.0.2_5432 172.17.0.2:5432 maxconn 100 check port 8008
        server postgresql_172.17.0.3_5432 172.17.0.3:5432 maxconn 100 check port 8008
        server postgresql_172.17.0.4_5432 172.17.0.4:5432 maxconn 100 check port 8008
        
Рестарт haproxy

    $ systemctl restart haproxy
    ==== AUTHENTICATING FOR org.freedesktop.systemd1.manage-units ===
    Чтобы перезапустить «haproxy.service», необходимо пройти аутентификацию.
    Authenticating as: Feynman,,, (feynman)
    Password:
    ==== AUTHENTICATION COMPLETE ===
    
    $ systemctl status haproxy
    ● haproxy.service - HAProxy Load Balancer
       Loaded: loaded (/lib/systemd/system/haproxy.service; enabled; vendor preset: enabled)
       Active: active (running) since Tue 2020-04-14 22:46:35 MSK; 9s ago
         Docs: man:haproxy(1)
               file:/usr/share/doc/haproxy/configuration.txt.gz
      Process: 19357 ExecStartPre=/usr/sbin/haproxy -f $CONFIG -c -q $EXTRAOPTS (code=exited, status=0/SUCCESS)
     Main PID: 19365 (haproxy)
        Tasks: 2 (limit: 4915)
       CGroup: /system.slice/haproxy.service
               ├─19365 /usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid
               └─19368 /usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid
    
    апр 14 22:46:35 feynman-desktop systemd[1]: Starting HAProxy Load Balancer...
    апр 14 22:46:35 feynman-desktop systemd[1]: Started HAProxy Load Balancer.

Подключаемся:

    $ psql -h 127.0.0.1 -p 5000 -U postgres
    Пароль пользователя postgres:
    ...
    postgres=# \l
                                       Список баз данных
         Имя     | Владелец | Кодировка | LC_COLLATE  |  LC_CTYPE   |     Права доступа
    -------------+----------+-----------+-------------+-------------+-----------------------
     postgres    | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 |
     replicatest | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 |
     template0   | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
                 |          |           |             |             | postgres=CTc/postgres
     template1   | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
                 |          |           |             |             | postgres=CTc/postgres
    (4 строки)
    
видно, что это наш кластер из докеров (принял пароль zalando, бд replicatest есть, а моих локальных нет)

Теперь добавлю на 5001-й порт работу на чтение. Добавляю вот такую секцию:

    listen batman2
            bind *:5001
            option httpchk
            http-check expect status 503
            default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
            server postgresql_172.17.0.2_5432 172.17.0.2:5432 maxconn 100 check port 8008
            server postgresql_172.17.0.3_5432 172.17.0.3:5432 maxconn 100 check port 8008
            server postgresql_172.17.0.4_5432 172.17.0.4:5432 maxconn 100 check port 8008

Пытаюсь подключиться:

    $ sudo systemctl restart haproxy
    
    $ psql -h 127.0.0.1 -p 5001 -U postgres
    Пароль пользователя postgres:
    psql (11.6, сервер 12.2 (Ubuntu 12.2-2.pgdg18.04+1))
    ПРЕДУПРЕЖДЕНИЕ: psql имеет базовую версию 11, а сервер - 12.
                    Часть функций psql может не работать.
    SSL-соединение (протокол: TLSv1.3, шифр: TLS_AES_256_GCM_SHA384, бит: 256, сжатие: выкл.)
    Введите "help", чтобы получить справку.
    
    postgres=# \l
                                       Список баз данных
         Имя     | Владелец | Кодировка | LC_COLLATE  |  LC_CTYPE   |     Права доступа
    -------------+----------+-----------+-------------+-------------+-----------------------
     postgres    | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 |
     replicatest | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 |
     template0   | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
                 |          |           |             |             | postgres=CTc/postgres
     template1   | postgres | UTF8      | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
                 |          |           |             |             | postgres=CTc/postgres
    (4 строки)
    
Работает!

## 13. Поменять конфигурацию PostgreSQL + с параметром требующим перезагрузки

Я так понимаю, имеется в виду поменять конфигурацию кластера

    
    root@d0cacc06fa17:/home/postgres# patronictl edit-config
    loop_wait: 10
    maximum_lag_on_failover: 33554432
    postgresql:
      parameters:
        archive_mode: 'on'
        archive_timeout: 1800s
        autovacuum_analyze_scale_factor: 0.02
        autovacuum_max_workers: 5
        autovacuum_vacuum_scale_factor: 0.05
        checkpoint_completion_target: 0.9
        hot_standby: 'on'
        log_autovacuum_min_duration: 0
        log_checkpoints: 'on'
        log_connections: 'on'
        log_disconnections: 'on'
        log_line_prefix: '%t [%p]: [%l-1] %c %x %d %u %a %h '
        log_lock_waits: 'on'
        log_min_duration_statement: 500
        log_statement: ddl
        log_temp_files: 0
        max_connections: 200
        max_replication_slots: 10
        max_wal_senders: 10
        tcp_keepalives_idle: 900
        tcp_keepalives_interval: 100
        track_functions: all
        wal_keep_segments: 8
        wal_level: hot_standby
        wal_log_hints: 'on'
      use_pg_rewind: true
      use_slots: true
    retry_timeout: 10
    ttl: 30
    "/tmp/dummy-config-in5v3qsl.yaml" 33L, 885C written
    ---
    +++
    @@ -18,7 +18,7 @@
         log_min_duration_statement: 500
         log_statement: ddl
         log_temp_files: 0
    -    max_connections: 1000
    +    max_connections: 200
         max_replication_slots: 10
         max_wal_senders: 10
         tcp_keepalives_idle: 900
    
    Apply these changes? [y/N]: y
    Configuration changed
    root@d0cacc06fa17:/home/postgres#

    root@d0cacc06fa17:/home/postgres# patronictl list
    +---------+--------------+------------+--------+---------+----+-----------+-----------------+
    | Cluster |    Member    |    Host    |  Role  |  State  | TL | Lag in MB | Pending restart |
    +---------+--------------+------------+--------+---------+----+-----------+-----------------+
    |  dummy  | 54be6a8d7513 | 172.17.0.4 |        | running |  3 |         0 |        *        |
    |  dummy  | d0cacc06fa17 | 172.17.0.3 |        | running |  3 |         0 |        *        |
    |  dummy  | e9477f065cf0 | 172.17.0.2 | Leader | running |  3 |           |        *        |
    +---------+--------------+------------+--------+---------+----+-----------+-----------------+

Вижу Pending restart. Делаю restart:

    root@d0cacc06fa17:/home/postgres# patronictl list
    +---------+--------------+------------+--------+---------+----+-----------+-----------------+
    | Cluster |    Member    |    Host    |  Role  |  State  | TL | Lag in MB | Pending restart |
    +---------+--------------+------------+--------+---------+----+-----------+-----------------+
    |  dummy  | 54be6a8d7513 | 172.17.0.4 |        | running |  3 |         0 |        *        |
    |  dummy  | d0cacc06fa17 | 172.17.0.3 |        | running |  3 |         0 |        *        |
    |  dummy  | e9477f065cf0 | 172.17.0.2 | Leader | running |  3 |           |        *        |
    +---------+--------------+------------+--------+---------+----+-----------+-----------------+
    root@d0cacc06fa17:/home/postgres# patronictl restart dummy
    +---------+--------------+------------+--------+---------+----+-----------+-----------------+
    | Cluster |    Member    |    Host    |  Role  |  State  | TL | Lag in MB | Pending restart |
    +---------+--------------+------------+--------+---------+----+-----------+-----------------+
    |  dummy  | 54be6a8d7513 | 172.17.0.4 |        | running |  3 |         0 |        *        |
    |  dummy  | d0cacc06fa17 | 172.17.0.3 |        | running |  3 |         0 |        *        |
    |  dummy  | e9477f065cf0 | 172.17.0.2 | Leader | running |  3 |           |        *        |
    +---------+--------------+------------+--------+---------+----+-----------+-----------------+
    When should the restart take place (e.g. 2020-04-14T21:37)  [now]:
    Are you sure you want to restart members e9477f065cf0, d0cacc06fa17, 54be6a8d7513? [y/N]: y
    Restart if the PostgreSQL version is less than provided (e.g. 9.5.2)  []:
    Success: restart on member e9477f065cf0
    Success: restart on member d0cacc06fa17
    Success: restart on member 54be6a8d7513
    root@d0cacc06fa17:/home/postgres#

    root@d0cacc06fa17:/home/postgres# patronictl list
    +---------+--------------+------------+--------+---------+----+-----------+
    | Cluster |    Member    |    Host    |  Role  |  State  | TL | Lag in MB |
    +---------+--------------+------------+--------+---------+----+-----------+
    |  dummy  | 54be6a8d7513 | 172.17.0.4 |        | running |  3 |         0 |
    |  dummy  | d0cacc06fa17 | 172.17.0.3 |        | running |  3 |         0 |
    |  dummy  | e9477f065cf0 | 172.17.0.2 | Leader | running |  3 |           |
    +---------+--------------+------------+--------+---------+----+-----------+

Вуаля.

На этом вроде всё )