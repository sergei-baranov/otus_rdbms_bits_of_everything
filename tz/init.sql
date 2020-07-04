/*
Написать запрос, который выведет процент пользователей, которые внесли полную оплату, и количество всех пользователей в группе, по группам.

Ограничить группами, в которых занятия идут уже больше месяца от текущего момента.

Статус оплаты “прошла” это invoice.status = "payed"

DBMS: MySQL 8.0.20
*/


CREATE DATABASE `otus_tz` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `otus_tz`;

CREATE TABLE IF NOT EXISTS `otus_tz`.`users`(
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`) USING BTREE
) /*!50100 TABLESPACE `innodb_file_per_table` */ ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci DATA DIRECTORY='/mysql_tablespaces/sd1t/otus_tz/';

CREATE TABLE IF NOT EXISTS `otus_tz`.`courses`(
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(128) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) /*!50100 TABLESPACE `innodb_file_per_table` */ ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci DATA DIRECTORY='/mysql_tablespaces/sd1t/otus_tz/';

CREATE TABLE IF NOT EXISTS `otus_tz`.`groups` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `course_id` BIGINT UNSIGNED DEFAULT NULL COMMENT 'fk to courses.id',
  `title` VARCHAR(32) DEFAULT NULL,
  `enabled` TINYINT(1) UNSIGNED NOT NULL,
  `price_full` INT UNSIGNED NOT NULL DEFAULT '0',
  `price_month` INT UNSIGNED DEFAULT NULL,
  `start_date` DATE NOT NULL DEFAULT '2050-01-01',
  `finish_date` DATE DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  CONSTRAINT `groups_refs2_courses` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) /*!50100 TABLESPACE `innodb_file_per_table` */ ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci DATA DIRECTORY='/mysql_tablespaces/sd1t/otus_tz/';

CREATE TABLE IF NOT EXISTS `otus_tz`.`invoice` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT 'fk to users.id',
  `amount` INT UNSIGNED NOT NULL,
  `status` VARCHAR(6) NOT NULL,
  `full_paid` TINYINT(1) UNSIGNED NOT NULL,
  `discount` INT UNSIGNED NOT NULL DEFAULT 0,
  `course_id` BIGINT UNSIGNED DEFAULT NULL COMMENT 'fk to courses.id',
  `group_id` BIGINT UNSIGNED DEFAULT NULL COMMENT 'fk to groups.id',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `user_id` (`user_id`),
  CONSTRAINT `invoice_refs2_users` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `invoice_refs2_courses` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `invoice_refs2_groups` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) /*!50100 TABLESPACE `innodb_file_per_table` */ ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci DATA DIRECTORY='/mysql_tablespaces/sd1t/otus_tz/';


DELETE FROM `otus_tz`.`invoice`;
ALTER TABLE `otus_tz`.`invoice` AUTO_INCREMENT = 1;
DELETE FROM `otus_tz`.`groups`;
ALTER TABLE `otus_tz`.`groups` AUTO_INCREMENT = 1;
TRUNCATE `otus_tz`.`courses`;
TRUNCATE `otus_tz`.`users`;
/*
or
DELETE FROM `otus_tz`.`courses`;
ALTER TABLE `otus_tz`.`courses` AUTO_INCREMENT = 1;
DELETE FROM `otus_tz`.`users`;
ALTER TABLE `otus_tz`.`users` AUTO_INCREMENT = 1;
*/
/* fill `otus_tz`.`users` */
INSERT INTO `otus_tz`.`users` SELECT * FROM (
  WITH RECURSIVE nats (n) AS
  (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM nats WHERE n < 1000/* @@cte_max_recursion_depth */
  )
  SELECT * FROM nats
) as t;

/* fill `otus_tz`.`courses` */
INSERT INTO
  `otus_tz`.`courses`
  (`id`, `title`)
VALUES
  (1, 'Patterns'),
  (3, 'ArchHighload'),
  (5, 'ArchSoftware'),
  (7, 'UnityGames'),
  (8, 'ReactJs'),
  (11, 'Vue'),
  (21, 'JavaScript'),
  (22, 'AdvancedAndroid'),
  (23, 'Java'),
  (25, 'Php'),
  (27, 'Scala'),
  (33, 'TeamLead2'),
  (35, 'Golang'),
  (36, 'PostgresQL')
;

/* `otus_tz`.`fill_groups` */
USE `otus_tz`;
DROP PROCEDURE IF EXISTS `otus_tz`.`fill_groups`;
DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `otus_tz`.`fill_groups`(
  out rc int
  , out err varchar(1000)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
  DECLARE done INT DEFAULT FALSE;

  DECLARE l_max_year INT UNSIGNED DEFAULT 2021;
  DECLARE l_counter_year INT UNSIGNED DEFAULT 2018;

  DECLARE l_max_month INT UNSIGNED DEFAULT 5;
  DECLARE l_counter_month INT UNSIGNED DEFAULT 2;

  DECLARE l_group_title VARCHAR(32) DEFAULT '';
  DECLARE l_group_start VARCHAR(10) DEFAULT '';
  DECLARE l_group_fin VARCHAR(10) DEFAULT '';

  DECLARE l_course_id bigint UNSIGNED DEFAULT '0';
  DECLARE l_course_title VARCHAR(24) DEFAULT '';

  DECLARE cur_courses CURSOR FOR SELECT `id`, `title` FROM `otus_tz`.`courses`;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1
    rc = RETURNED_SQLSTATE, err = MESSAGE_TEXT;
    ROLLBACK;
    RESIGNAL;
  END;

  OPEN cur_courses;

  loop_courses: LOOP
    FETCH cur_courses INTO l_course_id, l_course_title;
    IF done THEN
      LEAVE loop_courses;
    END IF;

    START TRANSACTION;
    SET l_counter_year = 2018;
    WHILE l_counter_year <= l_max_year DO
      SET l_counter_month = 2;
      WHILE l_counter_month <= l_max_month DO
        SET l_group_title = CONCAT(l_course_title, '-', l_counter_year, '-0', l_counter_month);
        SET l_group_start = CONCAT(l_counter_year, '-0', l_counter_month, '-01');
        SET l_group_fin = CONCAT(l_counter_year, '-0', (l_counter_month + 4), '-28');
        INSERT INTO `otus_tz`.`groups` (
          `course_id`, `title`, `enabled`, `price_full`, `price_month`, `start_date`, `finish_date`
        )
        VALUES (
          l_course_id, l_group_title, 1, 60000, 12000, l_group_start, l_group_fin
        );
        SET l_counter_month = l_counter_month + 1;
      END WHILE;
      SET l_counter_year = l_counter_year + 1;
    END WHILE;
    COMMIT;
  END LOOP;

  CLOSE cur_courses;
END $$
DELIMITER ;
/* fill `otus_tz`.`groups` */
CALL `otus_tz`.`fill_groups`(@rc, @err);

/* `otus_tz`.`fill_invoices` */
USE `otus_tz`;
DROP PROCEDURE IF EXISTS `otus_tz`.`fill_invoices`;
DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `otus_tz`.`fill_invoices`(
  out rc int
  , out err varchar(1000)
)
MODIFIES SQL DATA
SQL SECURITY DEFINER
BEGIN
  DECLARE done INT DEFAULT FALSE;

  DECLARE l_counter int DEFAULT 0;
  DECLARE l_rand4limit int DEFAULT 0;
  DECLARE l_rand4payed double DEFAULT 0.0;
  DECLARE l_payed VARCHAR(6) DEFAULT '';
  DECLARE l_user_id bigint DEFAULT 0;
  DECLARE l_group_id bigint DEFAULT 0;
  DECLARE l_course_id bigint DEFAULT 0;

  DECLARE cur_groups CURSOR FOR SELECT `id`, `course_id` FROM `otus_tz`.`groups`;
  DECLARE cur_users CURSOR FOR SELECT `id` FROM `otus_tz`.`users` ORDER BY RAND() LIMIT 50;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1
    rc = RETURNED_SQLSTATE, err = MESSAGE_TEXT;
    ROLLBACK;
    RESIGNAL;
  END;

  OPEN cur_groups;
  
  loop_groups: LOOP
    FETCH cur_groups INTO l_group_id, l_course_id;
    IF done THEN
      LEAVE loop_groups;
    END IF;

    START TRANSACTION;
      SET l_rand4limit =  FLOOR(1 + RAND() * 50);
      SET l_counter = 1;
      OPEN cur_users;
      loop_users_full: LOOP
        SET l_rand4payed =  RAND();
        IF l_rand4payed > 0.5 THEN
          SET l_payed = 'payed';
        ELSE
          SET l_payed = '';
        END IF;

        FETCH cur_users INTO l_user_id;
        IF done OR l_counter > l_rand4limit THEN
          SET done = FALSE;
          LEAVE loop_users_full;
        END IF;
        SET l_counter = l_counter + 1;

        INSERT INTO `otus_tz`.`invoice` (
          `user_id`, `amount`, `status`, `full_paid`, `discount`, `course_id`, `group_id`
        ) VALUES (
          l_user_id, 50000, l_payed, 1, 10000, l_course_id, l_group_id
        );
      END LOOP;
      CLOSE cur_users;

      SET l_rand4limit =  FLOOR(1 + RAND() * 50);
      SET l_counter = 1;
      OPEN cur_users;
      loop_users_month1: LOOP
        SET l_rand4payed =  RAND();
        IF l_rand4payed > 0.5 THEN
          SET l_payed = 'payed';
        ELSE
          SET l_payed = '';
        END IF;

        FETCH cur_users INTO l_user_id;
        IF done OR l_counter > l_rand4limit THEN
          SET done = FALSE;
          LEAVE loop_users_month1;
        END IF;
        SET l_counter = l_counter + 1;

        INSERT INTO `otus_tz`.`invoice` (
          `user_id`, `amount`, `status`, `full_paid`, `discount`, `course_id`, `group_id`
        ) VALUES (
          l_user_id, 10000, l_payed, 0, 2000, l_course_id, l_group_id
        );
      END LOOP;
      CLOSE cur_users;

      SET l_rand4limit =  FLOOR(1 + RAND() * 50);
      SET l_counter = 1;
      OPEN cur_users;
      loop_users_month5: LOOP
        SET l_rand4payed =  RAND();
        IF l_rand4payed > 0.5 THEN
          SET l_payed = 'payed';
        ELSE
          SET l_payed = '';
        END IF;

        FETCH cur_users INTO l_user_id;
        IF done OR l_counter > l_rand4limit THEN
          SET done = FALSE;
          LEAVE loop_users_month5;
        END IF;
        SET l_counter = l_counter + 1;

        INSERT INTO `otus_tz`.`invoice` (
          `user_id`, `amount`, `status`, `full_paid`, `discount`, `course_id`, `group_id`
        ) VALUES
        (l_user_id, 10000, 'payed', 0, 2000, l_course_id, l_group_id),
        (l_user_id, 10000, 'payed', 0, 2000, l_course_id, l_group_id),
        (l_user_id, 10000, 'payed', 0, 2000, l_course_id, l_group_id),
        (l_user_id, 10000, 'payed', 0, 2000, l_course_id, l_group_id),
        (l_user_id, 10000, l_payed, 0, 2000, l_course_id, l_group_id)
        ;
      END LOOP;
      CLOSE cur_users;

    COMMIT;

    IF done THEN
      LEAVE loop_groups;
    END IF;
  END LOOP;

  CLOSE cur_groups;
END $$
DELIMITER ;
/* fill `otus_tz`.`invoice` */
CALL `otus_tz`.`fill_invoices`(@rc, @err);

/* допустим для начала попроще: что флаг `full_paid` ставится на завершающий полную оплату счёт
(на единственный при разовой и последний при частичной) */

/* допустим теперь, что флаг `full_paid` маркирует счёт на оплату курса полностью
(и в частичных счетах этот флаг не высталяется никогда),
а в `invoice`.`discount` лежит скидка в деньгах (в абс. значении) */