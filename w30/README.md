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


