USE `moddb`;

DELIMITER $$

CREATE OR REPLACE PROCEDURE upgrade_database__moderation()
BEGIN

IF EXISTS( (SELECT * FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='moddb' AND
 TABLE_NAME='assets' AND COLUMN_NAME='tagsCached') ) THEN
	ALTER TABLE `assets` DROP COLUMN `tagsCached`;
END IF;


END $$

CALL upgrade_database__moderation() $$

DELIMITER ;
