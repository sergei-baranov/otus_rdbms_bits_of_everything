CREATE TABLE tsq.`moex_last_prices` (
 `id` BIGINT UNSIGNED NOT NULL COMMENT 'PK, FK: su.tradings.id',
 `emission_id` INT UNSIGNED NOT NULL DEFAULT '0' COMMENT 'FK: su.emission.id',
 `date` DATE NOT NULL DEFAULT '1900-01-01' COMMENT 'Дата торгов',
 `last_price` DECIMAL(16,10) DEFAULT NULL COMMENT 'Цена последняя (в рублях)',
 `nkd` DECIMAL(36, 16) DEFAULT NULL COMMENT 'НКД (в рублях)',
 `update_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Время последнего обновления записи',
 PRIMARY KEY (`id`) USING BTREE,
 UNIQUE KEY `ed` (`emission_id`,`date`) USING BTREE,
 UNIQUE KEY `de` (`date`,`emission_id`) USING BTREE
) /*!50100 TABLESPACE `innodb_file_per_table` */ ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Последняя цена на Московской бирже и НКД (не вся МСК биржа!) для портфеля IF';