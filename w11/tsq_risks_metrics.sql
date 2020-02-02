CREATE TABLE tsq.`risks_metrics` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'PK, FK to prices.id',
  `update_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '',
  `dur` DECIMAL(18,10) UNSIGNED DEFAULT NULL COMMENT 'Дюрация к погашению (от индик. цены), в днях',
  `dur_to` DECIMAL(18,10) UNSIGNED DEFAULT NULL COMMENT 'Дюрация к оферте (от индик. цены), в днях',
  `duration` DECIMAL(18,10) UNSIGNED GENERATED ALWAYS AS (if((`dur` <> 0),`dur`,nullif(`dur_to`,0))) STORED COMMENT 'Индикативная дюрация, в днях',
  `dur_mod` DECIMAL(15,10) DEFAULT NULL COMMENT 'Модифицированная дюрация к погашению (от индик. цены)',
  `dur_mod_to` DECIMAL(15,10) DEFAULT NULL COMMENT 'Модифицированная дюрация к оферте (от индик. цены)',
  `modified_duration` DECIMAL(15,10) GENERATED ALWAYS AS (if((`dur_mod` <> 0),`dur_mod`,nullif(`dur_mod_to`,0))) STORED COMMENT 'Индикативная модифицированная дюрация',
  `pvbp` DECIMAL(18,10) DEFAULT NULL COMMENT 'PVBP к погашению',
  `pvbp_offer` DECIMAL(18,10) DEFAULT NULL COMMENT 'PVBP к оферте',
  `convexity` DECIMAL(18,10) DEFAULT NULL COMMENT 'Выпуклость к погашению',
  `convexity_offer` DECIMAL(18,10) DEFAULT NULL COMMENT 'Выпуклость к оферте',
  PRIMARY KEY (`id`) USING BTREE,
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