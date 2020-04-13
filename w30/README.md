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
