ДЗ OTUS-RDBMS-2019-10 по занятиям 36..39 - MongoDB
---------------------------------------------------------
Задача: Настроить реплицирование и шардирование, аутентификацию в кластере. Проверить отказоустойчивость.
---------------------------------------------------------

# Table of Contents

0. [Установить, запустить](#install)
1. [Построить шардированный кластер из 3 кластерных нод (по 3 инстанса с репликацией) и с кластером конфига (3 инстанса)](#shard)
2. [Добавить балансировку, нагрузить данными, выбрать хороший ключ шардирования, посмотреть как данные перебалансируются между шардами.](#load)
3. [Настроить аутентификацию и многоролевой доступ.](#roles)
4. [Поронять разные инстансы, посмотреть, что будет происходить, поднять обратно. Описать что произошло.](#kills)

## 0. Установить, запустить <a name="install"></a>

```
$ mongod
Command 'mongod' not found, but can be installed with:
sudo apt install mongodb-server-core
$ sudo apt install mongodb-server-core
...

$ mongo
Command 'mongo' not found, but can be installed with:
sudo apt install mongodb-clients
$ sudo apt install mongodb-clients
...

$ sudo mkdir /home/mongo && sudo mkdir /home/mongo/{db1,db2,db3}
$ sudo chmod 777 /home/mongo/{db1,db2,db3}
$ mongod --dbpath /home/mongo/db1 --port 27001 --replSet RS --fork --logpath /home/mongo/db1/db1.log --pidfilepath /home/mongo/db1/db1.pid
about to fork child process, waiting until server is ready for connections.
forked process: 17509
child process started successfully, parent exiting

$ mongod --dbpath /home/mongo/db2 --port 27002 --replSet RS --fork --logpath /home/mongo/db2/db2.log --pidfilepath /home/mongo/db2/db2.pid
about to fork child process, waiting until server is ready for connections.
forked process: 17622
child process started successfully, parent exiting

$ mongod --dbpath /home/mongo/db3 --port 27003 --replSet RS --fork --logpath /home/mongo/db3/db3.log --pidfilepath /home/mongo/db3/db3.pid
about to fork child process, waiting until server is ready for connections.
forked process: 17726
child process started successfully, parent exiting

$  ps aux | grep mongo| grep -Ev "grep"
feynman  17509  0.6  0.1 1042572 62360 ?  Sl  23:40  0:01 mongod --dbpath /home/mongo/db1 --port 27001 --replSet RS --fork --logpath /home/mongo/db1/db1.log --pidfilepath /home/mongo/db1/db1.pid
feynman  17622  0.7  0.1 1042572 62472 ?  Sl  23:41  0:01 mongod --dbpath /home/mongo/db2 --port 27002 --replSet RS --fork --logpath /home/mongo/db2/db2.log --pidfilepath /home/mongo/db2/db2.pid
feynman  17726  0.8  0.1 1042576 62352 ?  Sl  23:41  0:01 mongod --dbpath /home/mongo/db3 --port 27003 --replSet RS --fork --logpath /home/mongo/db3/db3.log --pidfilepath /home/mongo/db3/db3.pid

$ mongo --port 27001
MongoDB shell version v3.6.3
connecting to: mongodb://127.0.0.1:27001/
MongoDB server version: 3.6.3
Welcome to the MongoDB shell.
...
>
```

Ну вот... 3.6.3

Идём сюда - https://docs.mongodb.com/manual/tutorial/install-mongodb-on-ubuntu/ - и ставим 4.2 по инструкции

```
$ dpkg --list
...
$ sudo apt-get remove mongodb-server-core
...
$ sudo apt-get remove mongo-tools

$ sudo wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
OK
$ sudo echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse
$ sudo apt-get update
...
$ sudo apt-get install -y mongodb-org
...
$ mongod
... db version v4.2.8 ...
```

Отлично. Запускаемся заново.

```
$ $ sudo rm -r /home/mongo
$ sudo mkdir /home/mongo && sudo mkdir /home/mongo/{db1,db2,db3}
$ sudo chmod 0777 /home/mongo/{db1,db2,db3}

$ mongod --dbpath /home/mongo/db1 --port 27001 --replSet RS --fork --logpath /home/mongo/db1/db1.log --pidfilepath /home/mongo/db1/db1.pid
about to fork child process, waiting until server is ready for connections.
forked process: 30810
ERROR: child process failed, exited with error number 14
To see additional information in this output, start without the "--fork" option.
$ mongod --dbpath /home/mongo/db1 --port 27001 --replSet RS --logpath /home/mongo/db1/db1.log --pidfilepath /home/mongo/db1/db1.pid
2020-06-26T00:32:12.909+0300 I  CONTROL  [main] log file "/home/mongo/db1/db1.log" exists; moved to "/home/mongo/db1/db1.log.2020-06-25T21-32-12".
$ cat /home/mongo/db1/db1.log
2020-06-26T00:32:12.912+0300 I  CONTROL  [main] Automatically disabling TLS 1.0, to force-enable TLS 1.0 specify --sslDisabledProtocols 'none'
2020-06-26T00:32:12.915+0300 W  ASIO     [main] No TransportLayer configured during NetworkInterface startup
2020-06-26T00:32:12.916+0300 I  CONTROL  [initandlisten] MongoDB starting : pid=30870 port=27001 dbpath=/home/mongo/db1 64-bit host=feynman-desktop
2020-06-26T00:32:12.916+0300 I  CONTROL  [initandlisten] db version v4.2.8
2020-06-26T00:32:12.916+0300 I  CONTROL  [initandlisten] git version: 43d25964249164d76d5e04dd6cf38f6111e21f5f
2020-06-26T00:32:12.916+0300 I  CONTROL  [initandlisten] OpenSSL version: OpenSSL 1.1.1d  10 Sep 2019
2020-06-26T00:32:12.916+0300 I  CONTROL  [initandlisten] allocator: tcmalloc
2020-06-26T00:32:12.916+0300 I  CONTROL  [initandlisten] modules: none
2020-06-26T00:32:12.916+0300 I  CONTROL  [initandlisten] build environment:
2020-06-26T00:32:12.916+0300 I  CONTROL  [initandlisten]     distmod: ubuntu1804
2020-06-26T00:32:12.916+0300 I  CONTROL  [initandlisten]     distarch: x86_64
2020-06-26T00:32:12.916+0300 I  CONTROL  [initandlisten]     target_arch: x86_64
2020-06-26T00:32:12.916+0300 I  CONTROL  [initandlisten] options: { net: { port: 27001 }, processManagement: { pidFilePath: "/home/mongo/db1/db1.pid" }, replication: { replSet: "RS" }, storage: { dbPath: "/home/mongo/db1" }, systemLog: { destination: "file", path: "/home/mongo/db1/db1.log" } }
2020-06-26T00:32:12.916+0300 E  NETWORK  [initandlisten] Failed to unlink socket file /tmp/mongodb-27001.sock Operation not permitted
2020-06-26T00:32:12.916+0300 F  -        [initandlisten] Fatal Assertion 40486 at src/mongo/transport/transport_layer_asio.cpp 684
2020-06-26T00:32:12.916+0300 F  -        [initandlisten]

***aborting after fassert() failure
```

Хм...
https://stackoverflow.com/questions/34555603/mongodb-failing-to-start-aborting-after-fassert-failure

sudo помогло ))

```
$ sudo mongod --dbpath /home/mongo/db1 --port 27001 --replSet RS --fork --logpath /home/mongo/db1/db1.log --pidfilepath /home/mongo/db1/db1.pid
about to fork child process, waiting until server is ready for connections.
forked process: 31693
child process started successfully, parent exiting

$ sudo mongod --dbpath /home/mongo/db2 --port 27002 --replSet RS --fork --logpath /home/mongo/db2/db2.log --pidfilepath /home/mongo/db2/db2.pid
about to fork child process, waiting until server is ready for connections.
forked process: 31955
child process started successfully, parent exiting

$ sudo mongod --dbpath /home/mongo/db3 --port 27003 --replSet RS --fork --logpath /home/mongo/db3/db3.log --pidfilepath /home/mongo/db3/db3.pid
about to fork child process, waiting until server is ready for connections.
forked process: 32038
child process started successfully, parent exiting

$ ps aux | grep mongo| grep -Ev "grep"
root     31693  1.0  0.2 1599400 94304 ?  Sl   00:37   0:01 mongod --dbpath /home/mongo/db1 --port 27001 --replSet RS --fork --logpath /home/mongo/db1/db1.log --pidfilepath /home/mongo/db1/db1.pid
root     31955  2.3  0.2 1598368 93796 ?  Sl   00:38   0:01 mongod --dbpath /home/mongo/db2 --port 27002 --replSet RS --fork --logpath /home/mongo/db2/db2.log --pidfilepath /home/mongo/db2/db2.pid
root     32038  3.6  0.2 1598368 94120 ?  Sl   00:38   0:00 mongod --dbpath /home/mongo/db3 --port 27003 --replSet RS --fork --logpath /home/mongo/db3/db3.log --pidfilepath /home/mongo/db3/db3.pid

$ mongo --port 27001
MongoDB shell version v4.2.8
connecting to: mongodb://127.0.0.1:27001/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("e5b68fa0-aed0-4dfe-b8ee-6babad1bb010") }
MongoDB server version: 4.2.8
...
```

Установил, запустил.

Делаем replicaset по инструкции из лекции:

```

> rs.status()
{
        "operationTime" : Timestamp(0, 0),
        "ok" : 0,
        "errmsg" : "no replset config has been received",
        "code" : 94,
        "codeName" : "NotYetInitialized",
        "$clusterTime" : {
                "clusterTime" : Timestamp(0, 0),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}

> rs.initiate({"_id" : "RS", members : [{"_id" : 0, priority : 3, host : "127.0.0.1:27001"},{"_id" : 1, host :
... "127.0.0.1:27002"},{"_id" : 2, host : "127.0.0.1:27003", arbiterOnly : true}]});
{
        "ok" : 1,
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593121350, 1),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        },
        "operationTime" : Timestamp(1593121350, 1)
}
RS:SECONDARY>
```

Отлично, я уже SECONDARY на 127.0.0.1:27001. Наверное, из-за priority : 3

```
RS:SECONDARY> rs.status()
{
        "set" : "RS",
        "date" : ISODate("2020-06-25T21:45:04.087Z"),
        "myState" : 1,
        "term" : NumberLong(1),
        "syncingTo" : "",
        "syncSourceHost" : "",
        "syncSourceId" : -1,
        "heartbeatIntervalMillis" : NumberLong(2000),
        "majorityVoteCount" : 2,
        "writeMajorityCount" : 2,
        "optimes" : {
                "lastCommittedOpTime" : {
                        "ts" : Timestamp(1593121501, 1),
                        "t" : NumberLong(1)
                },
                "lastCommittedWallTime" : ISODate("2020-06-25T21:45:01.934Z"),
                "readConcernMajorityOpTime" : {
                        "ts" : Timestamp(1593121501, 1),
                        "t" : NumberLong(1)
                },
                "readConcernMajorityWallTime" : ISODate("2020-06-25T21:45:01.934Z"),
                "appliedOpTime" : {
                        "ts" : Timestamp(1593121501, 1),
                        "t" : NumberLong(1)
                },
                "durableOpTime" : {
                        "ts" : Timestamp(1593121501, 1),
                        "t" : NumberLong(1)
                },
                "lastAppliedWallTime" : ISODate("2020-06-25T21:45:01.934Z"),
                "lastDurableWallTime" : ISODate("2020-06-25T21:45:01.934Z")
        },
        "lastStableRecoveryTimestamp" : Timestamp(1593121481, 1),
        "lastStableCheckpointTimestamp" : Timestamp(1593121481, 1),
        "electionCandidateMetrics" : {
                "lastElectionReason" : "electionTimeout",
                "lastElectionDate" : ISODate("2020-06-25T21:42:41.919Z"),
                "electionTerm" : NumberLong(1),
                "lastCommittedOpTimeAtElection" : {
                        "ts" : Timestamp(0, 0),
                        "t" : NumberLong(-1)
                },
                "lastSeenOpTimeAtElection" : {
                        "ts" : Timestamp(1593121350, 1),
                        "t" : NumberLong(-1)
                },
                "numVotesNeeded" : 2,
                "priorityAtElection" : 3,
                "electionTimeoutMillis" : NumberLong(10000),
                "numCatchUpOps" : NumberLong(0),
                "newTermStartDate" : ISODate("2020-06-25T21:42:41.931Z"),
                "wMajorityWriteAvailabilityDate" : ISODate("2020-06-25T21:42:42.524Z")
        },
        "members" : [
                {
                        "_id" : 0,
                        "name" : "127.0.0.1:27001",
                        "health" : 1,
                        "state" : 1,
                        "stateStr" : "PRIMARY",
                        "uptime" : 484,
                        "optime" : {
                                "ts" : Timestamp(1593121501, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDate" : ISODate("2020-06-25T21:45:01Z"),
                        "syncingTo" : "",
                        "syncSourceHost" : "",
                        "syncSourceId" : -1,
                        "infoMessage" : "",
                        "electionTime" : Timestamp(1593121361, 1),
                        "electionDate" : ISODate("2020-06-25T21:42:41Z"),
                        "configVersion" : 1,
                        "self" : true,
                        "lastHeartbeatMessage" : ""
                },
                {
                        "_id" : 1,
                        "name" : "127.0.0.1:27002",
                        "health" : 1,
                        "state" : 2,
                        "stateStr" : "SECONDARY",
                        "uptime" : 153,
                        "optime" : {
                                "ts" : Timestamp(1593121501, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDurable" : {
                                "ts" : Timestamp(1593121501, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDate" : ISODate("2020-06-25T21:45:01Z"),
                        "optimeDurableDate" : ISODate("2020-06-25T21:45:01Z"),
                        "lastHeartbeat" : ISODate("2020-06-25T21:45:03.922Z"),
                        "lastHeartbeatRecv" : ISODate("2020-06-25T21:45:03.009Z"),
                        "pingMs" : NumberLong(0),
                        "lastHeartbeatMessage" : "",
                        "syncingTo" : "127.0.0.1:27001",
                        "syncSourceHost" : "127.0.0.1:27001",
                        "syncSourceId" : 0,
                        "infoMessage" : "",
                        "configVersion" : 1
                },
                {
                        "_id" : 2,
                        "name" : "127.0.0.1:27003",
                        "health" : 1,
                        "state" : 7,
                        "stateStr" : "ARBITER",
                        "uptime" : 153,
                        "lastHeartbeat" : ISODate("2020-06-25T21:45:03.922Z"),
                        "lastHeartbeatRecv" : ISODate("2020-06-25T21:45:03.448Z"),
                        "pingMs" : NumberLong(0),
                        "lastHeartbeatMessage" : "",
                        "syncingTo" : "",
                        "syncSourceHost" : "",
                        "syncSourceId" : -1,
                        "infoMessage" : "",
                        "configVersion" : 1
                }
        ],
        "ok" : 1,
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593121501, 1),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        },
        "operationTime" : Timestamp(1593121501, 1)
}
RS:PRIMARY>
```

Теперь я PRIMARY на 127.0.0.1:27001. Почему?
Пересматриваем лекцию - наоборот: из-за priority: 3 127.0.0.1:27001 стал PRIMARY,
а исходно наверное все были SECONDARY, пока они не разобрались за какое-то время...

Отлично. Один репликасет запускается.

Идём дальше - создаём ещё два репликасета для шард и ещё один для конфигов.

## 1. Построить шардированный кластер из 3 кластерных нод (по 3 инстанса с репликацией) и с кластером конфига (3 инстанса). <a name="shard"></a>

NB: читать до конца, потом только делать (после "Да блиииииииииииин...") !!!

```
$ sudo killall mongod
$ ps aux | grep mongo| grep -Ev "grep"
$ sudo rm -r /home/mongo/{db1,db2,db3,db4,db5,db6,db7,db8,db9,dbc11,dbc12,dbc13}
$ sudo mkdir /home/mongo/{db1,db2,db3,db4,db5,db6,db7,db8,db9,dbc11,dbc12,dbc13}
$ sudo chmod 0777 /home/mongo/{db1,db2,db3,db4,db5,db6,db7,db8,db9,dbc11,dbc12,dbc13}
```

первая шарда
```
$ sudo mongod --dbpath /home/mongo/db1 --port 27001 --replSet RS1 --fork --logpath /home/mongo/db1/db1.log --pidfilepath /home/mongo/db1/db1.pid
$ sudo mongod --dbpath /home/mongo/db2 --port 27002 --replSet RS1 --fork --logpath /home/mongo/db2/db2.log --pidfilepath /home/mongo/db2/db2.pid
$ sudo mongod --dbpath /home/mongo/db3 --port 27003 --replSet RS1 --fork --logpath /home/mongo/db3/db3.log --pidfilepath /home/mongo/db3/db3.pid
$ mongo --port 27001
> rs.initiate({"_id" : "RS1", members : [{"_id" : 0, priority : 3, host : "127.0.0.1:27001"},{"_id" : 1, host : "127.0.0.1:27002"},{"_id" : 2, host : "127.0.0.1:27003", arbiterOnly : true}]});
...
RS1:SECONDARY>
RS1:SECONDARY>
RS1:PRIMARY> exit
bye
```

вторая шарда
```
$ sudo mongod --dbpath /home/mongo/db4 --port 27004 --replSet RS2 --fork --logpath /home/mongo/db4/db4.log --pidfilepath /home/mongo/db4/db4.pid
$ sudo mongod --dbpath /home/mongo/db5 --port 27005 --replSet RS2 --fork --logpath /home/mongo/db5/db5.log --pidfilepath /home/mongo/db5/db5.pid
$ sudo mongod --dbpath /home/mongo/db6 --port 27006 --replSet RS2 --fork --logpath /home/mongo/db6/db6.log --pidfilepath /home/mongo/db6/db6.pid
$ mongo --port 27004
> rs.initiate({"_id" : "RS2", members : [{"_id" : 0, priority : 3, host : "127.0.0.1:27004"},{"_id" : 1, host : "127.0.0.1:27005"},{"_id" : 2, host : "127.0.0.1:27006", arbiterOnly : true}]});
...
RS2:SECONDARY>
RS2:SECONDARY>
RS2:PRIMARY> exit
bye
```

третья шарда
```
$ sudo mongod --dbpath /home/mongo/db7 --port 27007 --replSet RS3 --fork --logpath /home/mongo/db7/db7.log --pidfilepath /home/mongo/db7/db7.pid
$ sudo mongod --dbpath /home/mongo/db8 --port 27008 --replSet RS3 --fork --logpath /home/mongo/db8/db8.log --pidfilepath /home/mongo/db8/db8.pid
$ sudo mongod --dbpath /home/mongo/db9 --port 27009 --replSet RS3 --fork --logpath /home/mongo/db9/db9.log --pidfilepath /home/mongo/db9/db9.pid
$ mongo --port 27007
> rs.initiate({"_id" : "RS3", members : [{"_id" : 0, priority : 3, host : "127.0.0.1:27007"},{"_id" : 1, host : "127.0.0.1:27008"},{"_id" : 2, host : "127.0.0.1:27009", arbiterOnly : true}]});
...
RS3:SECONDARY>
RS3:SECONDARY>
RS3:PRIMARY> exit
bye
```

конфиг-репликасет
```
$ sudo mongod --configsvr --dbpath /home/mongo/dbc11 --port 27011 --replSet RSC --fork --logpath /home/mongo/dbc11/dbc11.log --pidfilepath /home/mongo/dbc11/dbc11.pid
$ sudo mongod --configsvr --dbpath /home/mongo/dbc12 --port 27012 --replSet RSC --fork --logpath /home/mongo/dbc12/dbc12.log --pidfilepath /home/mongo/dbc12/dbc12.pid
$ sudo mongod --configsvr --dbpath /home/mongo/dbc13 --port 27013 --replSet RSC --fork --logpath /home/mongo/dbc13/dbc13.log --pidfilepath /home/mongo/dbc13/dbc13.pid
$ mongo --port 27011
> rs.initiate({"_id" : "RSC", configsvr: true, members : [{"_id" : 0, priority : 3, host : "127.0.0.1:27011"},{"_id" : 1, host : "127.0.0.1:27012"},{"_id" : 2, host : "127.0.0.1:27013", arbiterOnly : true}]});
...
"errmsg" : "Arbiters are not allowed in replica set configurations being used for config servers",
...
> rs.initiate({"_id" : "RSC", configsvr: true, members : [{"_id" : 0, priority : 3, host : "127.0.0.1:27011"},{"_id" : 1, priority : 2, host : "127.0.0.1:27012"},{"_id" : 2, host : "127.0.0.1:27013"}]});
...
RSC:SECONDARY>
RSC:PRIMARY> exit
bye
```

смотрим 12 процессов

```
$ sudo ps aux | grep mongo| grep -Ev "grep"
root     19357  0.6  0.3 1923732 102908 ?      Sl   02:22   0:08 mongod --dbpath /home/mongo/db1 --port 27001 --replSet RS1 --fork --logpath /home/mongo/db1/db1.log --pidfilepath /home/mongo/db1/db1.pid
root     19425  0.6  0.3 1899092 103592 ?      Sl   02:22   0:08 mongod --dbpath /home/mongo/db2 --port 27002 --replSet RS1 --fork --logpath /home/mongo/db2/db2.log --pidfilepath /home/mongo/db2/db2.pid
root     19478  0.4  0.2 1634768 97928 ?       Sl   02:23   0:06 mongod --dbpath /home/mongo/db3 --port 27003 --replSet RS1 --fork --logpath /home/mongo/db3/db3.log --pidfilepath /home/mongo/db3/db3.pid
root     19971  0.6  0.3 1928164 104912 ?      Sl   02:25   0:07 mongod --dbpath /home/mongo/db4 --port 27004 --replSet RS2 --fork --logpath /home/mongo/db4/db4.log --pidfilepath /home/mongo/db4/db4.pid
root     20053  0.6  0.3 1900032 104084 ?      Sl   02:25   0:07 mongod --dbpath /home/mongo/db5 --port 27005 --replSet RS2 --fork --logpath /home/mongo/db5/db5.log --pidfilepath /home/mongo/db5/db5.pid
root     20107  0.4  0.3 1632272 99012 ?       Sl   02:25   0:05 mongod --dbpath /home/mongo/db6 --port 27006 --replSet RS2 --fork --logpath /home/mongo/db6/db6.log --pidfilepath /home/mongo/db6/db6.pid
root     20434  0.6  0.3 1929084 105540 ?      Sl   02:26   0:07 mongod --dbpath /home/mongo/db7 --port 27007 --replSet RS3 --fork --logpath /home/mongo/db7/db7.log --pidfilepath /home/mongo/db7/db7.pid
root     20490  0.6  0.3 1899996 105356 ?      Sl   02:26   0:07 mongod --dbpath /home/mongo/db8 --port 27008 --replSet RS3 --fork --logpath /home/mongo/db8/db8.log --pidfilepath /home/mongo/db8/db8.pid
root     20560  0.4  0.2 1642544 98524 ?       Sl   02:26   0:05 mongod --dbpath /home/mongo/db9 --port 27009 --replSet RS3 --fork --logpath /home/mongo/db9/db9.log --pidfilepath /home/mongo/db9/db9.pid
root     22642  0.8  0.3 2054500 106592 ?      Sl   02:38   0:03 mongod --configsvr --dbpath /home/mongo/dbc11 --port 27011 --replSet RSC --fork --logpath /home/mongo/dbc11/dbc11.log --pidfilepath /home/mongo/dbc11/dbc11.pid
root     22718  0.8  0.3 1938272 105744 ?      Sl   02:38   0:03 mongod --configsvr --dbpath /home/mongo/dbc12 --port 27012 --replSet RSC --fork --logpath /home/mongo/dbc12/dbc12.log --pidfilepath /home/mongo/dbc12/dbc12.pid
root     22792  0.8  0.3 1945468 107636 ?      Sl   02:38   0:03 mongod --configsvr --dbpath /home/mongo/dbc13 --port 27013 --replSet RSC --fork --logpath /home/mongo/dbc13/dbc13.log --pidfilepath /home/mongo/dbc13/dbc13.pid
```

Тут возникла беда - у меня "русская ЭС" затесалась в название RSC.
Убил процессы, перезапустил, вытаюсь объединить в репликасет - ругается
("errmsg" : "already initialized").

Пришлось познакомиться с rs.reconfig()

```
RSС:OTHER> rsconf = rs.conf()
...
RSС:OTHER> rsconf._id = 'RSC';
RSC
RSС:OTHER> rsconf.members = [{"_id" : 0, priority : 3, host : "127.0.0.1:27011"},{"_id" : 1, priority : 2, host : "127.0.0.1:27012"},{"_id" : 2, host : "127.0.0.1:27013"}];
...
RSС:OTHER> rs.reconfig(rsconf, {force: true});
...
"errmsg" : "New and old configurations differ in replica set name; old was RSС, and new is RSC",
...
```

Ну.. тогда не знаю..
Убиваю файлы и всё заново по конфиг-репликасету.

```
RSС:OTHER> exit
bye
$ sudo ps aux | grep mongo| grep -Ev "grep"
...
$ sudo kill 27796
$ sudo kill 28160
$ sudo kill 28267

$ sudo rm -r /home/mongo/{dbc11,dbc12,dbc13}
$ sudo mkdir /home/mongo/{dbc11,dbc12,dbc13}
$ sudo chmod 0777 /home/mongo/{dbc11,dbc12,dbc13}

$ sudo mongod --configsvr --dbpath /home/mongo/dbc11 --port 27011 --replSet RSC --fork --logpath /home/mongo/dbc11/dbc11.log --pidfilepath /home/mongo/dbc11/dbc11.pid
$ sudo mongod --configsvr --dbpath /home/mongo/dbc12 --port 27012 --replSet RSC --fork --logpath /home/mongo/dbc12/dbc12.log --pidfilepath /home/mongo/dbc12/dbc12.pid
$ sudo mongod --configsvr --dbpath /home/mongo/dbc13 --port 27013 --replSet RSC --fork --logpath /home/mongo/dbc13/dbc13.log --pidfilepath /home/mongo/dbc13/dbc13.pid
$ mongo --port 27011
> rs.initiate({"_id" : "RSC", configsvr: true, members : [{"_id" : 0, priority : 3, host : "127.0.0.1:27011"},{"_id" : 1, priority : 2, host : "127.0.0.1:27012"},{"_id" : 2, host : "127.0.0.1:27013"}]});
{
        "ok" : 1,
        "$gleStats" : {
                "lastOpTime" : Timestamp(1593131045, 1),
                "electionId" : ObjectId("000000000000000000000000")
        },
        "lastCommittedOpTime" : Timestamp(0, 0),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593131045, 1),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        },
        "operationTime" : Timestamp(1593131045, 1)
}

RSC:SECONDARY>
RSC:SECONDARY>
RSC:PRIMARY>
RSC:PRIMARY> exit
bye
```

Готово.

```
$ sudo ps aux | grep mongo| grep -Ev "grep"
root     19357  0.6  0.3 1926056 103096 ?      Sl   02:22   0:23 mongod --dbpath /home/mongo/db1 --port 27001 --replSet RS1 --fork --logpath /home/mongo/db1/db1.log --pidfilepath /home/mongo/db1/db1.pid
root     19425  0.6  0.3 1899092 103220 ?      Sl   02:22   0:24 mongod --dbpath /home/mongo/db2 --port 27002 --replSet RS1 --fork --logpath /home/mongo/db2/db2.log --pidfilepath /home/mongo/db2/db2.pid
root     19478  0.4  0.2 1634768 96888 ?       Sl   02:23   0:16 mongod --dbpath /home/mongo/db3 --port 27003 --replSet RS1 --fork --logpath /home/mongo/db3/db3.log --pidfilepath /home/mongo/db3/db3.pid
root     19971  0.6  0.3 1928164 102656 ?      Sl   02:25   0:22 mongod --dbpath /home/mongo/db4 --port 27004 --replSet RS2 --fork --logpath /home/mongo/db4/db4.log --pidfilepath /home/mongo/db4/db4.pid
root     20053  0.6  0.3 1901060 104476 ?      Sl   02:25   0:23 mongod --dbpath /home/mongo/db5 --port 27005 --replSet RS2 --fork --logpath /home/mongo/db5/db5.log --pidfilepath /home/mongo/db5/db5.pid
root     20107  0.4  0.2 1632272 96832 ?       Sl   02:25   0:15 mongod --dbpath /home/mongo/db6 --port 27006 --replSet RS2 --fork --logpath /home/mongo/db6/db6.log --pidfilepath /home/mongo/db6/db6.pid
root     20434  0.6  0.3 1929084 103780 ?      Sl   02:26   0:21 mongod --dbpath /home/mongo/db7 --port 27007 --replSet RS3 --fork --logpath /home/mongo/db7/db7.log --pidfilepath /home/mongo/db7/db7.pid
root     20490  0.6  0.3 1899996 105380 ?      Sl   02:26   0:22 mongod --dbpath /home/mongo/db8 --port 27008 --replSet RS3 --fork --logpath /home/mongo/db8/db8.log --pidfilepath /home/mongo/db8/db8.pid
root     20560  0.4  0.2 1642544 97420 ?       Sl   02:26   0:15 mongod --dbpath /home/mongo/db9 --port 27009 --replSet RS3 --fork --logpath /home/mongo/db9/db9.log --pidfilepath /home/mongo/db9/db9.pid
root     31085  1.1  0.3 2053168 106168 ?      Sl   03:23   0:02 mongod --configsvr --dbpath /home/mongo/dbc11 --port 27011 --replSet RSC --fork --logpath /home/mongo/dbc11/dbc11.log --pidfilepath /home/mongo/dbc11/dbc11.pid
root     31154  1.2  0.3 1946252 105436 ?      Sl   03:23   0:02 mongod --configsvr --dbpath /home/mongo/dbc12 --port 27012 --replSet RSC --fork --logpath /home/mongo/dbc12/dbc12.log --pidfilepath /home/mongo/dbc12/dbc12.pid
root     31220  1.2  0.3 1944376 105424 ?      Sl   03:23   0:02 mongod --configsvr --dbpath /home/mongo/dbc13 --port 27013 --replSet RSC --fork --logpath /home/mongo/dbc13/dbc13.log --pidfilepath /home/mongo/dbc13/dbc13.pid
```

Теперь шарды.

```
$ sudo mongos --configdb RSC/127.0.0.1:27011,127.0.0.1:27012,127.0.0.1:27013 --port 27000 --fork --logpath /home/mongo/dbc11/dbs.log --pidfilepath /home/mongo/dbc11/dbs.pid
about to fork child process, waiting until server is ready for connections.
forked process: 32725
child process started successfully, parent exiting
$ mongo --port 27000
MongoDB shell version v4.2.8
connecting to: mongodb://127.0.0.1:27000/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("119c0daa-3ce2-4c83-8142-4c24abc41b17") }
MongoDB server version: 4.2.8
...
mongos> sh.addShard("RS1/127.0.0.1:27001,127.0.0.1:27002,127.0.0.1:27003");
...
"errmsg" : "Cannot run addShard on a node started without --shardsvr"
...
```

Да блиииииииииииин...

```
$ sudo killall mongod
$ sudo ps aux | grep mongo| grep -Ev "grep"                                                       root     32725  0.2  0.1 339260 34664 ?        Sl   03:31   0:02 mongos --configdb RSC/127.0.0.1:27011,127.0.0.1:27012,127.0.0.1:27013 --port 27000 --fork --logpath /home/mongo/dbc11/dbs.log --pidfilepath /home/mongo/dbc11/dbs.pid
$ sudo kill 32725
$ sudo mongod --shardsvr --dbpath /home/mongo/db1 --port 27001 --replSet RS1 --fork --logpath /home/mongo/db1/db1.log --pidfilepath /home/mongo/db1/db1.pid
$ sudo mongod --shardsvr --dbpath /home/mongo/db2 --port 27002 --replSet RS1 --fork --logpath /home/mongo/db2/db2.log --pidfilepath /home/mongo/db2/db2.pid
$ sudo mongod --shardsvr --dbpath /home/mongo/db3 --port 27003 --replSet RS1 --fork --logpath /home/mongo/db3/db3.log --pidfilepath /home/mongo/db3/db3.pid
$ mongo --port 27001
RS1:SECONDARY>
RS1:PRIMARY> exit
bye
$ sudo mongod --shardsvr --dbpath /home/mongo/db4 --port 27004 --replSet RS2 --fork --logpath /home/mongo/db4/db4.log --pidfilepath /home/mongo/db4/db4.pid
$ sudo mongod --shardsvr --dbpath /home/mongo/db5 --port 27005 --replSet RS2 --fork --logpath /home/mongo/db5/db5.log --pidfilepath /home/mongo/db5/db5.pid
$ sudo mongod --shardsvr --dbpath /home/mongo/db6 --port 27006 --replSet RS2 --fork --logpath /home/mongo/db6/db6.log --pidfilepath /home/mongo/db6/db6.pid
$ mongo --port 27004
RS2:SECONDARY>
RS2:PRIMARY> exit
bye
$ sudo mongod --shardsvr --dbpath /home/mongo/db7 --port 27007 --replSet RS3 --fork --logpath /home/mongo/db7/db7.log --pidfilepath /home/mongo/db7/db7.pid
$ sudo mongod --shardsvr --dbpath /home/mongo/db8 --port 27008 --replSet RS3 --fork --logpath /home/mongo/db8/db8.log --pidfilepath /home/mongo/db8/db8.pid
$ sudo mongod --shardsvr --dbpath /home/mongo/db9 --port 27009 --replSet RS3 --fork --logpath /home/mongo/db9/db9.log --pidfilepath /home/mongo/db9/db9.pid
$ mongo --port 27007
RS3:SECONDARY>
RS3:PRIMARY> exit
bye
$ sudo mongod --configsvr --dbpath /home/mongo/dbc11 --port 27011 --replSet RSC --fork --logpath /home/mongo/dbc11/dbc11.log --pidfilepath /home/mongo/dbc11/dbc11.pid
$ sudo mongod --configsvr --dbpath /home/mongo/dbc12 --port 27012 --replSet RSC --fork --logpath /home/mongo/dbc12/dbc12.log --pidfilepath /home/mongo/dbc12/dbc12.pid
$ sudo mongod --configsvr --dbpath /home/mongo/dbc13 --port 27013 --replSet RSC --fork --logpath /home/mongo/dbc13/dbc13.log --pidfilepath /home/mongo/dbc13/dbc13.pid
$ mongo --port 27011
RSC:PRIMARY> exit
bye

$ sudo mongos --configdb RSC/127.0.0.1:27011,127.0.0.1:27012,127.0.0.1:27013 --port 27000 --fork --logpath /home/mongo/dbc11/dbs.log --pidfilepath /home/mongo/dbc11/dbs.pid
$ mongo --port 27000
mongos> sh.addShard("RS1/127.0.0.1:27001,127.0.0.1:27002,127.0.0.1:27003");
{
        "shardAdded" : "RS1",
        "ok" : 1,
        "operationTime" : Timestamp(1593133068, 7),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593133068, 7),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
mongos> sh.addShard("RS2/127.0.0.1:27004,127.0.0.1:27005,127.0.0.1:27006");
{
        "shardAdded" : "RS2",
        "ok" : 1,
        "operationTime" : Timestamp(1593133156, 6),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593133156, 6),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
mongos> sh.addShard("RS3/127.0.0.1:27007,127.0.0.1:27008,127.0.0.1:27009");
{
        "shardAdded" : "RS3",
        "ok" : 1,
        "operationTime" : Timestamp(1593133195, 6),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593133195, 6),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
mongos> sh.status();
--- Sharding Status ---
  sharding version: {
        "_id" : 1,
        "minCompatibleVersion" : 5,
        "currentVersion" : 6,
        "clusterId" : ObjectId("5ef540302b494dfe26bbae5b")
  }
  shards:
        {  "_id" : "RS1",  "host" : "RS1/127.0.0.1:27001,127.0.0.1:27002",  "state" : 1 }
        {  "_id" : "RS2",  "host" : "RS2/127.0.0.1:27004,127.0.0.1:27005",  "state" : 1 }
        {  "_id" : "RS3",  "host" : "RS3/127.0.0.1:27007,127.0.0.1:27008",  "state" : 1 }
  active mongoses:
        "4.2.8" : 1
  autosplit:
        Currently enabled: yes
  balancer:
        Currently enabled:  yes
        Currently running:  no
        Failed balancer rounds in last 5 attempts:  0
        Migration Results for the last 24 hours:
                29 : Success
  databases:
        {  "_id" : "config",  "primary" : "config",  "partitioned" : true }
                config.system.sessions
                        shard key: { "_id" : 1 }
                        unique: false
                        balancing: true
                        chunks:
                                RS1     995
                                RS2     15
                                RS3     14
                        too many chunks to print, use verbose if you want to force print
```

Готово

Теперь данные и шардирование

## 2. Добавить балансировку, нагрузить данными, выбрать хороший ключ шардирования, посмотреть как данные перебалансируются между шардами. <a name="load"></a>

```
Данные генерирую вот так:
function ff(m){return Math.floor(Math.random() * Math.floor(m));}
function pad(n, w) {n = n + ''; return n.length >= w ? n : new Array(w - n.length + 1).join('0') + n;}
for (var i=0; i<1000000; i++) {
    var b = ff(1000);
    var m = ff(12);
    var d = ff(28);
    var p = ff(50);
    var dt = new Date('2019-'+ m +'-' + d);
    var dts = '19'+pad(m, 2)+pad(d, 2);
    var price = Math.random();
    var id = parseInt(p + dts + pad(b, 8));
    var id_pe = parseInt(p + pad(b, 8));
    var id_rev = parseInt(p + pad(b, 8) + dts);
    db.prices.insert({id: id, id_rev: id_rev, id_pe: id_pe, dt: dt, price: price, p: p})
}
```

```
mongos> use tsq
switched to db tsq
mongos> sh.enableSharding("tsq");
{
        "ok" : 1,
        "operationTime" : Timestamp(1593139863, 5),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593139863, 5),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
/* 10 записей */
mongos> function ff(m){return Math.floor(Math.random() * Math.floor(m));}function pad(n, w) {n = n + ''; return n.length >= w ? n : new Array(w - n.length + 1).join('0') + n;}for (var i=0; i<10; i++) {var b = ff(1000); var m = ff(12); var d = ff(28); var p = ff(50); var dt = new Date('2019-'+ m +'-' + d); var dts = '19'+pad(m, 2)+pad(d, 2); var price = Math.random(); var id = parseInt(p + dts + pad(b, 8)); var id_pe = parseInt(p + pad(b, 8)); var id_rev = parseInt(p + pad(b, 8) + dts); db.prices.insert({id: id, id_rev: id_rev, id_pe: id_pe, dt: dt, price: price, p: p});}
WriteResult({ "nInserted" : 1 })
mongos> db.prices.find()
{ "_id" : ObjectId("5ef56350b342cb2739067040"), "id" : 4719110600000362, "id_rev" : 4700000362191106, "id_pe" : 4700000362, "dt" : ISODate("2019-11-06T00:00:00Z"), "price" : 0.9061040379199191, "p" : 47 }
{ "_id" : ObjectId("5ef56350b342cb2739067041"), "id" : 4719101400000134, "id_rev" : 4700000134191014, "id_pe" : 4700000134, "dt" : ISODate("2019-10-14T00:00:00Z"), "price" : 0.23333375795364597, "p" : 47 }
{ "_id" : ObjectId("5ef56350b342cb2739067042"), "id" : 4419032100000369, "id_rev" : 4400000369190321, "id_pe" : 4400000369, "dt" : ISODate("2019-03-21T00:00:00Z"), "price" : 0.20726548998597516, "p" : 44 }
{ "_id" : ObjectId("5ef56350b342cb2739067043"), "id" : 2419052400000380, "id_rev" : 2400000380190524, "id_pe" : 2400000380, "dt" : ISODate("2019-05-24T00:00:00Z"), "price" : 0.39891561502051653, "p" : 24 }
{ "_id" : ObjectId("5ef56350b342cb2739067044"), "id" : 1519050200000147, "id_rev" : 1500000147190502, "id_pe" : 1500000147, "dt" : ISODate("2019-05-02T00:00:00Z"), "price" : 0.12881840844155656, "p" : 15 }
{ "_id" : ObjectId("5ef56350b342cb2739067045"), "id" : 2919070000000666, "id_rev" : 2900000666190700, "id_pe" : 2900000666, "dt" : ISODate("1970-01-01T00:00:00Z"), "price" : 0.73670183745665, "p" : 29 }
{ "_id" : ObjectId("5ef56350b342cb2739067046"), "id" : 4219031200000972, "id_rev" : 4200000972190312, "id_pe" : 4200000972, "dt" : ISODate("2019-03-12T00:00:00Z"), "price" : 0.144548153679519, "p" : 42 }
{ "_id" : ObjectId("5ef56350b342cb2739067047"), "id" : 2919072100000556, "id_rev" : 2900000556190721, "id_pe" : 2900000556, "dt" : ISODate("2019-07-21T00:00:00Z"), "price" : 0.25634350696424446, "p" : 29 }
{ "_id" : ObjectId("5ef56350b342cb2739067048"), "id" : 2519030000000316, "id_rev" : 2500000316190300, "id_pe" : 2500000316, "dt" : ISODate("1970-01-01T00:00:00Z"), "price" : 0.7630796964640619, "p" : 25 }
{ "_id" : ObjectId("5ef56350b342cb2739067049"), "id" : 3019100400000101, "id_rev" : 3000000101191004, "id_pe" : 3000000101, "dt" : ISODate("2019-10-04T00:00:00Z"), "price" : 0.2545096884505985, "p" : 30 }
/* 1M записей */
mongos> function ff(m){return Math.floor(Math.random() * Math.floor(m));}function pad(n, w) {n = n + ''; return n.length >= w ? n : new Array(w - n.length + 1).join('0') + n;}for (var i=0; i<1000000; i++) {var b = ff(1000); var m = ff(12); var d = ff(28); var p = ff(50); var dt = new Date('2019-'+ m +'-' + d); var dts = '19'+pad(m, 2)+pad(d, 2); var price = Math.random(); var id = parseInt(p + dts + pad(b, 8)); var id_pe = parseInt(p + pad(b, 8)); var id_rev = parseInt(p + pad(b, 8) + dts); db.prices.insert({id: id, id_rev: id_rev, id_pe: id_pe, dt: dt, price: price, p: p});}
```

долго льёт миллион записей, а я наблюдаю за памятью

```
$ sudo free -h
              всего        занято        свободно      общая  буф./врем.   доступно
Память:         31G         17G        1,8G         20M         11G         13G
Подкачка:        8,0G        512K        8,0G

$ sudo free -h
              всего        занято        свободно      общая  буф./врем.   доступно
Память:         31G         18G        1,5G         20M         11G         12G
Подкачка:        8,0G        512K        8,0G

$ sudo free -h
              всего        занято        свободно      общая  буф./врем.   доступно
Память:         31G         18G        1,3G         20M         11G         12G
Подкачка:        8,0G        512K        8,0G

$ sudo free -h
              всего        занято        свободно      общая  буф./врем.   доступно
Память:         31G         18G        2,2G         20M         10G         11G
Подкачка:        8,0G        512K        8,0G
```

Отработала за 15 минут

посчитаем

```
mongos> db.prices.find().count();
1000010
```

индексируем

```
mongos> db.prices.ensureIndex({id_pe: 1})
{
        "raw" : {
                "RS3/127.0.0.1:27007,127.0.0.1:27008" : {
                        "createdCollectionAutomatically" : false,
                        "numIndexesBefore" : 1,
                        "numIndexesAfter" : 2,
                        "ok" : 1
                }
        },
        "ok" : 1,
        "operationTime" : Timestamp(1593141523, 1),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593141523, 1),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
mongos> db.prices.stats()
...
```

запускаем шардирование

```
mongos> use admin
switched to db admin
mongos> db.runCommand({shardCollection: "tsq.prices", key: {id_pe: 1}});
{
        "collectionsharded" : "tsq.prices",
        "collectionUUID" : UUID("ac67f06f-c290-43c5-a3cf-598483b4351e"),
        "ok" : 1,
        "operationTime" : Timestamp(1593141629, 10),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593141629, 10),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
```

id_pe - это биржа + облигация
Ключ тяготеет к неравномерному распределению нагрузки (на 4-ю биржу например заведомо однозначно больше бумаг, чем на остальные), но на этот ключ однозначно будут частые запросы.
Поле не обновляется и крайне редко удаляется.
Но в запрос будут попадать условия типа IN. Это нормально, хорошо, плохо? Не знаю...
Хотя можно было бы и по датам пошардить... тут надо попрактиковаться и поиграться с запросами.
По дате условия выборки не всегда, и они по range-у (>, <, between), редко по соответсвию (=).
Будем считать, что для учебных целей нормальный ключ для начала.

getBalancerState
```
mongos> sh.getBalancerState()
true
```

listShards
```
mongos> db.adminCommand( { listShards: 1 } )
{
        "shards" : [
                {
                        "_id" : "RS1",
                        "host" : "RS1/127.0.0.1:27001,127.0.0.1:27002",
                        "state" : 1
                },
                {
                        "_id" : "RS2",
                        "host" : "RS2/127.0.0.1:27004,127.0.0.1:27005",
                        "state" : 1
                },
                {
                        "_id" : "RS3",
                        "host" : "RS3/127.0.0.1:27007,127.0.0.1:27008",
                        "state" : 1
                }
        ],
        "ok" : 1,
        "operationTime" : Timestamp(1593142383, 1),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593142383, 1),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
```

balancerStatus
```
mongos> db.adminCommand( { balancerStatus: 1 } )
{
        "mode" : "full",
        "inBalancerRound" : false,
        "numBalancerRounds" : NumberLong(1579),
        "ok" : 1,
        "operationTime" : Timestamp(1593142622, 1),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593142624, 3200),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
```

flushRouterConfig
```
mongos> db.adminCommand( { flushRouterConfig: "tsq.prices" } );
{
        "flushed" : true,
        "ok" : 1,
        "operationTime" : Timestamp(1593143122, 1),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593143122, 1),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
```

getShardDistribution
```
mongos> db.getSiblingDB("tsq").prices.getShardDistribution();

Shard RS1 at RS1/127.0.0.1:27001,127.0.0.1:27002
 data : 31.99MiB docs : 325760 chunks : 1
 estimated data per chunk : 31.99MiB
 estimated docs per chunk : 325760

Shard RS3 at RS3/127.0.0.1:27007,127.0.0.1:27008
 data : 34.23MiB docs : 348485 chunks : 2
 estimated data per chunk : 17.11MiB
 estimated docs per chunk : 174242

Shard RS2 at RS2/127.0.0.1:27004,127.0.0.1:27005
 data : 31.99MiB docs : 325765 chunks : 1
 estimated data per chunk : 31.99MiB
 estimated docs per chunk : 325765

Totals
 data : 98.22MiB docs : 1000010 chunks : 4
 Shard RS1 contains 32.57% data, 32.57% docs in cluster, avg obj size on shard : 103B
 Shard RS3 contains 34.84% data, 34.84% docs in cluster, avg obj size on shard : 103B
 Shard RS2 contains 32.57% data, 32.57% docs in cluster, avg obj size on shard : 103B
```
это нормальные цифры, или нет? не могу оценить...

попутно меряю память
```
$ sudo free -h
              всего        занято        свободно      общая  буф./врем.   доступно
Память:         31G         20G        1,2G         20M        9,7G         10G
Подкачка:        8,0G        512K        8,0G
```

просто какой-то запрос
```
mongos> db.prices.find({id_pe:{$in:[3100000162, 3100000359, 1700000435, 2900000666]}}).limit(100)
{ "_id" : ObjectId("5ef5645fb342cb273906704e"), "id" : 1719051200000435, "id_rev" : 1700000435190512, "id_pe" : 1700000435, "dt" : ISODate("2019-05-12T00:00:00Z"), "price" : 0.3184776353790074, "p" : 17 }
{ "_id" : ObjectId("5ef56493b342cb2739076dc1"), "id" : 1719060600000435, "id_rev" : 1700000435190606, "id_pe" : 1700000435, "dt" : ISODate("2019-06-06T00:00:00Z"), "price" : 0.007263150126781914, "p" : 17 }
{ "_id" : ObjectId("5ef564aab342cb273907e188"), "id" : 1719101000000435, "id_rev" : 1700000435191010, "id_pe" : 1700000435, "dt" : ISODate("2019-10-10T00:00:00Z"), "price" : 0.9613059396531076, "p" : 17 }
{ "_id" : ObjectId("5ef564bab342cb2739082a9b"), "id" : 1719051700000435, "id_rev" : 1700000435190517, "id_pe" : 1700000435, "dt" : ISODate("2019-05-17T00:00:00Z"), "price" : 0.6820936575005356, "p" : 17 }
{ "_id" : ObjectId("5ef564c4b342cb2739085b1a"), "id" : 1719061700000435, "id_rev" : 1700000435190617, "id_pe" : 1700000435, "dt" : ISODate("2019-06-17T00:00:00Z"), "price" : 0.718637995860245, "p" : 17 }
{ "_id" : ObjectId("5ef564cbb342cb273908803c"), "id" : 1719030700000435, "id_rev" : 1700000435190307, "id_pe" : 1700000435, "dt" : ISODate("2019-03-07T00:00:00Z"), "price" : 0.8004255074855655, "p" : 17 }
{ "_id" : ObjectId("5ef564ffb342cb27390976e7"), "id" : 1719021900000435, "id_rev" : 1700000435190219, "id_pe" : 1700000435, "dt" : ISODate("2019-02-19T00:00:00Z"), "price" : 0.7745657679003357, "p" : 17 }
{ "_id" : ObjectId("5ef5654db342cb27390af43a"), "id" : 1719060400000435, "id_rev" : 1700000435190604, "id_pe" : 1700000435, "dt" : ISODate("2019-06-04T00:00:00Z"), "price" : 0.4549633206430256, "p" : 17 }
{ "_id" : ObjectId("5ef56553b342cb27390b1032"), "id" : 1719072300000435, "id_rev" : 1700000435190723, "id_pe" : 1700000435, "dt" : ISODate("2019-07-23T00:00:00Z"), "price" : 0.9110347624477583, "p" : 17 }
{ "_id" : ObjectId("5ef56593b342cb27390c4543"), "id" : 1719090800000435, "id_rev" : 1700000435190908, "id_pe" : 1700000435, "dt" : ISODate("2019-09-08T00:00:00Z"), "price" : 0.531176081750169, "p" : 17 }
{ "_id" : ObjectId("5ef565f7b342cb27390e2435"), "id" : 1719072700000435, "id_rev" : 1700000435190727, "id_pe" : 1700000435, "dt" : ISODate("2019-07-27T00:00:00Z"), "price" : 0.0274577709047521, "p" : 17 }
{ "_id" : ObjectId("5ef56660b342cb2739101c48"), "id" : 1719102200000435, "id_rev" : 1700000435191022, "id_pe" : 1700000435, "dt" : ISODate("2019-10-22T00:00:00Z"), "price" : 0.4383821145279019, "p" : 17 }
{ "_id" : ObjectId("5ef56688b342cb273910dc10"), "id" : 1719110900000435, "id_rev" : 1700000435191109, "id_pe" : 1700000435, "dt" : ISODate("2019-11-09T00:00:00Z"), "price" : 0.19402241141896726, "p" : 17 }
{ "_id" : ObjectId("5ef566bfb342cb273911e488"), "id" : 1719001400000435, "id_rev" : 1700000435190014, "id_pe" : 1700000435, "dt" : ISODate("1970-01-01T00:00:00Z"), "price" : 0.48164534826273053, "p" : 17 }
{ "_id" : ObjectId("5ef566d5b342cb273912537d"), "id" : 1719011100000435, "id_rev" : 1700000435190111, "id_pe" : 1700000435, "dt" : ISODate("2019-01-11T00:00:00Z"), "price" : 0.8962773198097177, "p" : 17 }
{ "_id" : ObjectId("5ef5671ab342cb273913a801"), "id" : 1719041900000435, "id_rev" : 1700000435190419, "id_pe" : 1700000435, "dt" : ISODate("2019-04-19T00:00:00Z"), "price" : 0.360084804630435, "p" : 17 }
{ "_id" : ObjectId("5ef5672ab342cb273913f3ec"), "id" : 1719070400000435, "id_rev" : 1700000435190704, "id_pe" : 1700000435, "dt" : ISODate("2019-07-04T00:00:00Z"), "price" : 0.546451675250804, "p" : 17 }
{ "_id" : ObjectId("5ef5673eb342cb27391455ee"), "id" : 1719030500000435, "id_rev" : 1700000435190305, "id_pe" : 1700000435, "dt" : ISODate("2019-03-05T00:00:00Z"), "price" : 0.48232947867950793, "p" : 17 }
{ "_id" : ObjectId("5ef56350b342cb2739067045"), "id" : 2919070000000666, "id_rev" : 2900000666190700, "id_pe" : 2900000666, "dt" : ISODate("1970-01-01T00:00:00Z"), "price" : 0.73670183745665, "p" : 29 }
{ "_id" : ObjectId("5ef5648fb342cb2739075a80"), "id" : 2919052700000666, "id_rev" : 2900000666190527, "id_pe" : 2900000666, "dt" : ISODate("2019-05-27T00:00:00Z"), "price" : 0.7118082346780076, "p" : 29 }
Type "it" for more
```

## 3. Настроить аутентификацию и многоролевой доступ. <a name="roles"></a>

Из документации:
```
mongos> use admin
switched to db admin
mongos> db.createUser(
...   {
...     user: "myUserAdmin",
...     pwd: passwordPrompt(), // or cleartext password
...     roles: [ { role: "userAdminAnyDatabase", db: "admin" }, "readWriteAnyDatabase" ]
...   }
... )
Enter password:
Successfully added user: {
        "user" : "myUserAdmin",
        "roles" : [
                {
                        "role" : "userAdminAnyDatabase",
                        "db" : "admin"
                },
                "readWriteAnyDatabase"
        ]
}
```
пароль ввёл 123

Тоже из документации:
```

mongos> use test
switched to db test
mongos> db.createUser(
...   {
...     user: "myTester",
...     pwd:  passwordPrompt(),   // or cleartext password
...     roles: [ { role: "readWrite", db: "test" },
...              { role: "read", db: "reporting" } ]
...   }
... );
Enter password:
Successfully added user: {
        "user" : "myTester",
        "roles" : [
                {
                        "role" : "readWrite",
                        "db" : "test"
                },
                {
                        "role" : "read",
                        "db" : "reporting"
                }
        ]
}
```
пароль ввёл 123

Итого у меня есть теперь два пользователя: myUserAdmin и myTester

myUserAdmin
```
$ mongo --port 27000  --authenticationDatabase "admin" -u "myUserAdmin" -p
MongoDB shell version v4.2.8
Enter password:
connecting to: mongodb://127.0.0.1:27000/?authSource=admin&compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("c7615cbc-3bd9-4992-9bb3-06274c1fdf9e") }
MongoDB server version: 4.2.8
...
mongos> use tsq
switched to db tsq
mongos> db.prices.find({id_pe:{$in:[3100000162, 3100000359, 1700000435, 2900000666]}}).limit(1)
{ "_id" : ObjectId("5ef5645fb342cb273906704e"), "id" : 1719051200000435, "id_rev" : 1700000435190512, "id_pe" : 1700000435, "dt" : ISODate("2019-05-12T00:00:00Z"), "price" : 0.3184776353790074, "p" : 17 }
mongos> exit
bye
```

myTester
```
$ mongo --port 27000 -u "myTester" --authenticationDatabase "test" -p
MongoDB shell version v4.2.8
Enter password:
connecting to: mongodb://127.0.0.1:27000/?authSource=test&compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("daf4bb89-dffa-4c0a-9bc0-bc41aca181bf") }
...
mongos> use tsq
switched to db tsq
mongos> db.prices.find({id_pe:{$in:[3100000162, 3100000359, 1700000435, 2900000666]}}).limit(1)
{ "_id" : ObjectId("5ef5645fb342cb273906704e"), "id" : 1719051200000435, "id_rev" : 1700000435190512, "id_pe" : 1700000435, "dt" : ISODate("2019-05-12T00:00:00Z"), "price" : 0.3184776353790074, "p" : 17 }
mongos> db.foo.insert( { x: 1, y: 1 } )
WriteResult({ "nInserted" : 1 })
mongos> exit
bye
```

ПОЧЕМУ-ТО myTester-у тоже разрешилось почитать tsq.prices и сделать запись в tsq.foo.
Почему - непонятно...

## 4. Поронять разные инстансы, посмотреть, что будет происходить, поднять обратно. Описать что произошло. <a name="kills"></a>

Убью мастера на каждой из шард

```
$ ps aux | grep mongo| grep -Ev "grep"
root      4370  0.9  1.1 2344088 386248 ?      Sl   03:51   2:13 mongod --shardsvr --dbpath /home/mongo/db1 --port 27001 --replSet RS1 --fork --logpath /home/mongo/db1/db1.log --pidfilepath /home/mongo/db1/db1.pid
root      4512  1.0  1.1 2277192 380044 ?      Sl   03:51   2:20 mongod --shardsvr --dbpath /home/mongo/db2 --port 27002 --replSet RS1 --fork --logpath /home/mongo/db2/db2.log --pidfilepath /home/mongo/db2/db2.pid
root      4616  0.4  0.3 1626600 99684 ?       Sl   03:51   1:04 mongod --shardsvr --dbpath /home/mongo/db3 --port 27003 --replSet RS1 --fork --logpath /home/mongo/db3/db3.log --pidfilepath /home/mongo/db3/db3.pid
root      4848  0.9  1.1 2363576 379760 ?      Sl   03:52   2:04 mongod --shardsvr --dbpath /home/mongo/db4 --port 27004 --replSet RS2 --fork --logpath /home/mongo/db4/db4.log --pidfilepath /home/mongo/db4/db4.pid
root      4949  0.9  1.1 2277608 375288 ?      Sl   03:52   2:11 mongod --shardsvr --dbpath /home/mongo/db5 --port 27005 --replSet RS2 --fork --logpath /home/mongo/db5/db5.log --pidfilepath /home/mongo/db5/db5.pid
root      5038  0.4  0.2 1628344 98216 ?       Sl   03:53   1:03 mongod --shardsvr --dbpath /home/mongo/db6 --port 27006 --replSet RS2 --fork --logpath /home/mongo/db6/db6.log --pidfilepath /home/mongo/db6/db6.pid
root      5326  4.7  3.1 3035800 1031928 ?     Sl   03:53  10:44 mongod --shardsvr --dbpath /home/mongo/db7 --port 27007 --replSet RS3 --fork --logpath /home/mongo/db7/db7.log --pidfilepath /home/mongo/db7/db7.pid
root      5433  6.1  3.3 2995140 1089420 ?     Sl   03:54  14:05 mongod --shardsvr --dbpath /home/mongo/db8 --port 27008 --replSet RS3 --fork --logpath /home/mongo/db8/db8.log --pidfilepath /home/mongo/db8/db8.pid
root      5523  0.4  0.2 1628500 97712 ?       Sl   03:54   1:03 mongod --shardsvr --dbpath /home/mongo/db9 --port 27009 --replSet RS3 --fork --logpath /home/mongo/db9/db9.log --pidfilepath /home/mongo/db9/db9.pid
root      5720  1.1  0.3 2117256 128112 ?      SLl  03:54   2:33 mongod --configsvr --dbpath /home/mongo/dbc11 --port 27011 --replSet RSC --fork --logpath /home/mongo/dbc11/dbc11.log --pidfilepath /home/mongo/dbc11/dbc11.pid
root      5829  1.1  0.3 2089792 126704 ?      Sl   03:55   2:32 mongod --configsvr --dbpath /home/mongo/dbc12 --port 27012 --replSet RSC --fork --logpath /home/mongo/dbc12/dbc12.log --pidfilepath /home/mongo/dbc12/dbc12.pid
root      5935  1.0  0.3 2047664 127676 ?      Sl   03:55   2:18 mongod --configsvr --dbpath /home/mongo/dbc13 --port 27013 --replSet RSC --fork --logpath /home/mongo/dbc13/dbc13.log --pidfilepath /home/mongo/dbc13/dbc13.pid
root      6305  2.5  0.1 361952 37216 ?        Sl   03:56   5:41 mongos --configdb RSC/127.0.0.1:27011,127.0.0.1:27012,127.0.0.1:27013 --port 27000 --fork --logpath /home/mongo/dbc11/dbs.log --pidfilepath /home/mongo/dbc11/dbs.pid
feynman   6427  2.8  0.1 1241680 50164 pts/0   SLl+ 03:57   6:29 mongo --port 27000


$ sudo kill 4370
feynman@feynman-desktop:~$ mongo --port 27002
MongoDB shell version v4.2.8
connecting to: mongodb://127.0.0.1:27002/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("e77c2ae4-38a9-4679-b101-88fb682f1c99") }
MongoDB server version: 4.2.8
...

RS1:SECONDARY> rs.status()
{
        "set" : "RS1",
        "date" : ISODate("2020-06-26T04:45:31.793Z"),
        "myState" : 1,
        "term" : NumberLong(6),
        "syncingTo" : "",
        "syncSourceHost" : "",
        "syncSourceId" : -1,
        "heartbeatIntervalMillis" : NumberLong(2000),
        "majorityVoteCount" : 2,
        "writeMajorityCount" : 2,
        "optimes" : {
                "lastCommittedOpTime" : {
                        "ts" : Timestamp(1593146706, 1),
                        "t" : NumberLong(4)
                },
                "lastCommittedWallTime" : ISODate("2020-06-26T04:45:06.315Z"),
                "readConcernMajorityOpTime" : {
                        "ts" : Timestamp(1593146706, 1),
                        "t" : NumberLong(4)
                },
                "readConcernMajorityWallTime" : ISODate("2020-06-26T04:45:06.315Z"),
                "appliedOpTime" : {
                        "ts" : Timestamp(1593146722, 2),
                        "t" : NumberLong(6)
                },
                "durableOpTime" : {
                        "ts" : Timestamp(1593146722, 2),
                        "t" : NumberLong(6)
                },
                "lastAppliedWallTime" : ISODate("2020-06-26T04:45:22.290Z"),
                "lastDurableWallTime" : ISODate("2020-06-26T04:45:22.290Z")
        },
        "lastStableRecoveryTimestamp" : Timestamp(1593146676, 1),
        "lastStableCheckpointTimestamp" : Timestamp(1593146676, 1),
        "electionCandidateMetrics" : {
                "lastElectionReason" : "electionTimeout",
                "lastElectionDate" : ISODate("2020-06-26T04:45:22.286Z"),
                "electionTerm" : NumberLong(6),
                "lastCommittedOpTimeAtElection" : {
                        "ts" : Timestamp(1593146706, 1),
                        "t" : NumberLong(4)
                },
                "lastSeenOpTimeAtElection" : {
                        "ts" : Timestamp(1593146706, 1),
                        "t" : NumberLong(4)
                },
                "numVotesNeeded" : 2,
                "priorityAtElection" : 1,
                "electionTimeoutMillis" : NumberLong(10000),
                "numCatchUpOps" : NumberLong(0),
                "newTermStartDate" : ISODate("2020-06-26T04:45:22.290Z")
        },
        "electionParticipantMetrics" : {
                "votedForCandidate" : true,
                "electionTerm" : NumberLong(4),
                "lastVoteDate" : ISODate("2020-06-26T00:51:55.975Z"),
                "electionCandidateMemberId" : 0,
                "voteReason" : "",
                "lastAppliedOpTimeAtElection" : {
                        "ts" : Timestamp(1593132715, 1),
                        "t" : NumberLong(3)
                },
                "maxAppliedOpTimeInSet" : {
                        "ts" : Timestamp(1593132715, 1),
                        "t" : NumberLong(3)
                },
                "priorityAtElection" : 1
        },
        "members" : [
                {
                        "_id" : 0,
                        "name" : "127.0.0.1:27001",
                        "health" : 0,
                        "state" : 8,
                        "stateStr" : "(not reachable/healthy)",
                        "uptime" : 0,
                        "optime" : {
                                "ts" : Timestamp(0, 0),
                                "t" : NumberLong(-1)
                        },
                        "optimeDurable" : {
                                "ts" : Timestamp(0, 0),
                                "t" : NumberLong(-1)
                        },
                        "optimeDate" : ISODate("1970-01-01T00:00:00Z"),
                        "optimeDurableDate" : ISODate("1970-01-01T00:00:00Z"),
                        "lastHeartbeat" : ISODate("2020-06-26T04:45:30.290Z"),
                        "lastHeartbeatRecv" : ISODate("2020-06-26T04:45:11.989Z"),
                        "pingMs" : NumberLong(0),
                        "lastHeartbeatMessage" : "Error connecting to 127.0.0.1:27001 :: caused by :: Connection refused",
                        "syncingTo" : "",
                        "syncSourceHost" : "",
                        "syncSourceId" : -1,
                        "infoMessage" : "",
                        "configVersion" : -1
                },
                {
                        "_id" : 1,
                        "name" : "127.0.0.1:27002",
                        "health" : 1,
                        "state" : 1,
                        "stateStr" : "PRIMARY",
                        "uptime" : 14038,
                        "optime" : {
                                "ts" : Timestamp(1593146722, 2),
                                "t" : NumberLong(6)
                        },
                        "optimeDate" : ISODate("2020-06-26T04:45:22Z"),
                        "syncingTo" : "",
                        "syncSourceHost" : "",
                        "syncSourceId" : -1,
                        "infoMessage" : "could not find member to sync from",
                        "electionTime" : Timestamp(1593146722, 1),
                        "electionDate" : ISODate("2020-06-26T04:45:22Z"),
                        "configVersion" : 1,
                        "self" : true,
                        "lastHeartbeatMessage" : ""
                },
                {
                        "_id" : 2,
                        "name" : "127.0.0.1:27003",
                        "health" : 1,
                        "state" : 7,
                        "stateStr" : "ARBITER",
                        "uptime" : 14027,
                        "lastHeartbeat" : ISODate("2020-06-26T04:45:30.289Z"),
                        "lastHeartbeatRecv" : ISODate("2020-06-26T04:45:29.844Z"),
                        "pingMs" : NumberLong(0),
                        "lastHeartbeatMessage" : "",
                        "syncingTo" : "",
                        "syncSourceHost" : "",
                        "syncSourceId" : -1,
                        "infoMessage" : "",
                        "configVersion" : 1
                }
        ],
        "ok" : 1,
        "$gleStats" : {
                "lastOpTime" : Timestamp(0, 0),
                "electionId" : ObjectId("7fffffff0000000000000006")
        },
        "lastCommittedOpTime" : Timestamp(1593146706, 1),
        "$configServerState" : {
                "opTime" : {
                        "ts" : Timestamp(1593146720, 1),
                        "t" : NumberLong(2)
                }
        },
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593146722, 2),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        },
        "operationTime" : Timestamp(1593146722, 2)
}
RS1:PRIMARY>
```

SECONDARY превратился в PRIMARY, поскольку 127.0.0.1:27001 (not reachable/healthy).
Думаю, они там быстро проголосовали и выбрали безальтернативного кандидата.

```
$ sudo kill 4848
$ sudo kill 5326

$ sudo free -h
              всего        занято        свободно      общая  буф./врем.   доступно
Память:         31G         18G        2,7G         20M        9,8G         12G
Подкачка:        8,0G        512K        8,0G

mongos> use tsq
switched to db tsq
mongos> db.prices.find({id_pe:{$in:[3100000162, 3100000359, 1700000435, 2900000666]}}).limit(100)
{ "_id" : ObjectId("5ef5645fb342cb273906704e"), "id" : 1719051200000435, "id_rev" : 1700000435190512, "id_pe" : 1700000435, "dt" : ISODate("2019-05-12T00:00:00Z"), "price" : 0.3184776353790074, "p" : 17 }
...
{ "_id" : ObjectId("5ef5648fb342cb2739075a80"), "id" : 2919052700000666, "id_rev" : 2900000666190527, "id_pe" : 2900000666, "dt" : ISODate("2019-05-27T00:00:00Z"), "price" : 0.7118082346780076, "p" : 29 }
Type "it" for more
```

Данные тем не менее доступны.


Вроде всё.
Непонятка с моими пользователями получилась, myTester-у всё можно, хотя должно быть нельзя.
Но уже не хватает времени копать (


