ДЗ OTUS-RDBMS-2019-10 по занятию 15 - MySql: Хранимые процедуры и триггеры
---------------------------------------------------------
Цель: использовать хранимые процедуры и функций для оптимизации работы с БД
---------------------------------------------------------

- Создать пользователей client, manager.
- Создать процедуру выборки товаров с использованием различных фильтров: категория, цена, производитель, различные дополнительные параметры
Также в качестве параметров передавать по какому полю сортировать выборку, и параметры постраничной выдачи
- дать права да запуск процедуры пользователю client

- Создать процедуру get_orders - которая позволяет просматривать отчет по продажам за определенный период (час, день, неделя)
с различными уровнями группировки (по товару, по категории, по производителю)
- права дать пользователю manager

## 4. docker <a name="docker"></a>

сам себе: mysqldump
```
sudo mysqldump tsq -p*** --extended-insert=FALSE --single-transaction --tables spreads --where="id in (select id from tsq.prices where id_pe IN (SELECT DISTINCT pair_id FROM portfolio.watchlist_bonds))" > ~/_tsq_spreads.sql

sudo mysqldump tsq -p*** --extended-insert=FALSE --single-transaction --tables risks_metrics --where="id in (select id from tsq.prices where id_pe IN (SELECT DISTINCT pair_id FROM portfolio.watchlist_bonds))" > ~/_tsq_risks_metrics.sql

sudo mysqldump tsq -p*** --extended-insert=FALSE --single-transaction --tables yields --where="id in (select id from tsq.prices where id_pe IN (SELECT DISTINCT pair_id FROM portfolio.watchlist_bonds))" > ~/_tsq_yields.sql

sudo mysqldump portfolio -p*** --single-transaction --tables watchlist_instruments > ~/_watchlist_instruments.sql
sudo mysqldump portfolio -p*** --single-transaction --tables watchlist_equities > ~/_watchlist_equities.sql
sudo mysqldump portfolio -p*** --single-transaction --tables watchlist_depts > ~/_watchlist_depts.sql
sudo mysqldump portfolio -p*** --single-transaction --tables watchlist_bonds > ~/_watchlist_bonds.sql
```

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