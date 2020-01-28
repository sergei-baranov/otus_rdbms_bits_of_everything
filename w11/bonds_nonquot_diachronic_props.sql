CREATE TABLE bonds.`nonquot_diachronic_props` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `emission_id` INT UNSIGNED DEFAULT NULL COMMENT 'FK: su.emission.id',
  `anchor_date` DATE DEFAULT NULL COMMENT 'Дата, на которую рассчитаны свойства',
  `update_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Дата обновления записи',
  `outstanding_nominal_price` double DEFAULT NULL COMMENT 'Непогашенный номинал',
  `nkd` double DEFAULT NULL COMMENT 'НКД',
  `outstanding_integral_multiple` double DEFAULT NULL COMMENT 'Непогашенный лот кратности',
  `current_coupon_rate` double DEFAULT NULL COMMENT 'Ставка купона, % годовых',
  `nominal_value_index` double DEFAULT NULL COMMENT 'Индекс приведения номинальной стоимости',
  `offer_date` DATE DEFAULT NULL COMMENT 'Дата оферты (ближайшая будущая из put/call)',
  `years_to_maturity` DECIMAL(15,10) UNSIGNED DEFAULT NULL COMMENT 'Лет до погашения',
  `years_to_offert` DECIMAL(15,10) UNSIGNED DEFAULT NULL COMMENT 'Лет до оферты (ближайшей будущей из put/call)',
  PRIMARY KEY (`id`,`emission_id`,`anchor_date`) USING BTREE,
  UNIQUE KEY `bond_date` (`emission_id`,`anchor_date`) USING BTREE,
  KEY `update_time` (`update_time`) USING BTREE,
  KEY `date_bond` (`anchor_date`,`emission_id`) USING BTREE
) /*!50100 TABLESPACE `innodb_file_per_table` */ ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Свойства бумаг, которые зависят от даты, но не зависят от котировок' DATA DIRECTORY = '/mysql_tablespaces/sd1t/bonds'
/*!50100 PARTITION BY HASH (DAYOFMONTH(`anchor_date`))
PARTITIONS 32 */