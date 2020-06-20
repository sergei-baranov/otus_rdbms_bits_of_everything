ДЗ OTUS-RDBMS-2019-10 по занятию 13 - MySql: Индексы
---------------------------------------------------------
Задача - сделать полнотекстовый индекс, который ищет по свойствам, названию товара и описанию; в README представить запрос для тестирования
---------------------------------------------------------

# Table of Contents
1. [Общее описание](#commondescr)
2. [Как заполняется поле allwords](#preparedata)
3. [Как делаем запросы](#preparequery)
4. [Тестовые запросы](#testqueries)
5. [Ошибочность первоначального варианта](#fail)
6. [Релевантность](#relevancy)
7. [Подходящий вариант](#win)
8. [Charset/Colaltion](#collation)
9. [Docker](#docker)

## Общее описание <a name="commondescr"></a>

Как я это делаю по текущей задаче на работе.

Сейчас необходимо организовать так называемый suggest (автокомплитер)
для такой сущности как "участник размещений выпусков облигаций".<br/>
В форме фильтрации выпусков облигаций есть фильтр "Участник размещения",
который передаёт в процедуру фильтрации id участника, но пользователь этого id не знает.<br/>
Название же организации он знает тоже достаточно приблизительно,
при этом неведомо, на каком языке.

Задача - при помощи автокомплитера определить id организации для передачи в процедуру фильтрации (в поле формы с полями-фильтрами).
Посетитель вводит часть названия организации, suggest предлагает ему на выбор варианты.
Чем больше символов ввёл посетитель, тем меньше вариантов. В идеале - один вариант.

Sphinx мы пока не ставили, как переходный вариант используем MySql FULLTEXT-индексы.

Под каждый suggest (их несколько уже есть: поиск облигаций, поиск индексов и т.п., теперь добавляется поиск участников доразмещений) я создаю отдельную таблицу, содержащую как минимум два поля:
- id искомой сущности (как правило это поле и ПК, оно же FK на таблицу с данными по сущности)
- поле allwords, на которое и вешаю FULLTEXT-индекс

Явное указание поля FTS_DOC_ID и прочие "тонкие настройки" из документации мы не используем,<br/>
стопслова у нас английские из поставки, innodb_ft_min_token_size равен трём и т.п.

(мы будем переводиться на Сфинкс, так как пошло наполнение китайскими данными,<br/>
и по этому поводу у нас есть ресурс на внедрение каких-то более гибких схем,<br/>
чем встроенные в Мускул из коробки, поэтому всякие штуки типа "ngram Full-Text Parser"<br/>
мы бегло прочитали и отбросили, ожидая, что всё это Сфинкс нам обеспечит получше).

В реальности полей и таблиц больше,<br/>
так как алгоритмы часто включают в себя сначала поиск по таблице с уникальными кодами сущностей,<br/>
и при наличии полного (или даже частичного) совпадения с term-ом (тем, что ввёл посетитель),<br/>
полнотекстовый поиск не производится; в каждом случае алгоритм немного меняется.

## Как заполняется поле allwords <a name="preparedata"></a>

У нас есть исходные таблицы, join которых позволяет получить резалтсет,<br/>
в данном случае по полям примерно такой:

    | id | name_rus | name_eng | full_name_rus | full_name_eng | name_ita | name_pol | ...

Приложение, которое заполняет таблицу для полнотекстового поиска,<br/>
склеивает все строковые поля в `allwords`, но перед этим:
- зачищает тексты от не-словных-символов (регулярка /\W+/u)
- приводит весь текст к нижнему регистру
- НЕ отбрасывает короткие слова (если в запросе будут слова короче 3-х символов, то искать будем like-ом)
- отбрасывает повторяющиеся слова
- сортирует все слова (хак для случая с поиском like-ом)

В данном случае я заведу в таблице три поля:
- `id` bigint unsigned
- `allwords` varchar(1024)
- `names` text

В `names` закину все поля, тупо сконкатенированные пробелом (без зачистки, lowercase-а, сортировки и т.п.).

Поле id будет PRIMARY KEY.<br/>
На поля `allwords` и `names` накину FULLTEXT INDEX,<br/>
а на поле `allwords` ещё и обычный BTREE.

    CREATE TABLE `old`.participants_suggest` (
     `id` bigint(20) unsigned NOT NULL COMMENT 'PK; FK to su.emitents.id_of_emitent',
     `names` text NOT NULL,
     `allwords` varchar(1024) NOT NULL DEFAULT '',
     `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
     PRIMARY KEY (`id`),
     KEY `allwords_btree` (`allwords`(255)) USING BTREE,
     FULLTEXT KEY `allwords_fulltext` (`allwords`),
     FULLTEXT KEY `names_fulltext` (`names`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Для автокомплитера "участники размещений"'

Результат получается примерно такой:

    USE `old`;
    INSERT INTO `participants_suggest`
    (`id`, `names`, `allwords`, `updated_at`)
    VALUES
    (22, 'Банк Кредит Свисс Bank Credit Suisse Банк Кредит Свисс CJSC “BANK CREDIT SUISSE (MOSCOW)”', 'bank cjsc credit moscow suisse банк кредит свисс', '2020-06-19 01:26:36'),
    (50, 'ВТБ VTB Банк ВТБ (ПАО) Bank VTB (PJSC)', 'bank pjsc vtb банк втб пао', '2020-06-19 01:26:36'),
    (53, 'БИНБАНК B&N Bank ПАО \"БИНБАНК\" B&N Bank (Public Joint-Stock Company)', 'bank bn company jointstock public бинбанк пао', '2020-06-19 01:49:00'),
    (8628, 'PKO Bank Polski PKO Bank Polski PKO Bank Polski PKO Bank Polski PKO Bank Polski Powszechna Kasa Oszczędności Bank Polski SA', 'bank kasa oszczędności pko polski powszechna sa', '2020-06-19 01:49:01')
    /* и т. д. */;

(Можем заметить на примере Бинбанка, что в БД бывает треш с подсечёнными лишний раз кавычками и т.п.)

## Как делаем запросы <a name="preparequery"></a>

На вход в приложение получаем term и далее:
- разбиваем его на слова (/\s+/is),
- вычищаем не-буквенные символы (/\W+/u),
- приводим к нижнему регистру,
- убираем дублирующиеся слова,
- сортируем слова

Если среди слов нет слов длиной меньше трёх (допустим, "абакан вкусвилл ягода"),
то идём на полнотекстовый поиск:

    SELECT `id` FROM old.participants_suggest WHERE
    MATCH(`allwords`) AGAINST('+абакан* +вкусвилл* +ягода*') IN BOOLEAN MODE

Если среди слов были короче 3-х символов, то ищем LIKE-ом:

    SELECT `id` FROM old.participants_suggest WHERE
    `allwords` LIKE '%абакан%вкусвилл%ягода%co%'

## Тестовые запросы <a name="testqueries"></a>

Посетитель ввёл "Citigroup"

    /* Citigroup */
    SELECT `id` FROM old.participants_suggest
    WHERE MATCH(`allwords`) AGAINST('+citigroup*' IN BOOLEAN MODE);
    /* 7 строк, 2..4 ms */
    SELECT `id` FROM old.participants_suggest
    WHERE MATCH(`names`) AGAINST('+citigroup*' IN BOOLEAN MODE);
    /* 7 строк, 2..4 ms */
    SELECT `id` FROM old.participants_suggest WHERE `allwords` LIKE '%citigroup%';
    /* 7 строк, 6..8 ms */
    SELECT `id` FROM old.participants_suggest FORCE INDEX (`allwords_btree`)
    WHERE `allwords` LIKE '%citigroup%';
    /* 7 строк, 6..8 ms; а индекс при таком запросе (с wildcard-ом в начале) в принципе не работает */

Посетитель ввёл "KBC Bank"

    /* KBC Bank */
    SELECT `id` FROM old.participants_suggest
    WHERE MATCH(`allwords`) AGAINST('+bank* +kbc*' IN BOOLEAN MODE);
    /* 2 строк, 3..5 ms */
    SELECT `id` FROM old.participants_suggest
    WHERE MATCH(`names`) AGAINST('+bank* +kbc*' IN BOOLEAN MODE);
    /* 2 строк, 3..5 ms */
    SELECT `id` FROM old.participants_suggest
    WHERE `allwords` LIKE '%bank%kbc%';
    /* 2 строк, 6..7 ms */

Посетитель ввёл "Powszechna Kasa Oszczędności Bank Polski SA"

    /* Powszechna Kasa Oszczędności Bank Polski SA */
    SELECT `id` FROM old.participants_suggest
    WHERE `allwords` LIKE '%bank%kasa%oszczędności%polski%powszechna%sa%';
    /* 1 строк, 5..7 ms */

Посетитель ввёл "Powszechna Kasa Oszczędności Bank Polski"

    /* Powszechna Kasa Oszczędności Bank Polski */
    SELECT `id` FROM old.participants_suggest
    WHERE MATCH(`allwords`) AGAINST('+bank* +kasa* +oszczędności* +polski* +powszechna*' IN BOOLEAN MODE);
    /* 1 строк, 3..5 ms */
    SELECT `id` FROM old.participants_suggest
    WHERE `allwords` LIKE '%bank%kasa%oszczędności%polski%powszechna%';
    /* 1 строк, 5..7 ms */

Посетитель ввёл "Standard Chartered Bank"

    /* Standard Chartered Bank */
    SELECT `id` FROM old.participants_suggest
    WHERE MATCH(`allwords`) AGAINST('+bank* +chartered* +standard*' IN BOOLEAN MODE);
    /* 6 строк, 3..4 ms */
    SELECT `id` FROM old.participants_suggest
    WHERE `allwords` LIKE '%bank%chartered%standard%';
    /* 6 строк, 6 ms */

## Ошибочность первоначального варианта <a name="fail"></a>

НО: Всё это вообще не будет работать, если посетитель введёт хотя бы одно несуществующее слово (например допустит ожибку в одном из слов); как пример - "Powszechna Kasa Oszczędności Bank Polski SDA" (ввёл SDA вместо SA).

Посетитель ввёл "Powszechna Kasa Oszczędności Bank Polski SDA"

    /* Powszechna Kasa Oszczędności Bank Polski SDA */
    SELECT `id` FROM old.participants_suggest
    WHERE MATCH(`allwords`) AGAINST('+bank* +kasa* +oszczędności* +polski* +powszechna* +sda*' IN BOOLEAN MODE);
    /* 0 строк, 3..5 ms */
    SELECT `id` FROM old.participants_suggest
    WHERE `allwords` LIKE '%bank%kasa%oszczędności%polski%powszechna%sda%';
    /* 0 строк, 5..7 ms */

Очевидно, что надо убирать обязательность всех слов, но тогда слишком объёмный результат:

    SELECT `id`, `names`, `allwords`,
    MATCH(`allwords`) AGAINST('Powszechna Kasa Oszczędności Bank Polski SDA') as rel
    FROM old.participants_suggest
    WHERE MATCH(`allwords`) AGAINST('Powszechna Kasa Oszczędności Bank Polski SDA');
    /* 200 строк 5..7 ms */
    
    SELECT `id`, `names`, `allwords`,
    MATCH(`allwords`) AGAINST('bank* kasa* oszczędności* polski* powszechna* sda*' IN BOOLEAN MODE) as `rel`
    FROM old.participants_suggest
    WHERE MATCH(`allwords`) AGAINST('bank* kasa* oszczędności* polski* powszechna* sda*' IN BOOLEAN MODE);
    /* 200 строк 5..7 ms */

## Релевантность <a name="relevancy"></a>

Тогда - надо играться с релевантностью:

Посетитель ввёл "Powszechna Kasa Oszczędności Bank Polski SDA"

    /* Powszechna Kasa Oszczędności Bank Polski SDA */
    SELECT `id`, `names`, `allwords`, `rel` FROM (
      SELECT `id`, `names`, `allwords`,
      MATCH(`allwords`) AGAINST('bank* kasa* szczędności* polski* powszechna* sda*' IN BOOLEAN MODE) as `rel`
      FROM old.participants_suggest
      WHERE MATCH(`allwords`) AGAINST('bank* kasa* szczędności* polski* powszechna* sda*' IN BOOLEAN MODE)
    ) t WHERE t.`rel` > 1 ORDER BY t.`rel` DESC;
    /* 4 строк 8 ms */

Посетитель ввёл "Standard Chartered Bank"

    /* Standard Chartered Bank */
    SELECT `id`, `names`, `allwords`, `rel` FROM (
      SELECT `id`, `names`, `allwords`,
      MATCH(`allwords`) AGAINST('bank* chartered* standard*' IN BOOLEAN MODE) as `rel`
      FROM old.participants_suggest
      WHERE MATCH(`allwords`) AGAINST('bank* chartered* standard*' IN BOOLEAN MODE)
    ) t WHERE t.`rel` > 1 ORDER BY t.`rel` DESC;
    /* 20 строк, 7..10 ms */

Посетитель ввёл "Citigroup"

    /* Citigroup */
    SELECT `id`, `names`, `allwords`, `rel` FROM (
      SELECT `id`, `names`, `allwords`,
      MATCH(`allwords`) AGAINST('citigroup*' IN BOOLEAN MODE) as `rel`
      FROM old.participants_suggest
      WHERE MATCH(`allwords`) AGAINST('citigroup*' IN BOOLEAN MODE)
    ) t WHERE t.`rel` > 1 ORDER BY t.`rel` DESC;
    /* 7 строк 4 ms */

Может это сработает и на `names`? "Standard Chartered Bank"

    /* может это сработает и на `names` ? */
    SELECT `id`, `names`, `allwords`, `rel` FROM (
      SELECT `id`, `names`, `allwords`,
      MATCH(`names`) AGAINST('bank* chartered* standard*' IN BOOLEAN MODE) as `rel`
      FROM old.participants_suggest
      WHERE MATCH(`names`) AGAINST('bank* chartered* standard*' IN BOOLEAN MODE)
    ) t WHERE t.`rel` > 1 ORDER BY t.`rel` DESC;
    /* неподготовленное поле `names`, 200 строк, 9 ms, не вариант */


## Подходящий вариант <a name="win"></a>

Таким образом, приемлемо избыточный, но быстрый и надёжный вариант - искать как раньше,
с чисткой слов на входе, по подготовленному полю, в IN BOOLEAN MODE, но убирать обязательность всех слов (+),
и ориентировться на `rel` > 1.

Неподготовленное поле `names` при таком раскладе бессмысленно, слишком огромный нерелевантный результат.
Обязательность каждого слова глупость (ничего не найдётся при ошибке в одном любом).
А подготовленное поле + необязательность + булеан мод + релевантность = хороший результат.

При таком подходе так же не надо использовать запрос с LIKE-ом, начинающимся с %,
который не использует индекс вообще, ну и соответственно BTREE-индекс не нужен.

Таблица тогда такая:

    CREATE TABLE `participants_suggest` (
     `id` bigint(20) unsigned NOT NULL COMMENT 'PK; FK to su.emitents.id_of_emitent',
     `allwords` varchar(1024) NOT NULL DEFAULT '',
     `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
     PRIMARY KEY (`id`),
     FULLTEXT KEY `allwords_fulltext` (`allwords`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Для автокомплитера "участники размещений"'

Типовой запрос тогда такой:

    /*  для Standard Chartered Bank */
    SELECT
      `id`,
      `rel`
    FROM
      (
        SELECT `id`, MATCH(`allwords`) AGAINST('bank* chartered* standard*' IN BOOLEAN MODE) as `rel`
        FROM old.participants_suggest
        WHERE MATCH(`allwords`) AGAINST('bank* chartered* standard*' IN BOOLEAN MODE)
      ) t
    WHERE
      t.`rel` > 1
    ORDER BY
      t.`rel` DESC;
    /* 20 строк, 7..10 ms */

сам себе см. https://dev.mysql.com/doc/refman/8.0/en/fulltext-boolean.html
(How Relevancy Ranking is Calculated)

## Charset/Colaltion <a name="collation"></a>

А теперь поэкспериментируем с CHARSET-ом

Таблица с utf8:

    CREATE TABLE `participants_suggest_8` (
     `id` bigint(20) unsigned NOT NULL COMMENT 'PK; FK to su.emitents.id_of_emitent',
     `allwords` varchar(1024) NOT NULL DEFAULT '',
     `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
     PRIMARY KEY (`id`),
     FULLTEXT KEY `allwords_fulltext` (`allwords`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
    COMMENT='Для автокомплитера "участники размещений"'
    TABLESPACE `innodb_file_per_table` DATA DIRECTORY = '/mysql_tablespaces/sd1t/old';

Таблица с utf8mb4:

    CREATE TABLE `participants_suggest_900` (
     `id` bigint(20) unsigned NOT NULL COMMENT 'PK; FK to su.emitents.id_of_emitent',
     `allwords` varchar(1024) NOT NULL DEFAULT '',
     `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
     PRIMARY KEY (`id`),
     FULLTEXT KEY `allwords_fulltext` (`allwords`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
    COMMENT='Для автокомплитера "участники размещений"'
    TABLESPACE `innodb_file_per_table` DATA DIRECTORY = '/mysql_tablespaces/sd1t/old';

Запросы

    SELECT `id` FROM old.participants_suggest_8 WHERE `allwords` LIKE '%bank%kasa%oszczędności%polski%powszechna%sa%';
    /* 1 строк 6 ms */
    SELECT `id` FROM old.participants_suggest_900 WHERE `allwords` LIKE '%bank%kasa%oszczędności%polski%powszechna%sa%';
    /* 1 строк 6 ms */

    SELECT `id` FROM old.participants_suggest_8 WHERE
    MATCH(`allwords`) AGAINST('+bank* +kasa* +oszczędności* +polski* +powszechna*' IN BOOLEAN MODE);
    /* 1 строк 3_5 ms */
    SELECT `id` FROM old.participants_suggest_900 WHERE
    MATCH(`allwords`) AGAINST('+bank* +kasa* +oszczędności* +polski* +powszechna*' IN BOOLEAN MODE);
    /* 1 строк 3_5 ms */

    SELECT `id` FROM old.participants_suggest_8 WHERE
    MATCH(`allwords`) AGAINST('+bank* +kasa* +oszczędności* +polski* +powszechna* +sda*' IN BOOLEAN MODE);
    /* 0 строк 4 ms */
    SELECT `id` FROM old.participants_suggest_900 WHERE
    MATCH(`allwords`) AGAINST('+bank* +kasa* +oszczędności* +polski* +powszechna* +sda*' IN BOOLEAN MODE);
    /* 0 строк 4 ms */

    /* Citigroup */
    SELECT `id`, `allwords`, `rel` FROM (
      SELECT `id`, `allwords`, MATCH(`allwords`) AGAINST('citigroup*' IN BOOLEAN MODE) as `rel`
      FROM old.participants_suggest_8 WHERE MATCH(`allwords`) AGAINST('citigroup*' IN BOOLEAN MODE)
    ) t WHERE t.`rel` > 1 ORDER BY t.`rel` DESC;
    /* 7 строк 2..3 ms */
    SELECT `id`, `allwords`, `rel` FROM (
      SELECT `id`, `allwords`, MATCH(`allwords`) AGAINST('citigroup*' IN BOOLEAN MODE) as `rel`
      FROM old.participants_suggest_900 WHERE MATCH(`allwords`) AGAINST('citigroup*' IN BOOLEAN MODE)
    ) t WHERE t.`rel` > 1 ORDER BY t.`rel` DESC;
    /* 7 строк 2..3 ms */

    /* акционерн банк */
    SELECT `id`, `allwords`, `rel` FROM (
      SELECT `id`, `allwords`, MATCH(`allwords`) AGAINST('акционерн* банк*' IN BOOLEAN MODE) as `rel`
      FROM old.participants_suggest_8 WHERE MATCH(`allwords`) AGAINST('акционерн* банк*' IN BOOLEAN MODE)
    ) t WHERE t.`rel` > 1 ORDER BY t.`rel` DESC;
    /* 200 строк 10 ms */
    SELECT `id`, `allwords`, `rel` FROM (
      SELECT `id`, `allwords`, MATCH(`allwords`) AGAINST('акционерн* банк*' IN BOOLEAN MODE) as `rel`
      FROM old.participants_suggest_900 WHERE MATCH(`allwords`) AGAINST('акционерн* банк*' IN BOOLEAN MODE)
    ) t WHERE t.`rel` > 1 ORDER BY t.`rel` DESC;
    /* 200 строк 10 ms */


На малых объёмах (таблица всего 4К записей),<br/>
с единичными тестами на глаз,<br/>
на ссд-диске,<br/>
на ненагруженной машине,<br/>
с много памятью - результаты одинаковые.

## Docker <a name="docker"></a>

#### Поднять сервис можно командой:

```
docker-compose up otus_rdbms_201910_sergei_baranov_w13
```

#### Остановить:

```
docker-compose stop otus_rdbms_201910_sergei_baranov_w13
```

#### При проблемах вида
"Problem while dropping database.
Can't remove database directory ... Please remove it manually."
и т.п.:

- Открываем терминал в контейнере:

```
docker-compose exec otus_rdbms_201910_sergei_baranov_w13 /bin/sh
```

- и в терминале в контейнере:

```
cd /var/lib/mysql
rm -R old
```

#### Для подключения к БД используйте команду:

```
docker-compose exec otus_rdbms_201910_sergei_baranov_w13 mysql -u root -p12345
```

или, если не пускает, то

```
docker-compose exec otus_rdbms_201910_sergei_baranov_w13 mysql -uroot
```

то же из sh

```
docker-compose exec otus_rdbms_201910_sergei_baranov_w13 /bin/sh
# mysql -uroot
mysql> use old;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> SELECT `id`, `allwords`, `rel` FROM (
           ->       SELECT `id`, `allwords`, MATCH(`allwords`) AGAINST('citigroup*' IN BOOLEAN MODE) as `rel`
           ->       FROM old.participants_suggest_900 WHERE MATCH(`allwords`) AGAINST('citigroup*' IN BOOLEAN MODE)
           ->     ) t WHERE t.`rel` > 1 ORDER BY t.`rel` DESC;
       +--------+-------------------------------------------------+-------------------+
       | id     | allwords                                        | rel               |
       +--------+-------------------------------------------------+-------------------+
       | 131869 | asia citigroup global ltd markets               | 7.729019641876221 |
       |    799 | citigroup inc                                   | 7.729019641876221 |
       |  36175 | citigroup global limited markets                | 7.729019641876221 |
       |  20905 | ag agco citigroup deutschland global markets    | 7.729019641876221 |
       |  91057 | citigroup global inc markets                    | 7.729019641876221 |
       |  70351 | citigroup funding global luxembourg markets sca | 7.729019641876221 |
       |  87789 | citigroup limited pty                           | 7.729019641876221 |
       +--------+-------------------------------------------------+-------------------+
       7 rows in set (0.00 sec)
```

как-то так...

#### Для использования в клиентских приложениях можно использовать команду:

```
mysql -u root -p12345 --host=127.0.0.1 --port=3309 --protocol=tcp
```