/*
запускать примерно так:
use sb;
call split_sb_tradings_next_chunk(255, '2019-04-09', '238, 242, 1102, 1116, 1117, 1120, 1190, 1504, 1556, 1641', @rc, @err);
*/
use sb;
DELIMITER ;;
CREATE DEFINER = `sb`@`%` PROCEDURE split_sb_tradings_next_chunk(
    IN in_trading_ground_id INT
    , IN in_anchor_date DATE
    , IN in_bonds_ids VARCHAR(10000)
    , OUT rc VARCHAR(45)
    , OUT err VARCHAR(1000)
) MODIFIES SQL DATA
main:BEGIN
    DECLARE l_src_part_num VARCHAR(4);
    DECLARE l_dest_part_num VARCHAR(4);
    DECLARE l_all_fields VARCHAR(2500);
    DECLARE l_sql_select VARCHAR(14000);
    DECLARE l_prices_fields VARCHAR(500);
    DECLARE l_yields_fields VARCHAR(500);
    DECLARE l_volumes_fields VARCHAR(500);
    DECLARE l_risks_metrics_fields VARCHAR(500);
    DECLARE l_spreads_fields VARCHAR(500);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
        rc = RETURNED_SQLSTATE, err = MESSAGE_TEXT;
        ROLLBACK;
        RESIGNAL;
    END;

    CASE
      WHEN in_trading_ground_id <   2 THEN SET l_src_part_num = 'p1';
      WHEN in_trading_ground_id <   5 THEN SET l_src_part_num = 'p4';
      WHEN in_trading_ground_id <   7 THEN SET l_src_part_num = 'p6';
      WHEN in_trading_ground_id <  10 THEN SET l_src_part_num = 'p9';
      WHEN in_trading_ground_id <  11 THEN SET l_src_part_num = 'p10';
      WHEN in_trading_ground_id <  21 THEN SET l_src_part_num = 'p20';
      WHEN in_trading_ground_id <  26 THEN SET l_src_part_num = 'p25';
      WHEN in_trading_ground_id <  29 THEN SET l_src_part_num = 'p28';
      WHEN in_trading_ground_id <  30 THEN SET l_src_part_num = 'p29';
      WHEN in_trading_ground_id <  52 THEN SET l_src_part_num = 'p51';
      WHEN in_trading_ground_id <  70 THEN SET l_src_part_num = 'p69';
      WHEN in_trading_ground_id <  72 THEN SET l_src_part_num = 'p71';
      WHEN in_trading_ground_id <  88 THEN SET l_src_part_num = 'p87';
      WHEN in_trading_ground_id < 110 THEN SET l_src_part_num = 'p109';
      WHEN in_trading_ground_id < 120 THEN SET l_src_part_num = 'p119';
      WHEN in_trading_ground_id < 146 THEN SET l_src_part_num = 'p145';
      WHEN in_trading_ground_id < 150 THEN SET l_src_part_num = 'p149';
      WHEN in_trading_ground_id < 200 THEN SET l_src_part_num = 'p199';
      WHEN in_trading_ground_id < 300 THEN SET l_src_part_num = 'p299';
      WHEN in_trading_ground_id < 400 THEN SET l_src_part_num = 'p399';
      WHEN in_trading_ground_id < 500 THEN SET l_src_part_num = 'p499';
      ELSE SET l_src_part_num = 'p0';
    END CASE;

    CASE
      WHEN in_trading_ground_id <   4 THEN SET l_dest_part_num = 'p1';
      WHEN in_trading_ground_id <   5 THEN SET l_dest_part_num = 'p4';
      WHEN in_trading_ground_id <   8 THEN SET l_dest_part_num = 'p7';
      WHEN in_trading_ground_id <  20 THEN SET l_dest_part_num = 'p19';
      WHEN in_trading_ground_id <  21 THEN SET l_dest_part_num = 'p20';
      WHEN in_trading_ground_id <  71 THEN SET l_dest_part_num = 'p70';
      WHEN in_trading_ground_id <  72 THEN SET l_dest_part_num = 'p71';
      WHEN in_trading_ground_id <  91 THEN SET l_dest_part_num = 'p90';
      WHEN in_trading_ground_id <  92 THEN SET l_dest_part_num = 'p91';
      WHEN in_trading_ground_id < 110 THEN SET l_dest_part_num = 'p109';
      WHEN in_trading_ground_id < 120 THEN SET l_dest_part_num = 'p119';
      WHEN in_trading_ground_id < 150 THEN SET l_dest_part_num = 'p149';
      WHEN in_trading_ground_id < 168 THEN SET l_dest_part_num = 'p167';
      WHEN in_trading_ground_id < 237 THEN SET l_dest_part_num = 'p236';
      WHEN in_trading_ground_id < 241 THEN SET l_dest_part_num = 'p240';
      WHEN in_trading_ground_id < 245 THEN SET l_dest_part_num = 'p244';
      WHEN in_trading_ground_id < 255 THEN SET l_dest_part_num = 'p254';
      WHEN in_trading_ground_id < 256 THEN SET l_dest_part_num = 'p255';
      WHEN in_trading_ground_id < 259 THEN SET l_dest_part_num = 'p258';
      WHEN in_trading_ground_id < 301 THEN SET l_dest_part_num = 'p300';
      WHEN in_trading_ground_id < 334 THEN SET l_dest_part_num = 'p333';
      WHEN in_trading_ground_id < 415 THEN SET l_dest_part_num = 'p414';
      WHEN in_trading_ground_id < 500 THEN SET l_dest_part_num = 'p499';
      ELSE SET l_dest_part_num = 'p0';
    END CASE;

    /* fields for select from sb.tradings to cte */
    SET l_all_fields = CONCAT(
    '      `id`, `place_id`, `date`, `emission_id`\n',
    '    , `boardid`\n',
    '    , `clear_price`, `buying_quote`, `selling_quote`, `last_price`\n',
    '    , `open_price`, `max_price`, `min_price`, `avar_price`, `mid_price`\n',
    '    , `marketprice`, `marketprice2`, `admittedquote`, `legalcloseprice`\n',
    '    , `clearance_profit`, `offer_profit`, `clearance_profit_effect`\n',
    '    , `offer_profit_effect`, `coupon_profit_effect`, `current_yield`\n',
    '    , `clearance_profit_nominal`, `offer_profit_nominal`\n',
    '    , `ytm_bid`, `yto_bid`, `ytc_bid`\n',
    '    , `ytm_offer`, `yto_offer`, `ytc_offer`\n',
    '    , `ytm_last`, `yto_last`, `ytc_last`\n',
    '    , `ytm_close`, `yto_close`, `ytc_close`\n',
    '    , `overturn`, `volume`, `volume_money`, `agreement_number`\n',
    '    , `dur`, `dur_to`, `dur_mod`, `dur_mod_to`\n',
    '    , `pvbp`, `pvbp_offer`, `convexity`, `convexity_offer`\n',
    '    , `g_spread`, `t_spread`, `t_spread_benchmark`\n'
    );

    /* select from sb.tradings */
    /*
    в этой части я перечисляю все поля, необходимые для всех
    пяти таблиц, так как надеюсь, что CTE не будет реально
    обращаться к БД все пять раз, а идентичные SELECT-ы
    возьмёт из кеша
    */
    SET l_sql_select = CONCAT(
    '    SELECT\n',
    l_all_fields,
    '    FROM\n',
    '      sb.tradings PARTITION (', l_src_part_num, ')\n',
    '    WHERE\n',
    '      `place_id` = ', in_trading_ground_id, '\n',
    '      AND `date` = ', in_anchor_date, '\n',
    '      AND `emission_id` IN (', in_bonds_ids, ')\n',
    '    ORDER BY NULL'
    );

    /* fields for select from cte and insert into tsq.prices */
    SET l_prices_fields = CONCAT(
        '`id`, `place_id`, `date`, `emission_id`, `boardid`',
        ', `clear_price`, `buying_quote`, `selling_quote`, `last_price`',
        ', `open_price`, `max_price`, `min_price`, `avar_price`, `mid_price`',
        ', `marketprice`, `marketprice2`, `admittedquote`, `legalcloseprice`'
    );

    /* fields for select from cte and insert into tsq.yields */
    SET l_yields_fields = CONCAT(
        '`id`',
        ', `clearance_profit`, `offer_profit`, `clearance_profit_effect`',
        ', `offer_profit_effect`, `coupon_profit_effect`, `current_yield`',
        ', `clearance_profit_nominal`, `offer_profit_nominal`',
        ', `ytm_bid`, `yto_bid`, `ytc_bid`',
        ', `ytm_offer`, `yto_offer`, `ytc_offer`',
        ', `ytm_last`, `yto_last`, `ytc_last`',
        ', `ytm_close`, `yto_close`, `ytc_close`'
    );

    /* fields for select from cte and insert into tsq.volumes */
    SET l_volumes_fields = CONCAT(
        '`id`',
        ', `overturn`, `volume`, `volume_money`, `agreement_number`'
    );

    /* fields for select from cte and insert into tsq.risks_metrics */
    SET l_risks_metrics_fields = CONCAT(
        '`id`',
        ', `dur`, `dur_to`, `dur_mod`, `dur_mod_to`',
        ', `pvbp`, `pvbp_offer`, `convexity`, `convexity_offer`'
    );

    /* fields for select from cte and insert into tsq.spreads */
    SET l_spreads_fields = CONCAT(
        '`id`',
        ', `g_spread`, `t_spread`, `t_spread_benchmark`'
    );

    /* INSERT INTO tsq.prices */
    SET @sql_prices = CONCAT(
        'WITH cte (',
        l_all_fields,
        ') AS (',
        l_sql_select,
        ') INSERT IGNORE INTO tsq.prices PARTITION (', l_dest_part_num, ') SELECT ',
        l_prices_fields,
        ' FROM cte'
    );

    /* INSERT INTO tsq.yields */
    SET @sql_yields = CONCAT(
        'WITH cte (',
        l_all_fields,
        ') AS (',
        l_sql_select,
        ') INSERT IGNORE INTO tsq.yields PARTITION (', l_dest_part_num, ') SELECT ',
        l_yields_fields,
        ' FROM cte'
    );

    /* INSERT INTO tsq.volumes */
    SET @sql_volumes = CONCAT(
        'WITH cte (',
        l_all_fields,
        ') AS (',
        l_sql_select,
        ') INSERT IGNORE INTO tsq.volumes PARTITION (', l_dest_part_num, ') SELECT ',
        l_volumes_fields,
        ' FROM cte'
    );

    /* INSERT INTO tsq.risks_metrics */
    SET @sql_risks_metrics = CONCAT(
        'WITH cte (',
        l_all_fields,
        ') AS (',
        l_sql_select,
        ') INSERT IGNORE INTO tsq.risks_metrics PARTITION (', l_dest_part_num, ') SELECT ',
        l_risks_metrics_fields,
        ' FROM cte'
    );

    /* INSERT INTO tsq.spreads */
    SET @sql_spreads = CONCAT(
        'WITH cte (',
        l_all_fields,
        ') AS (',
        l_sql_select,
        ') INSERT IGNORE INTO tsq.spreads PARTITION (', l_dest_part_num, ') SELECT ',
        l_spreads_fields,
        ' FROM cte'
    );

    START TRANSACTION READ WRITE;

    PREPARE s1 FROM @sql_prices;
    EXECUTE s1;
    DEALLOCATE PREPARE s1;

    PREPARE s2 FROM @sql_yields;
    EXECUTE s2;
    DEALLOCATE PREPARE s2;

    PREPARE s3 FROM @sql_volumes;
    EXECUTE s3;
    DEALLOCATE PREPARE s3;

    PREPARE s4 FROM @sql_risks_metrics;
    EXECUTE s4;
    DEALLOCATE PREPARE s4;

    PREPARE s5 FROM @sql_spreads;
    EXECUTE s5;
    DEALLOCATE PREPARE s5;

    COMMIT;
END ;;
DELIMITER ;