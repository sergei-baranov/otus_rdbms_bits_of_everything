CREATE TABLE tsq.`two_last_quotations` (
  /* potential keys */
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'id результата торгов, PK, FK to tsq.prices, упаковка биржа-дата-бумага',
  `place_id` SMALLINT UNSIGNED DEFAULT NULL COMMENT 'id биржи',
  `date` DATE DEFAULT NULL COMMENT 'дата котировки',
  `emission_id` INT UNSIGNED DEFAULT NULL COMMENT 'id эмиссии (su.emission.id)',
  /* update_time */
  `update_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Время обновления записи',
  /* tsq.prices */
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
  `indicative_price` DECIMAL(16,10) DEFAULT NULL COMMENT 'Индикативная цена, % от номинала',
  `indicative_price_type` VARCHAR(16) DEFAULT NULL COMMENT 'Тип индикативной цены',
  `bid_ask_spread` DECIMAL(23,10) DEFAULT NULL COMMENT 'Bid-Ask spread по цене, bp',
  /* tsq.yields */
  `clearance_profit` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к погашения простая (от индик. цены), в долях',
  `offer_profit` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к оферте простая (от индик. цены), в долях',
  `clearance_profit_effect` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к погашению эффективная (от индик. цены), в долях ',
  `offer_profit_effect` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к оферте эффективная (от индик. цены), в долях ',
  `coupon_profit_effect` DECIMAL(16,10) DEFAULT NULL COMMENT 'current_yield',
  `clearance_profit_nominal` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к погашению номинальная (от индик. цены), в долях ',
  `offer_profit_nominal` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к оферте номинальная (от индик. цены), в долях ',
  `ytm_bid` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к погашению эфф. по цене Bid, в долях',
  `ytm_offer` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к погашению эфф. по цене Ask, в долях',
  `yto_bid` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к оферте эфф. по цене Bid, в долях',
  `yto_offer` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к оферте эфф. по цене Ask, в долях',
  `ytc_bid` DECIMAL(16,10) DEFAULT NULL COMMENT 'Текущая доходность по цене Bid, в долях',
  `ytc_offer` DECIMAL(16,10) DEFAULT NULL COMMENT 'Текущая доходность по цене Ask, в долях',
  `ytm_last` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к погашению эфф. по цене Last, в долях',
  `yto_last` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к оферте эфф. по цене Last, в долях',
  `ytc_last` DECIMAL(16,10) DEFAULT NULL COMMENT 'Текущая доходность по цене Last, в долях',
  `ytm_close` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к погашению эфф. по цене Close, в долях',
  `yto_close` DECIMAL(16,10) DEFAULT NULL COMMENT 'Доходность к оферте эфф. по цене Close, в долях',
  `ytc_close` DECIMAL(16,10) DEFAULT NULL COMMENT 'Текущая доходность по цене Close, в долях',
  `current_yield` DECIMAL(16,10) DEFAULT NULL COMMENT 'Текущая доходность, в долях',
  `indicative_yield` DECIMAL(16,10) DEFAULT NULL COMMENT 'Индикативная доходность, в долях',
  `indicative_yield_type` VARCHAR(16) DEFAULT NULL COMMENT 'Тип индикативной доходности',
  /* tsq.volumes */
  `overturn` DECIMAL(30,10) DEFAULT NULL COMMENT 'Оборот',
  `volume` INT DEFAULT NULL COMMENT 'Объем сделок в бумагах',
  `volume_money` INT DEFAULT NULL COMMENT 'Объем сделок в денежных единицах',
  `agreement_number` INT DEFAULT NULL COMMENT 'Количество сделок',
  /* tsq.risks_metrics */
  `dur` DECIMAL(18,10) DEFAULT NULL COMMENT 'Дюрация к погашению (от индик. цены), в днях',
  `dur_to` DECIMAL(18,10) DEFAULT NULL COMMENT 'Дюрация к оферте (от индик. цены), в днях',
  `duration` DECIMAL(18,10) DEFAULT NULL COMMENT 'Индикативная дюрация, в днях',
  `dur_mod` DECIMAL(15,10) DEFAULT NULL COMMENT 'Модифицированная дюрация к погашению (от индик. цены)',
  `dur_mod_to` DECIMAL(15,10) DEFAULT NULL COMMENT 'Модифицированная дюрация к оферте (от индик. цены)',
  `modified_duration` DECIMAL(15,10) DEFAULT NULL COMMENT 'Индикативная модифицированная дюрация',
  `pvbp` DECIMAL(18,10) DEFAULT NULL COMMENT 'PVBP к погашению',
  `pvbp_offer` DECIMAL(18,10) DEFAULT NULL COMMENT 'PVBP к оферте',
  `convexity` DECIMAL(18,10) DEFAULT NULL COMMENT 'Выпуклость к погашению',
  `convexity_offer` DECIMAL(18,10) DEFAULT NULL COMMENT 'Выпуклость к оферте',
  /* tsq.spreads */
  `g_spread` DECIMAL(23,10) DEFAULT NULL COMMENT 'G-spread, bp',
  `t_spread` DECIMAL(23,10) DEFAULT NULL COMMENT 'T-spread, bp',
  `t_spread_benchmark` INT UNSIGNED DEFAULT NULL COMMENT 'Эмиссия-бенчмарк для T-spread (su.emission.id)',
  /* bonds.nonquot_diachronic_props */
  `nkd` DECIMAL(36, 16) DEFAULT NULL COMMENT 'НКД (ACI)',
  `offer_date` DATE DEFAULT NULL COMMENT 'Дата оферты (ближайшая будущая из put/call)',
  `years_to_maturity` DECIMAL(15,10) DEFAULT NULL COMMENT 'Лет до погашения',
  `years_to_offert` DECIMAL(15,10) DEFAULT NULL COMMENT 'Лет до оферты (ближайшей будущей из put/call)',
  /* XPEHb */
 `tg_priority_glob` SMALLINT UNSIGNED DEFAULT NULL COMMENT 'Приоритет биржи для профиля global',
 `is_pseudo` TINYINT UNSIGNED NOT NULL DEFAULT '0' COMMENT 'Псевдобиржа (да/нет)',
   /* keys */
  PRIMARY KEY (`id`) USING BTREE,
  KEY `pde` (`place_id`,`date`,`emission_id`) USING BTREE,
  KEY `update_time` (`update_time`) USING BTREE
  /* keys */
) /*!50100 TABLESPACE `innodb_file_per_table` */ ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Котировки торговых систем, срез по две последние котировки на каждую пару бумага/биржа'