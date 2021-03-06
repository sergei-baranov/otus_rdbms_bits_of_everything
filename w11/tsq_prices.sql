CREATE TABLE tsq.`prices` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'PK, id, pack of place-date-bond',
  `id_rev` BIGINT UNSIGNED GENERATED ALWAYS AS (
    ((`id` DIV 100000000000000) * 100000000000000) +
    ((`id` % 100000000) * 1000000) +
    ((`id` DIV 100000000) % 1000000)
  ) COMMENT 'Repack PK to place-bond-date (for 2last)',
  `place_id` SMALLINT UNSIGNED GENERATED ALWAYS AS (
    (`id` DIV 100000000000000)
  ) STORED COMMENT 'id биржи',
  `date` DATE GENERATED ALWAYS AS (
    cast((20000000 + ((`id` DIV 100000000) % 1000000)) as date)
  ) STORED COMMENT 'дата котировки',
  `emission_id` INT UNSIGNED GENERATED ALWAYS AS (
    (`id` % 100000000)
  ) STORED COMMENT 'id эмиссии (su.emission.id)',
  `boardid` SMALLINT UNSIGNED DEFAULT NULL COMMENT 'Режим торгов',
  `update_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Время обновления записи',
  `clear_price` TINYINT UNSIGNED NOT NULL DEFAULT '0' COMMENT 'Под вопросом: см. коммент ниже',
  `buying_quote` DECIMAL(16,10) DEFAULT NULL COMMENT 'Котировка на покупку (bid), % от номинала',
  `selling_quote` DECIMAL(16,10) DEFAULT NULL COMMENT 'Котировка на продажу (ask), % от номинала',
  `last_price` DECIMAL(16,10) DEFAULT NULL COMMENT 'Цена последняя, % от номинала',
  `open_price` DECIMAL(16,10) DEFAULT NULL COMMENT 'Цена открытия, % от номинала',
  `max_price` DECIMAL(16,10) DEFAULT NULL COMMENT 'Цена максимальная, % от номинала',
  `min_price` DECIMAL(16,10) DEFAULT NULL COMMENT 'Цена минимальная, % от номинала',
  `avar_price` DECIMAL(16,10) DEFAULT NULL COMMENT 'Цена средневзвешенная, % от номинала',
  `mid_price` DECIMAL(16,10) DEFAULT NULL COMMENT 'Цена средняя, % от номинала',
  `marketprice` DECIMAL(16,10) DEFAULT NULL COMMENT 'Рыночная цена (3) (ранее Рыночная цена (1)), % от номинала',
  `marketprice2` DECIMAL(16,10) DEFAULT NULL COMMENT 'Рыночная цена (2), % от номинала',
  `admittedquote` DECIMAL(16,10) DEFAULT NULL COMMENT 'Признаваемая котировка, % от номинала',
  `legalcloseprice` DECIMAL(16,10) DEFAULT NULL COMMENT 'Цена закрытия, % от номинала',
  `indicative_price` DECIMAL(16,10) GENERATED ALWAYS AS ((case when (`avar_price` > 0) then `avar_price` when (`marketprice` > 0) then `marketprice` when (`legalcloseprice` > 0) then `legalcloseprice` when (`admittedquote` > 0) then `admittedquote` when (`mid_price` > 0) then `mid_price` when (`last_price` > 0) then `last_price` else NULL end)) STORED COMMENT 'Индикативная цена, % от номинала',
  `indicative_price_type` VARCHAR(16) GENERATED ALWAYS AS ((case when (`avar_price` > 0) then _utf8mb4'Avg' when (`marketprice` > 0) then _utf8mb4'Market' when (`legalcloseprice` > 0) then _utf8mb4'Close' when (`admittedquote` > 0) then _utf8mb4'Admitted' when (`mid_price` > 0) then _utf8mb4'Mid' when (`last_price` > 0) then _utf8mb4'Last' else NULL end)) STORED COMMENT 'Тип индикативной цены',
  `bid_ask_spread` DECIMAL(23,10) GENERATED ALWAYS AS (if(((`selling_quote` <> 0) and (`buying_quote` <> 0)),((`selling_quote` - `buying_quote`) * 100),NULL)) STORED COMMENT 'Bid-Ask spread по цене, bp',
  PRIMARY KEY (`id`),
  KEY `id_rev` (`id_rev`),
  KEY `p_d_e` (`place_id`,`date`,`emission_id`),
  KEY `p_e_d` (`place_id`,`date`,`emission_id`),
  KEY `update_time` (`update_time`) USING BTREE
  /* keys */
) /*!50100 TABLESPACE `innodb_file_per_table` */ ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
/* DATA DIRECTORY = '/mysql_tablespaces/sd1t/tsq' - commented; for home usage */
/*!50100 PARTITION BY RANGE (`id`)
(PARTITION p1 VALUES LESS THAN     (400000000000000) ENGINE = InnoDB,
 PARTITION p4 VALUES LESS THAN     (500000000000000) ENGINE = InnoDB,
 PARTITION p7 VALUES LESS THAN     (800000000000000) ENGINE = InnoDB,
 PARTITION p19 VALUES LESS THAN   (2000000000000000) ENGINE = InnoDB,
 PARTITION p20 VALUES LESS THAN   (2100000000000000) ENGINE = InnoDB,
 PARTITION p70 VALUES LESS THAN   (7100000000000000) ENGINE = InnoDB,
 PARTITION p71 VALUES LESS THAN   (7200000000000000) ENGINE = InnoDB,
 PARTITION p90 VALUES LESS THAN   (9100000000000000) ENGINE = InnoDB,
 PARTITION p91 VALUES LESS THAN   (9200000000000000) ENGINE = InnoDB,
 PARTITION p109 VALUES LESS THAN (11000000000000000) ENGINE = InnoDB,
 PARTITION p119 VALUES LESS THAN (12000000000000000) ENGINE = InnoDB,
 PARTITION p149 VALUES LESS THAN (15000000000000000) ENGINE = InnoDB,
 PARTITION p167 VALUES LESS THAN (16800000000000000) ENGINE = InnoDB,
 PARTITION p236 VALUES LESS THAN (23700000000000000) ENGINE = InnoDB,
 PARTITION p240 VALUES LESS THAN (24100000000000000) ENGINE = InnoDB,
 PARTITION p244 VALUES LESS THAN (24500000000000000) ENGINE = InnoDB,
 PARTITION p254 VALUES LESS THAN (25500000000000000) ENGINE = InnoDB,
 PARTITION p255 VALUES LESS THAN (25600000000000000) ENGINE = InnoDB,
 PARTITION p258 VALUES LESS THAN (25900000000000000) ENGINE = InnoDB,
 PARTITION p300 VALUES LESS THAN (30100000000000000) ENGINE = InnoDB,
 PARTITION p333 VALUES LESS THAN (33400000000000000) ENGINE = InnoDB,
 PARTITION p414 VALUES LESS THAN (41500000000000000) ENGINE = InnoDB,
 PARTITION p499 VALUES LESS THAN (50000000000000000) ENGINE = InnoDB,
 PARTITION p0 VALUES LESS THAN MAXVALUE ENGINE = InnoDB) */